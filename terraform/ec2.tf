# SSH key pair for EC2 access
resource "aws_key_pair" "deployer" {
  key_name   = "nukaloot-deployer"
  public_key = file(var.ssh_public_key_path)
}

# Generate SSH key for GitHub access (repo cloning)
resource "tls_private_key" "github_deploy" {
  algorithm = "ED25519"
}

resource "aws_instance" "app" {
  ami                         = var.ami_id
  instance_type               = "t4g.micro"
  key_name                    = aws_key_pair.deployer.key_name
  iam_instance_profile        = aws_iam_instance_profile.ec2.name
  vpc_security_group_ids      = [aws_security_group.ec2.id]
  associate_public_ip_address = true

  user_data = templatefile("${path.module}/scripts/user-data.sh", {
    github_deploy_key = tls_private_key.github_deploy.private_key_openssh
    domain            = var.domain
  })

  root_block_device {
    volume_size = 15
    volume_type = "gp3"
  }

  tags = {
    Name = "nukaloot-app"
  }

  lifecycle {
    ignore_changes = [ami, user_data]
  }
}
