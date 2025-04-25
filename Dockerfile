FROM python:3.10-slim

# 1. System deps + Perl libs for Nikto
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      git curl wget ca-certificates \
      nmap wkhtmltopdf ffuf wafw00f \
      default-jre-headless \
      perl libnet-ssleay-perl libwhisker2-perl libio-socket-ssl-perl && \
    rm -rf /var/lib/apt/lists/*

# 2. Nikto
RUN git clone https://github.com/sullo/nikto.git /opt/nikto && \
    ln -s /opt/nikto/program/nikto.pl /usr/local/bin/nikto

# 3. testssl.sh
RUN git clone https://github.com/drwetter/testssl.sh.git /opt/testssl.sh && \
    ln -s /opt/testssl.sh/testssl.sh /usr/local/bin/testssl.sh

# 4. subfinder (precompiled binary)
RUN curl -L https://github.com/projectdiscovery/subfinder/releases/latest/download/subfinder-linux-amd64.tar.gz \
     -o /tmp/subfinder.tgz \
    && tar -xzf /tmp/subfinder.tgz -C /usr/local/bin \
    && rm /tmp/subfinder.tgz

# 5. nuclei (precompiled binary)
RUN curl -L https://github.com/projectdiscovery/nuclei/releases/latest/download/nuclei-linux-amd64.tar.gz \
     -o /tmp/nuclei.tgz \
    && tar -xzf /tmp/nuclei.tgz -C /usr/local/bin \
    && rm /tmp/nuclei.tgz

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

EXPOSE 8080

CMD zap.sh -daemon -host 0.0.0.0 -port ${ZAP_PORT:-8090} && \
    uvicorn main:app --host 0.0.0.0 --port 8080
