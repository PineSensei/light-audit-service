# 1. Base image
FROM python:3.10-slim

# 2. System deps + Perl libs for Nikto
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      git curl wget ca-certificates \
      nmap wkhtmltopdf ffuf wafw00f \
      default-jre-headless \
      perl libnet-ssleay-perl libwhisker2-perl libio-socket-ssl-perl && \
    rm -rf /var/lib/apt/lists/*

# 3. Install Nikto (from GitHub)
RUN git clone https://github.com/sullo/nikto.git /opt/nikto && \
    ln -s /opt/nikto/program/nikto.pl /usr/local/bin/nikto

# 4. Install testssl.sh
RUN git clone https://github.com/drwetter/testssl.sh.git /opt/testssl.sh && \
    ln -s /opt/testssl.sh/testssl.sh /usr/local/bin/testssl.sh

# 5. Pin & install subfinder v2.7.0
ENV SUBFINDER_VERSION=2.7.0
RUN wget -qO /tmp/subfinder.tgz \
     https://github.com/projectdiscovery/subfinder/releases/download/v${SUBFINDER_VERSION}/subfinder_${SUBFINDER_VERSION}_linux_amd64.tar.gz && \
    tar -xz -C /usr/local/bin -f /tmp/subfinder.tgz && \
    rm /tmp/subfinder.tgz

# 6. Pin & install nuclei v2.10.9 (latest at time of writing)
ENV NUCLEI_VERSION=2.10.9
RUN wget -qO /tmp/nuclei.tgz \
     https://github.com/projectdiscovery/nuclei/releases/download/v${NUCLEI_VERSION}/nuclei_${NUCLEI_VERSION}_linux_amd64.tar.gz && \
    tar -xz -C /usr/local/bin -f /tmp/nuclei.tgz && \
    rm /tmp/nuclei.tgz

# 7. Working dir
WORKDIR /app

# 8. Python deps
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# 9. App code + templates + static
COPY . .

# 10. Expose port
EXPOSE 8080

# 11. Start ZAP (daemon) then FastAPI
CMD zap.sh -daemon -host 0.0.0.0 -port ${ZAP_PORT:-8090} && \
    uvicorn main:app --host 0.0.0.0 --port 8080
