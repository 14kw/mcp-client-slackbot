# Use Python 3.10 slim image
FROM python:3.10-slim

# Install Node.js, npm, and Google Cloud SDK for MCP servers and GCS sync
RUN apt-get update && apt-get install -y \
    nodejs \
    npm \
    curl \
    gnupg \
    lsb-release \
    && echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | tee -a /etc/apt/sources.list.d/google-cloud-sdk.list \
    && curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key --keyring /usr/share/keyrings/cloud.google.gpg add - \
    && apt-get update && apt-get install -y google-cloud-cli \
    && rm -rf /var/lib/apt/lists/*

# Install uvx globally
RUN pip install --no-cache-dir uv

# Set working directory
WORKDIR /app

# Copy requirements first for better caching
COPY mcp_simple_slackbot/requirements.txt .

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY mcp_simple_slackbot/ .

# Create directory for persistent database
RUN mkdir -p /data

# Set environment variable for database path
ENV DB_PATH=/data/test.db

# Make entrypoint script executable
RUN chmod +x /app/entrypoint.sh

# Expose port (Cloud Run will set PORT environment variable)
EXPOSE 8080

# Run the application via entrypoint script
ENTRYPOINT ["/app/entrypoint.sh"]
