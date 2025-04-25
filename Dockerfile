FROM python:3.10-slim

# 1. System deps + Perl libs for Nikto
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      git curl wget ca-certificates \
      nmap wkhtmltopdf ffuf wafw00f \
      default-jre-headless \
      perl libnet-ssleay-perl libwhisker2-perl libio-socket-ssl-perl && \
    rm -rf /var/lib/apt/lists/*

# 2. Install Nikto
RUN git clone https://github.com/sullo/nikto.git /opt/nikto && \
    ln -s /opt/nikto/program/nikto.pl /usr/local/bin/nikto

# 3. Install testssl.sh
RUN git clone https://github.com/drwetter/testssl.sh.git /opt/testssl.sh && \
    ln -s /opt/testssl.sh/testssl.sh /usr/local/bin/testssl.sh

# 4. Install nuclei (precompiled binary)
RUN curl -sL https://github.com/projectdiscovery/nuclei/releases/latest/download/nuclei-linux-amd64.tar.gz \
    | tar -xz -C /usr/local/bin

WORKDIR /app

# 5. Python deps
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# 6. Copy app code + templates + static
COPY . .

EXPOSE 8080

# 7. Start ZAP then the FastAPI app
CMD zap.sh -daemon -host 0.0.0.0 -port ${ZAP_PORT:-8090} && \
    uvicorn main:app --host 0.0.0.0 --port 8080
