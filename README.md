# Game Price Infra

Infrastructure and orchestration for the Game Price Finder project.

## Architecture

```
                    Internet
                       |
                   port 80
                       |
                  +---------+
                  |  Nginx  |
                  +---------+
                       |
                  +---------+
                  | Next.js |  (frontend — only thing exposed to internet)
                  |  (web)  |
                  +---------+
                       |
                  internal only
                       |
                  +---------+
                  | NestJS  |  (API — not accessible from internet)
                  |  (api)  |
                  +---------+
                       |
                  internal only
                       |
                  +---------+
                  |   RDS   |  (PostgreSQL — not accessible from internet)
                  | (db)    |
                  +---------+
```

### Network Security

- **Nginx**: Only service exposed to the internet (port 80). Proxies everything to Next.js.
- **Next.js (web)**: Serves the frontend. API calls from the browser go to Next.js route handlers, which proxy internally to the backend. The browser never talks to the API directly.
- **NestJS (api)**: Runs inside the VPC only. Not accessible from outside. Only Next.js can reach it via Docker's internal network.
- **RDS (PostgreSQL)**: Only accessible from the EC2 instance's security group. Not exposed to the internet. Only the API can connect to it.

**No one outside the VPC can reach the API or the database. Ever.**

---

## AWS Infrastructure (Terraform)

| Resource | Spec | Cost |
|----------|------|------|
| EC2 | t3.micro | Free tier (750 hrs/month, 12 months) |
| RDS | db.t3.micro PostgreSQL 16 | Free tier (750 hrs/month, 12 months) |
| Elastic IP | 1 | Free while instance is running |
| S3 | Terraform state bucket (versioned) | Free tier |
| Secrets Manager | 3 secrets (DB password, DuckDNS token, deploy key) | Free tier (10,000 API calls/month) |
| Domain | DuckDNS subdomain | Free |

### What Terraform creates

- EC2 instance with Docker, 2GB swap, and all three repos cloned
- RDS PostgreSQL with 7-day automatic backups and delete protection
- Security group for EC2 (ports 80 and 22 only)
- Security group for RDS (port 5432 from EC2 only)
- Elastic IP attached to the EC2 instance
- SSH key for GitHub repo access
- IAM role for EC2 with Secrets Manager read access
- **AWS Secrets Manager** secrets for:
  - `game-price/db-password` — auto-generated 32-char PostgreSQL password
  - `game-price/duckdns-token` — DuckDNS API token
  - `game-price/github-deploy-key` — SSH private key for GitHub access

No secrets are hardcoded in the EC2 instance. All sensitive values are fetched at boot time from Secrets Manager via IAM role.

---

## Deployment Guide

### Prerequisites

1. [AWS CLI](https://aws.amazon.com/cli/) installed and configured (`aws configure`)
2. [Terraform](https://www.terraform.io/downloads) >= 1.5 installed
3. A [DuckDNS](https://www.duckdns.org/) account — pick a subdomain and copy your token
4. An SSH key pair for EC2 access (e.g. `~/.ssh/id_rsa.pub`)

### Step 1: Create S3 bucket for Terraform state

This only needs to run once:

```bash
cd terraform
./setup.sh
```

### Step 2: Create `terraform.tfvars`

Create a `terraform.tfvars` file (already in `.gitignore`):

```hcl
duckdns_domain = "game-price"
duckdns_token  = "your-duckdns-token"
```

### Step 3: Deploy infrastructure

```bash
terraform init
terraform apply -var="ssh_public_key_path=/path/to/your/key.pub"
```

The database password is auto-generated and stored in AWS Secrets Manager. No need to set it manually.

### Step 4: Add SSH key to GitHub

After `terraform apply`, copy the `github_deploy_public_key` from the output and add it as an **SSH key** on your GitHub account:

1. Go to https://github.com/settings/keys
2. Click "New SSH key"
3. Paste the key

This gives the EC2 instance read access to all your repos.

### Step 5: Configure CI/CD

Add these secrets to **all three** repos (Settings → Secrets → Actions):

| Secret | Value |
|--------|-------|
| `EC2_HOST` | The `ec2_public_ip` from Terraform output |
| `EC2_SSH_KEY` | Your private SSH key (the one matching `ssh_public_key_path`) |

### Step 6: Done

- Your app is live at `http://<your-subdomain>.duckdns.org`
- Every push to `main` in the API or Web repo triggers automatic deployment
- The database is backed up daily with 7-day retention

---

## Local Development

The `docker-compose.yml` spins up the full stack locally (with PostgreSQL in Docker instead of RDS):

| Service | Port | Description |
|---------|------|-------------|
| **db** | `5434` | PostgreSQL 16 with health checks |
| **api** | `3002` | NestJS backend with hot-reload |
| **web** | `3003` | Next.js frontend with hot-reload |

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

- **Frontend**: http://localhost:3003
- **API**: http://localhost:3002/api

### Hot Reload

Source code is mounted as volumes. Changes to `game-price-api/src/` and `game-price-web/src/` are picked up automatically.

---

## CI/CD

Both `game-price-api` and `game-price-web` have GitHub Actions workflows that deploy on push to `main`:

1. GitHub Actions SSHs into the EC2 instance
2. Pulls the latest code from the repo
3. Rebuilds the Docker container
4. Zero manual intervention

The deploy script is at `terraform/scripts/deploy.sh` and supports:

```bash
deploy.sh api    # Deploy API only
deploy.sh web    # Deploy Web only
deploy.sh infra  # Deploy infra changes
deploy.sh all    # Deploy everything
```

---

## File Structure

```
game-price-infra/
  docker-compose.yml        # Local development
  docker-compose.prod.yml   # Production (Nginx + Web + API, DB is RDS)
  nginx/
    nginx.conf              # Reverse proxy (port 80 → Next.js)
  terraform/
    main.tf                 # AWS provider, S3 backend
    variables.tf            # Input variables
    ec2.tf                  # EC2 instance, key pair, elastic IP
    rds.tf                  # PostgreSQL RDS
    network.tf              # Security groups
    outputs.tf              # IP, domain, SSH command, deploy key
    setup.sh                # One-time S3 bucket creation
    scripts/
      user-data.sh          # EC2 bootstrap (Docker, swap, clone, start)
      deploy.sh             # CI/CD deploy script
```

---

## Related Repos

| Repo | Description |
|------|-------------|
| [game-price-api](https://github.com/padronjosef/game-price-api) | Backend API (NestJS, TypeORM, Playwright) |
| [game-price-web](https://github.com/padronjosef/game-price-web) | Frontend (Next.js, React, Tailwind) |
| **game-price-infra** (this repo) | Docker Compose, Terraform, CI/CD |
