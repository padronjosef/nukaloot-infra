resource "aws_db_subnet_group" "default" {
  name       = "game-price-db-subnet"
  subnet_ids = data.aws_subnets.default.ids

  tags = {
    Name = "game-price-db-subnet"
  }
}

# Generate a random password and store it in Secrets Manager
resource "random_password" "db" {
  length  = 32
  special = false # RDS doesn't like some special chars
}

resource "aws_secretsmanager_secret" "db_password" {
  name                    = "game-price/db-password"
  description             = "RDS PostgreSQL password for game-price-db"
  recovery_window_in_days = 7
}

resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id     = aws_secretsmanager_secret.db_password.id
  secret_string = random_password.db.result
}

resource "aws_secretsmanager_secret" "github_deploy_key" {
  name                    = "game-price/github-deploy-key"
  description             = "SSH private key for GitHub deploy access"
  recovery_window_in_days = 7
}

resource "aws_secretsmanager_secret_version" "github_deploy_key" {
  secret_id     = aws_secretsmanager_secret.github_deploy_key.id
  secret_string = tls_private_key.github_deploy.private_key_openssh
}

resource "aws_secretsmanager_secret" "duckdns_token" {
  name                    = "game-price/duckdns-token"
  description             = "DuckDNS token for dynamic DNS"
  recovery_window_in_days = 7
}

resource "aws_secretsmanager_secret_version" "duckdns_token" {
  secret_id     = aws_secretsmanager_secret.duckdns_token.id
  secret_string = var.duckdns_token
}

resource "aws_db_instance" "postgres" {
  identifier = "game-price-db"

  engine         = "postgres"
  engine_version = "16"
  instance_class = "db.t3.micro"

  allocated_storage = 20
  storage_type      = "gp2"

  db_name  = "game_prices"
  username = "postgres"
  password = random_password.db.result

  db_subnet_group_name   = aws_db_subnet_group.default.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  # Free tier and safety
  multi_az            = false
  publicly_accessible = false
  skip_final_snapshot = false
  final_snapshot_identifier = "game-price-db-final"
  deletion_protection       = true

  # Backups — 7 days retention
  backup_retention_period = 7
  backup_window           = "03:00-04:00"

  tags = {
    Name = "game-price-db"
  }
}
