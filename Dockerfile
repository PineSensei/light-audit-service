FROM python:3.10-slim

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      git curl wget ca-certificates \
      nmap wkhtmltopdf ffuf wafw00f \
      default-jre-headless \
      perl libnet-ssleay-perl libwhisker2-perl libio-socket-ssl-perl && \
    rm -rf /var/lib/apt/lists/*

# Nikto
RUN git clone https://github.com/sullo/nikto.git /opt/nikto && \
    ln -s /opt/nikto/program/nikto.pl /usr/local/bin/nikto

# testssl.sh
RUN git clone https://github.com/drwetter/testssl.sh.git /opt/testssl.sh && \
    ln -s /opt/testssl.sh/testssl.sh /usr/local/bin/testssl.sh

# subfinder v2.6.8
ENV SUBFINDER_VERSION=2.6.8
RUN wget -qO /tmp/subfinder.tgz \
     https://github.com/projectdiscovery/subfinder/releases/download/v${SUBFINDER_VERSION}/subfinder_${SUBFINDER_VERSION}_linux_amd64.tar.gz && \
    tar -xz -C /usr/local/bin -f /tmp/subfinder.tgz && \
    rm /tmp/subfinder.tgz

# nuclei (latest)
RUN wget -qO /tmp/nuclei.tgz \
     https://github.com/projectdiscovery/nuclei/releases/latest/download/nuclei-linux-amd64.tar.gz && \
    tar -xz -C /usr/local/bin -f /tmp/nuclei.tgz && \
    rm /tmp/nuclei.tgz

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

EXPOSE 8080

CMD zap.sh -daemon -host 0.0.0.0 -port ${ZAP_PORT:-8090} && \
    uvicorn main:app --host 0.0.0.0 --port 8080
