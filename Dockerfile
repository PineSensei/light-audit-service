FROM python:3.10-slim

# 1) System packages, Perl libs for Nikto, and build tools for Python wheels
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      git curl wget ca-certificates \
      nmap ffuf wafw00f \
      wkhtmltopdf default-jre-headless \
      perl libnet-ssleay-perl libwhisker2-perl libio-socket-ssl-perl \
      build-essential python3-dev libssl-dev libffi-dev && \
    rm -rf /var/lib/apt/lists/*

# 2) Nikto
RUN git clone https://github.com/sullo/nikto.git /opt/nikto && \
    ln -s /opt/nikto/program/nikto.pl /usr/local/bin/nikto

# 3) testssl.sh
RUN git clone https://github.com/drwetter/testssl.sh.git /opt/testssl.sh && \
    ln -s /opt/testssl.sh/testssl.sh /usr/local/bin/testssl.sh

# (subfinder/nuclei removed for now to simplify build)

WORKDIR /app

# 4) Python dependencies
COPY requirements.txt .
RUN pip install --upgrade pip setuptools wheel && \
    pip install --no-cache-dir -r requirements.txt

# 5) Copy application code
COPY . .

# 6) Expose port & run
EXPOSE 8080
CMD zap.sh -daemon -host 0.0.0.0 -port ${ZAP_PORT:-8090} && \
    uvicorn main:app --host 0.0.0.0 --port 8080
