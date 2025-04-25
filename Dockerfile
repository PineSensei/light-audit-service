# 1) Use OWASP ZAP’s official image so zap.sh is available
FROM owasp/zap2docker-stable:latest

# 2) Switch to root to install Python & tools
USER root

# 3) Install Python3, pip, build tools, and your OSS scanners
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      python3 python3-pip python3-dev build-essential libssl-dev libffi-dev \
      git curl wget ca-certificates \
      nmap ffuf wafw00f \
      wkhtmltopdf \
      default-jre-headless \
      perl libnet-ssleay-perl libwhisker2-perl libio-socket-ssl-perl && \
    rm -rf /var/lib/apt/lists/*

# 4) Install Nikto
RUN git clone https://github.com/sullo/nikto.git /opt/nikto && \
    ln -s /opt/nikto/program/nikto.pl /usr/local/bin/nikto

# 5) Install testssl.sh
RUN git clone https://github.com/drwetter/testssl.sh.git /opt/testssl.sh && \
    ln -s /opt/testssl.sh/testssl.sh /usr/local/bin/testssl.sh

# 6) Upgrade pip and install Python dependencies
COPY requirements.txt /tmp/requirements.txt
RUN pip3 install --upgrade pip setuptools wheel && \
    pip3 install --no-cache-dir -r /tmp/requirements.txt

# 7) Copy your application code
WORKDIR /app
COPY . /app

# 8) Expose FastAPI port (ZAP listens on 8090 internally)
EXPOSE 8080

# 9) Launch ZAP in daemon mode, then start FastAPI
#    We background zap.sh so the container stays alive and then run uvicorn
CMD ["bash","-lc","zap.sh -daemon -host 0.0.0.0 -port ${ZAP_PORT:-8090} && uvicorn main:app --host 0.0.0.0 --port 8080"]
