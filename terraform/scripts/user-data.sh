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
apt-get install -y ca-certificates curl gnupg awscli jq dnsutils certbot
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" > /etc/apt/sources.list.d/docker.list

apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

systemctl enable docker
usermod -aG docker ubuntu

# --- CloudWatch Agent ---
curl -sO https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb
dpkg -i amazon-cloudwatch-agent.deb
rm amazon-cloudwatch-agent.deb

cat <<'CW_CONFIG' > /opt/aws/amazon-cloudwatch-agent/etc/config.json
{
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/cloud-init-output.log",
            "log_group_name": "game-price-finder",
            "log_stream_name": "cloud-init",
            "retention_in_days": 7
          },
          {
            "file_path": "/var/log/letsencrypt/letsencrypt.log",
            "log_group_name": "game-price-finder",
            "log_stream_name": "certbot",
            "retention_in_days": 7
          }
        ]
      }
    }
  }
}
CW_CONFIG

/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config -m ec2 \
  -c file:/opt/aws/amazon-cloudwatch-agent/etc/config.json -s

# --- SSH key for GitHub ---
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
INTERNAL_API_URL=http://api:3000
WEB_APP_DOMAIN=${domain}
ENV
chown ubuntu:ubuntu "$APP_DIR/game-price-infra/.env"

# --- Wait for DNS to resolve to this instance ---
MY_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
for i in $(seq 1 30); do
  RESOLVED=$(dig +short ${domain} @8.8.8.8 2>/dev/null)
  if [ "$RESOLVED" = "$MY_IP" ]; then
    echo "DNS resolved: ${domain} -> $MY_IP"
    break
  fi
  echo "Waiting for DNS... (attempt $i/30, got: $RESOLVED, expected: $MY_IP)"
  sleep 10
done

# --- Get SSL certificate ---
certbot certonly --standalone \
  -d "${domain}" \
  --non-interactive \
  --agree-tos \
  --register-unsafely-without-email

# --- Generate HTTPS nginx config ---
export DOMAIN="${domain}"
envsubst '$$DOMAIN' < "$APP_DIR/game-price-infra/nginx/nginx.conf.template" > "$APP_DIR/game-price-infra/nginx/nginx.conf"

# --- Start services ---
cd "$APP_DIR/game-price-infra"
sudo -u ubuntu docker compose -f docker-compose.prod.yml up -d --build

# --- Cron: cert renewal (twice daily) ---
cat <<'CRON' | crontab -
0 0,12 * * * cd /opt/game-price-finder/game-price-infra && docker compose -f docker-compose.prod.yml stop nginx && certbot renew --quiet && docker compose -f docker-compose.prod.yml start nginx
CRON
