# Game Price Infra

Infrastructure and orchestration for the Game Price Finder project.

## Overview

This repo contains the configuration needed to run the full Game Price Finder stack locally and (in the future) deploy it to the cloud.

## Local Development

The `docker-compose.yml` spins up the entire stack:

| Service | Image | Port | Description |
|---------|-------|------|-------------|
| **db** | `postgres:16-alpine` | `5434` | PostgreSQL database with health checks |
| **api** | Built from `game-price-api` | `3002` | NestJS backend with hot-reload |
| **web** | Built from `game-price-web` | `3003` | Next.js frontend with hot-reload |

### Prerequisites

Clone all three repos as siblings:

```
some-folder/
  game-price-api/
  game-price-web/
  game-price-infra/    <-- you are here
```

### Run

```bash
docker compose up
```

That's it. The app is available at:
- **Frontend**: http://localhost:3003
- **API**: http://localhost:3002/api
- **Database**: `localhost:5434` (user: `postgres`, password: `postgres`, db: `game_prices`)

### Hot Reload

Source code is mounted as volumes, so changes to `game-price-api/src/` and `game-price-web/src/` are picked up automatically without rebuilding containers.

### Rebuild

```bash
docker compose up --build
```

## Related Repos

This project is part of a multi-repo setup. All three repos are needed to run the full stack:

| Repo | Description |
|------|-------------|
| [game-price-api](https://github.com/padronjosef/game-price-api) | Backend API (NestJS, TypeORM, Playwright) |
| [game-price-web](https://github.com/padronjosef/game-price-web) | Frontend (Next.js, React, Tailwind) |
| **game-price-infra** (this repo) | Docker Compose and infrastructure |

## Future

This repo will also house:
- Terraform configs for AWS infrastructure
- Kubernetes manifests
- CI/CD pipeline definitions
- Production Dockerfiles and docker-compose overrides
