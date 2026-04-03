#!/bin/bash
set -e

APP_DIR="/opt/game-price-finder"

# --- Swap (2GB) ---
if [ ! -f /swapfile ]; then
  fallocate -l 2G /swapfile
  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile
  echo "/swapfile swap swap defaults 0 0" >> /etc/fstab
fi

# --- Install Docker ---
apt-get update -y
apt-get install -y ca-certificates curl gnupg awscli jq
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" > /etc/apt/sources.list.d/docker.list

apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

systemctl enable docker
usermod -aG docker ubuntu

# --- SSH key for GitHub deploy keys (from Secrets Manager) ---
GITHUB_DEPLOY_KEY=$(aws secretsmanager get-secret-value \
  --secret-id "${github_deploy_secret_id}" \
  --region "${aws_region}" \
  --query SecretString \
  --output text)

mkdir -p /home/ubuntu/.ssh
echo "$GITHUB_DEPLOY_KEY" > /home/ubuntu/.ssh/github_deploy
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

# --- Fetch secrets from Secrets Manager ---
DB_PASSWORD=$(aws secretsmanager get-secret-value \
  --secret-id "${db_secret_id}" \
  --region "${aws_region}" \
  --query SecretString \
  --output text)

DUCKDNS_TOKEN=$(aws secretsmanager get-secret-value \
  --secret-id "${duckdns_secret_id}" \
  --region "${aws_region}" \
  --query SecretString \
  --output text)

# --- Create .env for production ---
cat <<ENV > "$APP_DIR/game-price-infra/.env"
DB_HOST=${db_host}
DB_PORT=5432
DB_USERNAME=postgres
DB_PASSWORD=$DB_PASSWORD
DB_NAME=game_prices
INTERNAL_API_URL=http://api:3000
ENV
chown ubuntu:ubuntu "$APP_DIR/game-price-infra/.env"

# --- DuckDNS update ---
curl -s "https://www.duckdns.org/update?domains=${duckdns_domain}&token=$DUCKDNS_TOKEN&ip="

# Cron jobs — DuckDNS (every 5 min) + cert renewal (twice daily)
cat <<'CRON' | crontab -
*/5 * * * * DUCKDNS_TOKEN=$(aws secretsmanager get-secret-value --secret-id '${duckdns_secret_id}' --region '${aws_region}' --query SecretString --output text) && curl -s "https://www.duckdns.org/update?domains=${duckdns_domain}&token=$DUCKDNS_TOKEN&ip=" > /dev/null 2>&1
0 0,12 * * * certbot renew --quiet --deploy-hook 'cd /opt/game-price-finder/game-price-infra && docker compose -f docker-compose.prod.yml exec nginx nginx -s reload'
CRON

# --- SSL setup ---
apt-get install -y certbot
mkdir -p /var/www/certbot /etc/letsencrypt

# --- Start services (HTTP-only first, needed for certbot challenge) ---
cd "$APP_DIR/game-price-infra"
sudo -u ubuntu docker compose -f docker-compose.prod.yml up -d --build

# Wait for nginx to be ready
sleep 5

# --- Get SSL certificate ---
certbot certonly --webroot \
  -w /var/www/certbot \
  -d "${duckdns_domain}.duckdns.org" \
  --non-interactive \
  --agree-tos \
  --register-unsafely-without-email

# --- Switch nginx to HTTPS config ---
export DUCKDNS_DOMAIN="${duckdns_domain}"
envsubst '$$DUCKDNS_DOMAIN' < "$APP_DIR/game-price-infra/nginx/nginx.conf.template" > "$APP_DIR/game-price-infra/nginx/nginx.conf"
docker compose -f docker-compose.prod.yml exec nginx nginx -s reload

