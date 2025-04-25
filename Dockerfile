FROM python:3.10-slim

# 1) System dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      nmap nikto wkhtmltopdf ffuf wafw00f curl git go && \
    rm -rf /var/lib/apt/lists/*

# 2) Install subfinder
RUN go install github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest

# 3) Install nuclei
RUN curl -sL https://github.com/projectdiscovery/nuclei/releases/latest/download/nuclei-linux-amd64.tar.gz \
    | tar -xz -C /usr/local/bin nuclei

WORKDIR /app

# 4) Python deps
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# 5) App code + templates
COPY . .

EXPOSE 8080
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8080"]
