#!/bin/bash
set -e

BUCKET_NAME="game-price-finder-tfstate"
REGION="us-east-1"

echo "Creating S3 bucket for Terraform state..."

# Create bucket
aws s3api create-bucket \
  --bucket "$BUCKET_NAME" \
  --region "$REGION" 2>/dev/null || echo "Bucket already exists, continuing..."

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket "$BUCKET_NAME" \
  --versioning-configuration Status=Enabled

# Block public access
aws s3api put-public-access-block \
  --bucket "$BUCKET_NAME" \
  --public-access-block-configuration \
    BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

echo "S3 bucket '$BUCKET_NAME' is ready with versioning enabled."
echo "Run: terraform init && terraform apply"
