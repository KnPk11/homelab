FROM apache/airflow:3.0.4

USER root

# Install ffmpeg and restic
RUN apt-get update && \
    apt-get install -y ffmpeg curl bzip2 && \
    curl -L https://github.com/restic/restic/releases/download/v0.16.4/restic_0.16.4_linux_amd64.bz2 \
      -o /usr/local/bin/restic.bz2 && \
    bunzip2 /usr/local/bin/restic.bz2 && \
    chmod +x /usr/local/bin/restic && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Copy and set permissions for entrypoint
COPY entrypoint.sh /entrypoint.sh
RUN chown airflow:root /entrypoint.sh && chmod 755 /entrypoint.sh

# Add Docker's official GPG key and set up the repository
RUN apt-get update && apt-get install -y ca-certificates curl
RUN install -m 0755 -d /etc/apt/keyrings
RUN curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
RUN chmod a+r /etc/apt/keyrings/docker.asc
RUN echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null

# Update package lists and install the Docker CLI
RUN apt-get update && apt-get install -y docker-ce-cli

USER airflow

# Install yt-dlp
RUN pip install --no-cache-dir yt-dlp

# Use the entrypoint inside the container
ENTRYPOINT ["/entrypoint.sh"]