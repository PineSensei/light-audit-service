FROM python:3.10-slim

# 1) System deps
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      git curl wget ca-certificates \
      nmap nikto wkhtmltopdf ffuf wafw00f \
      default-jre-headless golang-go && \
    rm -rf /var/lib/apt/lists/*

# 2) Install subfinder
RUN go install github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest

# 3) Install nuclei
RUN wget -qO- https://github.com/projectdiscovery/nuclei/releases/latest/download/nuclei-linux-amd64.tar.gz \
    | tar -xz -C /usr/local/bin nuclei

WORKDIR /app

# 4) Python deps
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# 5) App code + templates
COPY . .

# 6) Expose port
EXPOSE 8080

# 7) Launch ZAP in background then the FastAPI app
CMD zap.sh -daemon -host 0.0.0.0 -port ${ZAP_PORT:-8090} && \
    uvicorn main:app --host 0.0.0.0 --port 8080
