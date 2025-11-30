#!/bin/bash
# ============================================================
# Exercise 04: Lambda Functions - Run Script
# ============================================================

set -e  # Exit on error

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${BLUE}============================================================${NC}"
echo -e "${BLUE}  Exercise 04: Lambda Functions${NC}"
echo -e "${BLUE}============================================================${NC}"
echo ""

# Setup awslocal alias for this script
awslocal="AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test AWS_DEFAULT_REGION=us-east-1 aws --endpoint-url=http://localhost:4566"

echo -e "${YELLOW}Key Concepts:${NC}"
echo "  - aws_lambda_function resource"
echo "  - IAM roles and trust policies"
echo "  - archive_file data source for zipping code"
echo "  - Lambda handler format: file.function"
echo "  - Environment variables"
echo "  - CloudWatch log groups"
echo ""

# Initialize
echo -e "${GREEN}► Initializing Terraform...${NC}"
terraform init -input=false > /dev/null
echo "  ✓ Initialized"
echo ""

# Apply
echo -e "${GREEN}► Deploying Lambda function...${NC}"
terraform apply -auto-approve -input=false
echo ""

# Get function name
FUNCTION_NAME=$(terraform output -raw function_name)

# Show resources
echo -e "${GREEN}► Resources created:${NC}"
terraform state list
echo ""

# Demonstrate IAM role
echo -e "${CYAN}────────────────────────────────────────${NC}"
echo -e "${CYAN}IAM Role Trust Policy:${NC}"
echo -e "${CYAN}────────────────────────────────────────${NC}"
echo ""
echo "principals {"
echo "  type        = \"Service\""
echo "  identifiers = [\"lambda.amazonaws.com\"]"
echo "}"
echo "actions = [\"sts:AssumeRole\"]"
echo ""
echo "This allows Lambda service to assume the role"
echo ""

# Demonstrate archive_file
echo -e "${CYAN}────────────────────────────────────────${NC}"
echo -e "${CYAN}archive_file Data Source:${NC}"
echo -e "${CYAN}────────────────────────────────────────${NC}"
echo ""
echo "data \"archive_file\" \"lambda_zip\" {"
echo "  type        = \"zip\""
echo "  source_dir  = \"\${path.module}/src\""
echo "  output_path = \"\${path.module}/lambda.zip\""
echo "}"
echo ""
echo "Automatically zips your source code for deployment"
echo ""

# Demonstrate handler
echo -e "${CYAN}────────────────────────────────────────${NC}"
echo -e "${CYAN}Lambda Handler Format:${NC}"
echo -e "${CYAN}────────────────────────────────────────${NC}"
echo ""
echo "handler = \"handler.lambda_handler\""
echo ""
echo "Format: <filename_without_extension>.<function_name>"
echo "  - File:     src/handler.py"
echo "  - Function: def lambda_handler(event, context)"
echo ""

# Invoke Lambda
echo -e "${GREEN}► Invoking Lambda function...${NC}"
echo ""
echo "Request: {\"name\": \"Tom\"}"
echo ""
eval "$awslocal lambda invoke --function-name $FUNCTION_NAME --payload '{\"name\": \"Tom\"}' /tmp/lambda-output.json" > /dev/null

echo -e "${GREEN}► Response:${NC}"
cat /tmp/lambda-output.json | python3 -c "import sys,json; d=json.load(sys.stdin); print(json.dumps(json.loads(d['body']), indent=2))"
echo ""

# Try another invocation
echo -e "${GREEN}► Invoking with different name...${NC}"
echo ""
echo "Request: {\"name\": \"World\"}"
eval "$awslocal lambda invoke --function-name $FUNCTION_NAME --payload '{\"name\": \"World\"}' /tmp/lambda-output.json" > /dev/null
echo ""
echo -e "${GREEN}► Response:${NC}"
cat /tmp/lambda-output.json | python3 -c "import sys,json; d=json.load(sys.stdin); print(json.dumps(json.loads(d['body']), indent=2))"
echo ""

# List functions
echo -e "${GREEN}► Lambda functions in LocalStack:${NC}"
eval "$awslocal lambda list-functions --query 'Functions[].FunctionName' --output table"
echo ""

echo -e "${BLUE}============================================================${NC}"
echo -e "${BLUE}  Exercise 04 Complete!${NC}"
echo -e "${BLUE}============================================================${NC}"
echo ""
echo "Invoke manually:"
echo "  awslocal lambda invoke --function-name $FUNCTION_NAME --payload '{\"name\": \"YourName\"}' output.json"
echo ""
echo "Resource Browser: https://app.localstack.cloud/inst/default/resources/lambda"
echo ""
echo "To clean up: terraform destroy"
