variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "db_password" {
  description = "Password for the RDS PostgreSQL database"
  type        = string
  sensitive   = true
}

variable "duckdns_token" {
  description = "DuckDNS token for dynamic DNS"
  type        = string
  sensitive   = true
}

variable "duckdns_domain" {
  description = "DuckDNS subdomain (e.g. 'game-price' for game-price.duckdns.org)"
  type        = string
}

variable "ssh_public_key_path" {
  description = "Path to the SSH public key for EC2 access"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}
