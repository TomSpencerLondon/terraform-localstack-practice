#!/bin/bash
# ============================================================
# Exercise 01: Hello S3 - Run Script
# ============================================================

set -e  # Exit on error

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}============================================================${NC}"
echo -e "${BLUE}  Exercise 01: Hello S3${NC}"
echo -e "${BLUE}============================================================${NC}"
echo ""

# Setup awslocal alias for this script
awslocal="AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test AWS_DEFAULT_REGION=us-east-1 aws --endpoint-url=http://localhost:4566"

echo -e "${YELLOW}Key Concepts:${NC}"
echo "  - Provider configuration for LocalStack"
echo "  - Basic resource blocks (aws_s3_bucket)"
echo "  - Variables and outputs"
echo "  - Terraform workflow: init → plan → apply → destroy"
echo ""

# Initialize
echo -e "${GREEN}► Initializing Terraform...${NC}"
terraform init -input=false > /dev/null
echo "  ✓ Initialized"
echo ""

# Apply
echo -e "${GREEN}► Deploying S3 bucket...${NC}"
terraform apply -auto-approve -input=false
echo ""

# Verify
echo -e "${GREEN}► Verifying deployment...${NC}"
echo ""
echo "Buckets in LocalStack:"
eval "$awslocal s3 ls"
echo ""

# Show state
echo -e "${GREEN}► Terraform state:${NC}"
terraform state list
echo ""

# Show outputs
echo -e "${GREEN}► Outputs:${NC}"
terraform output
echo ""

echo -e "${BLUE}============================================================${NC}"
echo -e "${BLUE}  Exercise 01 Complete!${NC}"
echo -e "${BLUE}============================================================${NC}"
echo ""
echo "To clean up: terraform destroy"
echo "To view in browser: https://app.localstack.cloud/inst/default/resources/s3"
