# Game Price Infra

Infrastructure and orchestration for the Game Price Finder project. Docker Compose for local dev, Terraform for AWS production.

## Tech Stack

- Docker Compose (dev and prod)
- Terraform (AWS provisioning)
- Nginx (reverse proxy, SSL termination)
- Let's Encrypt / Certbot (auto-renewing SSL)
- GitHub Actions (CI/CD)

## Architecture

```
Internet --> Nginx (SSL, ports 80/443) --> Next.js Web --> NestJS API --> RDS PostgreSQL
```

- **Nginx**: Only service exposed to the internet. HTTP redirects to HTTPS.
- **Next.js (web)**: Serves the frontend. Proxies API calls internally to the backend.
- **NestJS (api)**: Internal only. Only reachable via Docker's internal network.
- **RDS (PostgreSQL)**: Internal only. Only reachable from the EC2 security group.

No one outside the VPC can reach the API or the database.

## Getting Started

### Prerequisites

- Docker installed
- All 3 repos cloned as siblings:

```
parent-folder/
  game-price-api/
  game-price-web/
  game-price-infra/    <-- you are here
```

### Development

```bash
docker compose up
```

| Service | Port | Description |
|---------|------|-------------|
| **web** | `3003` | Next.js frontend with hot-reload |
| **api** | `3002` | NestJS backend with hot-reload |
| **db** | `5434` | PostgreSQL 16 |

Source code is mounted as volumes. Changes to `game-price-api/src/` and `game-price-web/src/` are picked up automatically.

### Environment Variables

`deploy.sh` reads `WEB_APP_DOMAIN` from `.env` for nginx config regeneration.

## AWS Infrastructure (Terraform)

| Resource | Spec |
|----------|------|
| EC2 | t3.micro |
| RDS | db.t3.micro, PostgreSQL 16, 7-day backups, deletion protection |
| Elastic IP | 1 (attached to EC2) |
| S3 | Terraform state bucket (versioned) |
| Secrets Manager | DB password + GitHub deploy key |
| CloudWatch | Log agent, 7-day retention |

EC2 has `prevent_destroy` lifecycle and `ignore_changes` on ami/user_data. AMI is pinned as a variable in tfvars (gitignored).

### Terraform Setup

```bash
cd terraform
./setup.sh                    # One-time: create S3 state bucket
# Create terraform.tfvars with duckdns_domain and duckdns_token
terraform init
terraform apply -var="ssh_public_key_path=/path/to/key.pub"
```

After apply: add the `github_deploy_public_key` output as an SSH key on your GitHub account. Add `EC2_HOST` and `EC2_SSH_KEY` as secrets to all 3 repos for CI/CD.

## Project Structure

```
game-price-infra/
  docker-compose.yml          # Local development
  docker-compose.prod.yml     # Production (Nginx + Web + API, DB is RDS)
  nginx/
    nginx.conf.template       # Nginx template with SSL
    nginx.conf                # Generated (do not edit)
  terraform/
    main.tf                   # AWS provider, S3 backend
    variables.tf              # Input variables
    ec2.tf                    # EC2 instance, key pair, elastic IP
    rds.tf                    # PostgreSQL RDS
    network.tf                # Security groups
    outputs.tf                # IP, domain, SSH command, deploy key
    setup.sh                  # One-time S3 bucket creation
    scripts/
      user-data.sh            # EC2 bootstrap (Docker, swap, clone, start)
      deploy.sh               # CI/CD deploy script
```

## Deployment

GitHub Actions deploys on push to `main` for both API and Web repos via SSH to EC2.

```bash
deploy.sh api    # Deploy API only
deploy.sh web    # Deploy Web only
deploy.sh infra  # Deploy infra changes
deploy.sh all    # Deploy everything
```

SSL certificates are obtained via Let's Encrypt at bootstrap and auto-renewed twice daily via cron.

## Auto-Versioning

All 3 repos use the same convention: prefix commit messages with `[major]`, `[minor]`, or `[patch]` to auto-bump versions via GitHub Actions.

## Related Repos

| Repo | Description |
|------|-------------|
| [game-price-api](https://github.com/padronjosef/game-price-api) | Backend API (NestJS, TypeORM, Playwright) |
| [game-price-web](https://github.com/padronjosef/game-price-web) | Frontend (Next.js, React, Tailwind) |
