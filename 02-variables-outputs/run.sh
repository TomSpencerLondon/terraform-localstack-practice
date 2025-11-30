#!/bin/bash
# ============================================================
# Exercise 02: Variables & Outputs - Run Script
# ============================================================

set -e  # Exit on error

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${BLUE}============================================================${NC}"
echo -e "${BLUE}  Exercise 02: Variables & Outputs${NC}"
echo -e "${BLUE}============================================================${NC}"
echo ""

# Setup awslocal alias for this script
awslocal="AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test AWS_DEFAULT_REGION=us-east-1 aws --endpoint-url=http://localhost:4566"

echo -e "${YELLOW}Key Concepts:${NC}"
echo "  - Variable types: string, number, bool, list, map, object"
echo "  - locals {} for computed values"
echo "  - for_each vs count for multiple resources"
echo "  - Conditional resources: count = condition ? 1 : 0"
echo "  - Output expressions and formatting"
echo ""

# Initialize
echo -e "${GREEN}► Initializing Terraform...${NC}"
terraform init -input=false > /dev/null
echo "  ✓ Initialized"
echo ""

# Apply
echo -e "${GREEN}► Deploying resources...${NC}"
terraform apply -auto-approve -input=false
echo ""

# Show resources created
echo -e "${GREEN}► Resources created:${NC}"
terraform state list
echo ""

# Demonstrate for_each
echo -e "${CYAN}────────────────────────────────────────${NC}"
echo -e "${CYAN}for_each pattern (named resources):${NC}"
echo -e "${CYAN}────────────────────────────────────────${NC}"
echo ""
echo "resource \"aws_s3_bucket\" \"buckets\" {"
echo "  for_each = var.buckets"
echo "  bucket   = \"\${local.name_prefix}-\${each.key}\""
echo "}"
echo ""
echo "Result: buckets[\"logs\"], buckets[\"data\"], buckets[\"backup\"]"
echo ""

# Demonstrate count
echo -e "${CYAN}────────────────────────────────────────${NC}"
echo -e "${CYAN}count pattern (indexed resources):${NC}"
echo -e "${CYAN}────────────────────────────────────────${NC}"
echo ""
echo "resource \"aws_s3_bucket\" \"counted_buckets\" {"
echo "  count  = var.bucket_count"
echo "  bucket = \"\${local.name_prefix}-counted-\${count.index}\""
echo "}"
echo ""
echo "Result: counted_buckets[0], counted_buckets[1], counted_buckets[2]"
echo ""

# Demonstrate filtering
echo -e "${CYAN}────────────────────────────────────────${NC}"
echo -e "${CYAN}Filtering with for expressions:${NC}"
echo -e "${CYAN}────────────────────────────────────────${NC}"
echo ""
echo "versioned_buckets = {"
echo "  for name, config in var.buckets : name => config"
echo "  if config.versioning"
echo "}"
echo ""
echo "Only buckets with versioning=true get versioning enabled"
echo ""

# Show outputs
echo -e "${GREEN}► Outputs:${NC}"
terraform output
echo ""

# List buckets
echo -e "${GREEN}► S3 Buckets in LocalStack:${NC}"
eval "$awslocal s3 ls"
echo ""

echo -e "${BLUE}============================================================${NC}"
echo -e "${BLUE}  Exercise 02 Complete!${NC}"
echo -e "${BLUE}============================================================${NC}"
echo ""
echo "Shell tip: Use single quotes for resource addresses with brackets:"
echo "  terraform state show 'aws_s3_bucket.buckets[\"logs\"]'"
echo ""
echo "To clean up: terraform destroy"
