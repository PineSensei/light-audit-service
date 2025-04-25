# 1. Base image
FROM python:3.10-slim

# 2. System dependencies + Perl libs for Nikto
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      git curl wget ca-certificates \
      nmap wkhtmltopdf ffuf wafw00f \
      default-jre-headless \
      perl libnet-ssleay-perl libwhisker2-perl libio-socket-ssl-perl && \
    rm -rf /var/lib/apt/lists/*

# 3. Nikto from GitHub
RUN git clone https://github.com/sullo/nikto.git /opt/nikto && \
    ln -s /opt/nikto/program/nikto.pl /usr/local/bin/nikto

# 4. testssl.sh for SSL/TLS checks
RUN git clone https://github.com/drwetter/testssl.sh.git /opt/testssl.sh && \
    ln -s /opt/testssl.sh/testssl.sh /usr/local/bin/testssl.sh

# 5. subfinder (latest precompiled)
RUN curl -sL https://github.com/projectdiscovery/subfinder/releases/latest/download/subfinder-linux-amd64.tar.gz \
    | tar -xz -C /usr/local/bin

# 6. nuclei (latest precompiled)
RUN curl -sL https://github.com/projectdiscovery/nuclei/releases/latest/download/nuclei-linux-amd64.tar.gz \
    | tar -xz -C /usr/local/bin

# 7. Set working directory
WORKDIR /app

# 8. Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# 9. Copy app code + templates + static
COPY . .

# 10. Expose port
EXPOSE 8080

# 11. Launch ZAP (daemon) and then FastAPI
CMD zap.sh -daemon -host 0.0.0.0 -port ${ZAP_PORT:-8090} && \
    uvicorn main:app --host 0.0.0.0 --port 8080
