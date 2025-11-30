#!/bin/bash
# ============================================================
# Exercise 03: S3 Static Website - Run Script
# ============================================================

set -e  # Exit on error

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${BLUE}============================================================${NC}"
echo -e "${BLUE}  Exercise 03: S3 Static Website${NC}"
echo -e "${BLUE}============================================================${NC}"
echo ""

# Setup awslocal alias for this script
awslocal="AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test AWS_DEFAULT_REGION=us-east-1 aws --endpoint-url=http://localhost:4566"

echo -e "${YELLOW}Key Concepts:${NC}"
echo "  - S3 static website hosting configuration"
echo "  - Bucket policies for public access"
echo "  - templatefile() for dynamic HTML content"
echo "  - aws_s3_object for uploading files"
echo "  - Content types (MIME types)"
echo "  - depends_on for resource ordering"
echo ""

# Initialize
echo -e "${GREEN}► Initializing Terraform...${NC}"
terraform init -input=false > /dev/null
echo "  ✓ Initialized"
echo ""

# Apply
echo -e "${GREEN}► Deploying static website...${NC}"
terraform apply -auto-approve -input=false
echo ""

# Get bucket name
BUCKET_NAME=$(terraform output -raw bucket_name)

# Show website files
echo -e "${GREEN}► Website files uploaded:${NC}"
eval "$awslocal s3 ls s3://$BUCKET_NAME/"
echo ""

# Demonstrate templatefile
echo -e "${CYAN}────────────────────────────────────────${NC}"
echo -e "${CYAN}templatefile() function:${NC}"
echo -e "${CYAN}────────────────────────────────────────${NC}"
echo ""
echo "content = templatefile(\"website/index.html\", {"
echo "  site_name   = var.site_name"
echo "  author      = var.author"
echo "  environment = var.environment"
echo "})"
echo ""
echo "In HTML: <h1>\${site_name}</h1>"
echo "Result:  <h1>My Terraform Website</h1>"
echo ""

# Demonstrate bucket policy
echo -e "${CYAN}────────────────────────────────────────${NC}"
echo -e "${CYAN}Bucket policy for public access:${NC}"
echo -e "${CYAN}────────────────────────────────────────${NC}"
echo ""
echo "Statement = [{"
echo "  Effect    = \"Allow\""
echo "  Principal = \"*\""
echo "  Action    = \"s3:GetObject\""
echo "  Resource  = \"\${bucket_arn}/*\""
echo "}]"
echo ""

# Show website content
echo -e "${GREEN}► Website preview (index.html):${NC}"
echo ""
curl -s "http://localhost:4566/$BUCKET_NAME/index.html" | head -20
echo ""
echo "..."
echo ""

# Website URL
WEBSITE_URL="http://localhost:4566/$BUCKET_NAME/index.html"
echo -e "${GREEN}► Website URL:${NC}"
echo "  $WEBSITE_URL"
echo ""

echo -e "${BLUE}============================================================${NC}"
echo -e "${BLUE}  Exercise 03 Complete!${NC}"
echo -e "${BLUE}============================================================${NC}"
echo ""
echo "View in browser: $WEBSITE_URL"
echo "Resource Browser: https://app.localstack.cloud/inst/default/resources/s3/$BUCKET_NAME"
echo ""
echo "To clean up: terraform destroy"
