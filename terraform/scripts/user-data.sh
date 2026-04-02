#!/bin/bash
set -e

APP_DIR="/opt/game-price-finder"

# --- Swap (2GB) ---
fallocate -l 2G /swapfile
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
echo "/swapfile swap swap defaults 0 0" >> /etc/fstab

# --- Install Docker ---
apt-get update -y
apt-get install -y ca-certificates curl gnupg
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" > /etc/apt/sources.list.d/docker.list

apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

systemctl enable docker
usermod -aG docker ubuntu

# --- SSH key for GitHub deploy keys ---
mkdir -p /home/ubuntu/.ssh
cat <<'DEPLOY_KEY' > /home/ubuntu/.ssh/github_deploy
${github_deploy_key}
DEPLOY_KEY
chmod 600 /home/ubuntu/.ssh/github_deploy
chown -R ubuntu:ubuntu /home/ubuntu/.ssh

# Configure SSH to use deploy key for GitHub
cat <<'SSH_CONFIG' > /home/ubuntu/.ssh/config
Host github.com
  HostName github.com
  User git
  IdentityFile /home/ubuntu/.ssh/github_deploy
  IdentitiesOnly yes
  StrictHostKeyChecking no
SSH_CONFIG
chmod 600 /home/ubuntu/.ssh/config
chown ubuntu:ubuntu /home/ubuntu/.ssh/config

# --- Clone repos ---
mkdir -p "$APP_DIR"
chown ubuntu:ubuntu "$APP_DIR"

sudo -u ubuntu git clone git@github.com:padronjosef/game-price-api.git "$APP_DIR/game-price-api"
sudo -u ubuntu git clone git@github.com:padronjosef/game-price-web.git "$APP_DIR/game-price-web"
sudo -u ubuntu git clone git@github.com:padronjosef/game-price-infra.git "$APP_DIR/game-price-infra"

# --- Create .env for production ---
cat <<ENV > "$APP_DIR/game-price-infra/.env"
DB_HOST=${db_host}
DB_PORT=5432
DB_USERNAME=postgres
DB_PASSWORD=${db_password}
DB_NAME=game_prices
INTERNAL_API_URL=http://api:3000
ENV
chown ubuntu:ubuntu "$APP_DIR/game-price-infra/.env"

# --- DuckDNS update ---
curl -s "https://www.duckdns.org/update?domains=${duckdns_domain}&token=${duckdns_token}&ip="

# DuckDNS cron — update IP every 5 minutes
echo "*/5 * * * * curl -s 'https://www.duckdns.org/update?domains=${duckdns_domain}&token=${duckdns_token}&ip=' > /dev/null 2>&1" | crontab -u ubuntu -

# --- Start services ---
cd "$APP_DIR/game-price-infra"
sudo -u ubuntu docker compose -f docker-compose.prod.yml up -d --build
