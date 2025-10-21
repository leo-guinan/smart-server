# Smart Server Docker Image
# Useful for testing locally before deploying to Hetzner

FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies
RUN apt-get update && apt-get install -y \
    jq \
    curl \
    nginx \
    sudo \
    && rm -rf /var/lib/apt/lists/*

# Create smart user
RUN useradd -r -s /bin/bash -m -d /opt/smart smart

# Copy application files
COPY --chown=smart:smart . /opt/smart-repo/

# Run installation (but skip systemd parts in container)
RUN cd /opt/smart-repo && \
    mkdir -p /opt/smart/{bin,experiments,var/runs,www} && \
    cp smart.conf /opt/smart/ && \
    cp context.md /opt/smart/ && \
    cp -r bin/* /opt/smart/bin/ && \
    cp -r experiments/* /opt/smart/experiments/ && \
    chmod +x /opt/smart/bin/*.sh && \
    chmod +x /opt/smart/experiments/*/[!m]*.sh && \
    sed -i 's|BASE_DIR=.*|BASE_DIR="/opt/smart"|' /opt/smart/smart.conf && \
    chown -R smart:smart /opt/smart

# Configure nginx
RUN rm /etc/nginx/sites-enabled/default && \
    echo 'server { \
        listen 80; \
        server_name _; \
        root /opt/smart/www; \
        index index.html; \
        location / { try_files $uri $uri/ =404; } \
        location /state.json { \
            alias /opt/smart/var/state.json; \
            add_header Cache-Control "no-store, no-cache, must-revalidate"; \
        } \
        location /runs/ { alias /opt/smart/var/runs/; autoindex on; } \
    }' > /etc/nginx/sites-available/smart-server && \
    ln -s /etc/nginx/sites-available/smart-server /etc/nginx/sites-enabled/

# Allow smart user to manage nginx
RUN echo "smart ALL=(ALL) NOPASSWD: /usr/sbin/nginx -t" >> /etc/sudoers && \
    echo "smart ALL=(ALL) NOPASSWD: /bin/systemctl reload nginx" >> /etc/sudoers && \
    echo "smart ALL=(ALL) NOPASSWD: /bin/sed -i* * /etc/nginx/nginx.conf" >> /etc/sudoers

EXPOSE 80

# Start nginx and run experiment on startup
CMD nginx && su - smart -c "/opt/smart/bin/agent.sh" && tail -f /opt/smart/var/experiment.log

