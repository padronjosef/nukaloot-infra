variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "domain" {
  description = "Domain name (e.g. game-price-finder.com)"
  type        = string
}

variable "ami_id" {
  description = "AMI ID for the EC2 instance (Ubuntu 22.04)"
  type        = string
  default     = "ami-00de3875b03809ec5"
}

variable "ssh_public_key_path" {
  description = "Path to the SSH public key for EC2 access"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}
