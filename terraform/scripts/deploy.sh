#!/bin/bash
set -e

APP_DIR="/opt/nukaloot"
SERVICE="$1"
ENV_FILE="$APP_DIR/nukaloot-infra/.env"

if [ -z "$SERVICE" ]; then
  echo "Usage: deploy.sh <api|web|infra|all>"
  exit 1
fi

# Read DOMAIN from .env file (single source of truth)
if [ -f "$ENV_FILE" ]; then
  export DOMAIN=$(grep -oP '(?<=WEB_APP_DOMAIN=).+' "$ENV_FILE" || echo "")
fi

regenerate_nginx() {
  if [ -z "$DOMAIN" ]; then
    echo "ERROR: DOMAIN is empty — refusing to regenerate nginx config"
    exit 1
  fi
  envsubst '$$DOMAIN' < "$APP_DIR/nukaloot-infra/nginx/nginx.conf.template" > "$APP_DIR/nukaloot-infra/nginx/nginx.conf"
  echo "Nginx config regenerated for $DOMAIN"
}

cd "$APP_DIR/nukaloot-infra"

# Free space before pulling new images (images, build cache, dangling volumes)
docker system prune -af

case "$SERVICE" in
  api)
    echo "Deploying API..."
    docker compose -f docker-compose.prod.yml pull api
    docker compose -f docker-compose.prod.yml up -d api
    ;;
  web)
    echo "Deploying Web..."
    regenerate_nginx
    docker compose -f docker-compose.prod.yml pull web
    docker compose -f docker-compose.prod.yml up -d web
    docker compose -f docker-compose.prod.yml restart nginx
    ;;
  infra)
    echo "Deploying Infra..."
    git fetch origin && git reset --hard origin/main
    regenerate_nginx
    docker compose -f docker-compose.prod.yml pull
    docker compose -f docker-compose.prod.yml up -d
    ;;
  all)
    echo "Deploying all..."
    git fetch origin && git reset --hard origin/main
    regenerate_nginx
    docker compose -f docker-compose.prod.yml pull
    docker compose -f docker-compose.prod.yml up -d
    ;;
  *)
    echo "Unknown service: $SERVICE"
    exit 1
    ;;
esac

echo "Deploy complete."
