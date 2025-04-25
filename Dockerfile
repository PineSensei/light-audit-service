# 1) Base ZAP image
FROM zaproxy/zap-stable:latest

USER root

# 2) Install system packages, Python & build tools
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      python3 python3-venv python3-pip python3-dev build-essential libssl-dev libffi-dev \
      git curl wget ca-certificates \
      nmap ffuf wafw00f wkhtmltopdf \
      default-jre-headless \
      perl libnet-ssleay-perl libwhisker2-perl libio-socket-ssl-perl && \
    rm -rf /var/lib/apt/lists/*

# 3) Create & activate a venv
RUN python3 -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# 4) Install Python dependencies into venv
COPY requirements.txt /tmp/requirements.txt
RUN pip install --upgrade pip setuptools wheel && \
    pip install --no-cache-dir -r /tmp/requirements.txt

# 5) Install Nikto
RUN git clone https://github.com/sullo/nikto.git /opt/nikto && \
    ln -s /opt/nikto/program/nikto.pl /usr/local/bin/nikto

# 6) Install testssl.sh
RUN git clone https://github.com/drwetter/testssl.sh.git /opt/testssl.sh && \
    ln -s /opt/testssl.sh/testssl.sh /usr/local/bin/testssl.sh

# 7) Copy your app code
WORKDIR /app
COPY . /app

# 8) Expose the FastAPI port
EXPOSE 8080

# 9) Entry point: start ZAP then Uvicorn from our venv
CMD ["bash","-c","zap.sh -daemon -host 0.0.0.0 -port ${ZAP_PORT:-8090} & /opt/venv/bin/uvicorn main:app --host 0.0.0.0 --port 8080"]

