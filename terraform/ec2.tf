# SSH key pair for EC2 access
resource "aws_key_pair" "deployer" {
  key_name   = "game-price-deployer"
  public_key = file(var.ssh_public_key_path)
}

# Generate SSH key for GitHub access (repo cloning)
resource "tls_private_key" "github_deploy" {
  algorithm = "ED25519"
}

# Latest Ubuntu 22.04 AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# IAM role so EC2 can read secrets from Secrets Manager
resource "aws_iam_role" "ec2_app" {
  name = "game-price-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "ec2_secrets" {
  name = "read-secrets"
  role = aws_iam_role.ec2_app.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue"]
      Resource = [
        aws_secretsmanager_secret.db_password.arn,
        aws_secretsmanager_secret.duckdns_token.arn,
        aws_secretsmanager_secret.github_deploy_key.arn,
      ]
    }]
  })
}

resource "aws_iam_instance_profile" "ec2_app" {
  name = "game-price-ec2-profile"
  role = aws_iam_role.ec2_app.name
}

resource "aws_instance" "app" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.micro"
  key_name               = aws_key_pair.deployer.key_name
  vpc_security_group_ids = [aws_security_group.ec2.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_app.name

  user_data = templatefile("${path.module}/scripts/user-data.sh", {
    db_host                = aws_db_instance.postgres.address
    db_secret_id           = aws_secretsmanager_secret.db_password.id
    duckdns_secret_id      = aws_secretsmanager_secret.duckdns_token.id
    github_deploy_secret_id = aws_secretsmanager_secret.github_deploy_key.id
    aws_region             = var.aws_region
    duckdns_domain         = var.duckdns_domain
  })

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  tags = {
    Name = "game-price-app"
  }
}

resource "aws_eip" "app" {
  instance = aws_instance.app.id
  domain   = "vpc"

  tags = {
    Name = "game-price-app"
  }
}
