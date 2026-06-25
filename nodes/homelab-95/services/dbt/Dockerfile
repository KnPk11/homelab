# Start from a Python base image compatible with ARM architecture
FROM python:3.11-slim

# Switch to the root user to install system packages
USER root

# Install system dependencies
RUN apt-get update && \
    apt-get install -y git --no-install-recommends && \
    rm -rf /var/lib/apt/lists/*

# Install dbt (core + adapters)
RUN pip install --no-cache-dir dbt-core dbt-bigquery dbt-postgres

# Copy your entrypoint script into the image
COPY entrypoint.sh /usr/local/bin/entrypoint.sh

# Make it executable
RUN chmod +x /usr/local/bin/entrypoint.sh

# Set the working directory
WORKDIR /usr/app

# Set the entrypoint to your wrapper script
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
