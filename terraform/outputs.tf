output "ec2_public_ip" {
  description = "Elastic IP of the EC2 instance"
  value       = aws_eip.app.public_ip
}

output "domain" {
  description = "DuckDNS domain"
  value       = "${var.duckdns_domain}.duckdns.org"
}

output "ssh_command" {
  description = "SSH into the EC2 instance"
  value       = "ssh ubuntu@${aws_eip.app.public_ip}"
}

output "rds_endpoint" {
  description = "RDS PostgreSQL endpoint (internal only)"
  value       = aws_db_instance.postgres.address
}

output "github_deploy_public_key" {
  description = "Add this as a deploy key (read-only) to each GitHub repo"
  value       = tls_private_key.github_deploy.public_key_openssh
}
