resource "aws_db_subnet_group" "default" {
  name       = "game-price-db-subnet"
  subnet_ids = data.aws_subnets.default.ids

  tags = {
    Name = "game-price-db-subnet"
  }
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
  password = var.db_password

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
