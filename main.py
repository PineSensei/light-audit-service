import os, subprocess, time, json, xmltodict
from datetime import datetime
from fastapi import FastAPI, BackgroundTasks, HTTPException
from pydantic import BaseModel
from zapv2 import ZAPv2
from jinja2 import Environment, FileSystemLoader
from sendgrid import SendGridAPIClient
from sendgrid.helpers.mail import Mail, Attachment, FileContent, FileName, FileType, Disposition
from dotenv import load_dotenv
import base64

# Load .env in local/dev
load_dotenv()

# Config
ZAP_HOST = os.getenv("ZAP_HOST", "127.0.0.1")
ZAP_PORT = int(os.getenv("ZAP_PORT", 8090))
ZAP_SPIDER_TIMEOUT = int(os.getenv("ZAP_SPIDER_TIMEOUT", 120))
ZAP_ASCAN_TIMEOUT = int(os.getenv("ZAP_ASCAN_TIMEOUT", 600))
REPORT_TEMPLATE_DIR = os.getenv("REPORT_TEMPLATE_DIR", "./templates")
STATIC_DIR = os.getenv("STATIC_DIR", "./static")
REPORT_HTML = os.getenv("REPORT_HTML", "report.html")
REPORT_PDF = os.getenv("REPORT_PDF", "report.pdf")
FROM_EMAIL = os.getenv("FROM_EMAIL")
SENDGRID_API_KEY = os.getenv("SENDGRID_API_KEY")
BRAND_NAME = os.getenv("BRAND_NAME", "YourBrand")

# FastAPI setup
app = FastAPI()
env = Environment(loader=FileSystemLoader(REPORT_TEMPLATE_DIR))

class ScanRequest(BaseModel):
    url: str
    email: str

@app.post("/scan")
async def scan_endpoint(req: ScanRequest, bg: BackgroundTasks):
    if not req.url.startswith("http"):
        raise HTTPException(400, "URL must start with http(s)")
    bg.add_task(run_scan_and_email, req.url, req.email)
    return {"status": "scan started"}

def run_cmd(cmd, timeout=None):
    res = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=timeout)
    return res.stdout or ""

def run_scan_and_email(url, email):
    now = datetime.utcnow().strftime("%Y-%m-%d %H:%M:%S")

    # 1) Subdomain enumeration
    subdomains = run_cmd(f"subfinder -d {url} -silent", timeout=60)

    # 2) Nmap
    nmap_xml = run_cmd(f"nmap -p80,443 -sV {url} -oX -", timeout=60)
    nmap_data = xmltodict.parse(nmap_xml)
    nmap_text = json.dumps(nmap_data, indent=2)

    # 3) SSL/TLS check
    run_cmd(f"testssl.sh --jsonfile testssl.json {url}", timeout=120)
    testssl_data = {}
    if os.path.exists("testssl.json"):
        testssl_data = json.loads(open("testssl.json").read())

    # 4) WAF detection
    waf = run_cmd(f"wafw00f {url}", timeout=30)

    # 5) Content discovery
    ffuf_json = run_cmd(f"ffuf -u https://{url}/FUZZ -w /usr/share/wordlists/dirb/common.txt -of json", timeout=60)
    ffuf_data = json.loads(ffuf_json) if ffuf_json else {}

    # 6) CMS scan (WordPress example)
    wpscan_json = run_cmd(f"wpscan --url https://{url} --format json --no-update", timeout=120)
    wpscan_data = json.loads(wpscan_json) if wpscan_json else {}

    # 7) Generic CVE patterns
    nuclei_json = run_cmd(f"nuclei -target {url} -json", timeout=120)
    nuclei_data = [json.loads(line) for line in nuclei_json.splitlines() if line.strip()]

    # 8) Nikto
    nikto_out = run_cmd(f"nikto -h https://{url}", timeout=120)

    # 9) ZAP DAST
    zap = ZAPv2(proxies={
        'http': f'http://{ZAP_HOST}:{ZAP_PORT}',
        'https': f'http://{ZAP_HOST}:{ZAP_PORT}'
    })
    # Spider
    sid = zap.spider.scan(url)
    start = time.time()
    while int(zap.spider.status(sid)) < 100 and time.time()-start < ZAP_SPIDER_TIMEOUT:
        time.sleep(2)
    # Active scan
    aid = zap.ascan.scan(url)
    start = time.time()
    while int(zap.ascan.status(aid)) < 100 and time.time()-start < ZAP_ASCAN_TIMEOUT:
        time.sleep(5)
    zap_report = zap.core.htmlreport()

    # 10) SQLMap
    sqlmap_out = run_cmd(f"sqlmap -u \"https://{url}/?id=1\" --batch --output-dir=sqlmap_out", timeout=120)

    # 11) XSStrike
    xs_out = run_cmd(f"xsstrike -u https://{url} --batch", timeout=60)

    # Render report
    tpl = env.get_template("report.html")
    html = tpl.render(
        url=url, date=now, brand=BRAND_NAME,
        subdomains=subdomains, nmap=nmap_text,
        testssl=testssl_data, waf=waf,
        ffuf=ffuf_data, wpscan=wpscan_data,
        nuclei=nuclei_data, nikto=nikto_out,
        zap=zap_report, sqlmap=sqlmap_out,
        xsstrike=xs_out, logo_path=os.path.join(STATIC_DIR,"logo.png")
    )
    with open(REPORT_HTML,"w") as f: f.write(html)
    run_cmd(f"wkhtmltopdf --enable-local-file-access {REPORT_HTML} {REPORT_PDF}", timeout=60)

    # Email
    sg = SendGridAPIClient(SENDGRID_API_KEY)
    msg = Mail(
        from_email=FROM_EMAIL,
        to_emails=email,
        subject=f"Security Audit for {url}",
        html_content="Please find your audit report attached."
    )
    encoded = base64.b64encode(open(REPORT_PDF,"rb").read()).decode()
    attachment = Attachment(FileContent(encoded), FileName("audit_report.pdf"),
                            FileType("application/pdf"), Disposition("attachment"))
    msg.attachment = attachment
    sg.send(msg)
