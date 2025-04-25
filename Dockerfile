# Use a slim Python base image
FROM python:3.10-slim

# Install system dependencies and Perl libs for Nikto
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      git curl wget ca-certificates \
      nmap wkhtmltopdf ffuf wafw00f \
      default-jre-headless \
      perl libnet-ssleay-perl libwhisker2-perl libio-socket-ssl-perl && \
    rm -rf /var/lib/apt/lists/*

# Install Nikto from its GitHub repo
RUN git clone https://github.com/sullo/nikto.git /opt/nikto && \
    ln -s /opt/nikto/program/nikto.pl /usr/local/bin/nikto

# Install testssl.sh for SSL/TLS checks
RUN git clone https://github.com/drwetter/testssl.sh.git /opt/testssl.sh && \
    ln -s /opt/testssl.sh/testssl.sh /usr/local/bin/testssl.sh

# Install subfinder (precompiled binary)
RUN wget -qO /tmp/subfinder.tgz \
     https://github.com/projectdiscovery/subfinder/releases/latest/download/subfinder-linux-amd64.tar.gz && \
    tar -xz -C /usr/local/bin -f /tmp/subfinder.tgz subfinder && \
    rm /tmp/subfinder.tgz

# Install nuclei (precompiled binary)
RUN wget -qO /tmp/nuclei.tgz \
     https://github.com/projectdiscovery/nuclei/releases/latest/download/nuclei-linux-amd64.tar.gz && \
    tar -xz -C /usr/local/bin -f /tmp/nuclei.tgz nuclei && \
    rm /tmp/nuclei.tgz

# Set working directory
WORKDIR /app

# Copy and install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY . .

# Expose the FastAPI port
EXPOSE 8080

# Launch ZAP (daemon) then start the FastAPI app
CMD zap.sh -daemon -host 0.0.0.0 -port ${ZAP_PORT:-8090} && \
    uvicorn main:app --host 0.0.0.0 --port 8080
