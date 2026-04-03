#!/bin/bash
set -e

APP_DIR="/opt/game-price-finder"
SERVICE="$1"

if [ -z "$SERVICE" ]; then
  echo "Usage: deploy.sh <api|web|infra|all>"
  exit 1
fi

cd "$APP_DIR"

case "$SERVICE" in
  api)
    echo "Deploying API..."
    cd game-price-api && git pull origin main
    cd ../game-price-infra
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
    # Re-generate HTTPS nginx config
    export DOMAIN=$(grep -oP '(?<=server_name )[^;]+' nginx/nginx.conf.template 2>/dev/null || echo "")
    if [ -d /etc/letsencrypt/live ]; then
      DOMAIN=$(ls /etc/letsencrypt/live/ | head -1)
      export DOMAIN
      envsubst '$$DOMAIN' < nginx/nginx.conf.template > nginx/nginx.conf
    fi
    docker compose -f docker-compose.prod.yml up -d --build
    ;;
  all)
    echo "Deploying all..."
    cd game-price-api && git pull origin main && cd ..
    cd game-price-web && git pull origin main && cd ..
    cd game-price-infra && git checkout -- . && git pull origin main
    if [ -d /etc/letsencrypt/live ]; then
      DOMAIN=$(ls /etc/letsencrypt/live/ | head -1)
      export DOMAIN
      envsubst '$$DOMAIN' < nginx/nginx.conf.template > nginx/nginx.conf
    fi
    docker compose -f docker-compose.prod.yml up -d --build
    ;;
  *)
    echo "Unknown service: $SERVICE"
    exit 1
    ;;
esac

echo "Deploy complete."
