# SSH key pair for EC2 access
resource "aws_key_pair" "deployer" {
  key_name   = "game-price-deployer"
  public_key = file(var.ssh_public_key_path)
}

# Generate SSH key for GitHub deploy keys (repo cloning)
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

resource "aws_instance" "app" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.micro"
  key_name               = aws_key_pair.deployer.key_name
  vpc_security_group_ids = [aws_security_group.ec2.id]

  user_data = templatefile("${path.module}/scripts/user-data.sh", {
    github_deploy_key = tls_private_key.github_deploy.private_key_openssh
    db_host           = aws_db_instance.postgres.address
    db_password       = var.db_password
    duckdns_token     = var.duckdns_token
    duckdns_domain    = var.duckdns_domain
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
