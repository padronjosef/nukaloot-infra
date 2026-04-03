#!/bin/bash
set -e

APP_DIR="/opt/game-price-finder"
SERVICE="$1"
ENV_FILE="$APP_DIR/game-price-infra/.env"

if [ -z "$SERVICE" ]; then
  echo "Usage: deploy.sh <api|web|infra|all>"
  exit 1
fi

# Read DOMAIN from .env file (single source of truth)
if [ -f "$ENV_FILE" ]; then
  export DOMAIN=$(grep -oP '(?<=WEB_APP_DOMAIN=).+' "$ENV_FILE" || echo "")
fi

regenerate_nginx() {
  if [ -n "$DOMAIN" ] && [ -f "$APP_DIR/game-price-infra/nginx/nginx.conf.template" ]; then
    envsubst '$$DOMAIN' < "$APP_DIR/game-price-infra/nginx/nginx.conf.template" > "$APP_DIR/game-price-infra/nginx/nginx.conf"
    echo "Nginx config regenerated for $DOMAIN"
  fi
}

cd "$APP_DIR"

case "$SERVICE" in
  api)
    echo "Deploying API..."
    cd game-price-api && git pull origin main
    cd ../game-price-infra
    grep -q "DB_SSL" .env || echo "DB_SSL=true" >> .env
    docker compose -f docker-compose.prod.yml up -d --build api
    ;;
  web)
    echo "Deploying Web..."
    cd game-price-web && git pull origin main
    cd ../game-price-infra
    docker compose -f docker-compose.prod.yml up -d --build web
    ;;
  infra)
    echo "Deploying Infra..."
    cd game-price-infra && git checkout -- . && git pull origin main
    regenerate_nginx
    docker compose -f docker-compose.prod.yml up -d --build
    ;;
  all)
    echo "Deploying all..."
    cd game-price-api && git pull origin main && cd ..
    cd game-price-web && git pull origin main && cd ..
    cd game-price-infra && git checkout -- . && git pull origin main
    regenerate_nginx
    docker compose -f docker-compose.prod.yml up -d --build
    ;;
  *)
    echo "Unknown service: $SERVICE"
    exit 1
    ;;
esac

echo "Deploy complete."
