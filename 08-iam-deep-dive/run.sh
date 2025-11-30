#!/bin/bash
# ============================================================
# Exercise 08: IAM Deep Dive - Run Script
# ============================================================

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}============================================================${NC}"
echo -e "${BLUE}  Exercise 08: IAM Deep Dive${NC}"
echo -e "${BLUE}============================================================${NC}"
echo ""

echo -e "${YELLOW}Key Concepts:${NC}"
echo "  - IAM Users (humans with passwords/keys)"
echo "  - IAM Groups (collections of users)"
echo "  - IAM Roles (for services to assume)"
echo "  - IAM Policies (JSON permission documents)"
echo "  - Trust Policies (who can assume a role)"
echo "  - Permission Policies (what they can do)"
echo ""

# Initialize
echo -e "${GREEN}► Initializing Terraform...${NC}"
terraform init -input=false > /dev/null
echo "  ✓ Initialized"
echo ""

# Apply
echo -e "${GREEN}► Creating IAM resources...${NC}"
terraform apply -auto-approve -input=false 2>&1 | grep -E "(Apply|created|Creation|complete)" | head -20
echo ""

echo -e "${GREEN}► Resources created:${NC}"
echo ""

# Show users
echo -e "${CYAN}────────────────────────────────────────${NC}"
echo -e "${CYAN}IAM USERS:${NC}"
echo -e "${CYAN}────────────────────────────────────────${NC}"
echo ""
awslocal iam list-users --query 'Users[].UserName' --output table 2>/dev/null || echo "  (list users failed)"
echo ""

# Show groups
echo -e "${CYAN}────────────────────────────────────────${NC}"
echo -e "${CYAN}IAM GROUPS:${NC}"
echo -e "${CYAN}────────────────────────────────────────${NC}"
echo ""
echo "  developers:"
awslocal iam get-group --group-name developers --query 'Users[].UserName' --output text 2>/dev/null | tr '\t' '\n' | sed 's/^/    - /' || echo "    (failed)"
echo ""
echo "  read-only:"
awslocal iam get-group --group-name read-only --query 'Users[].UserName' --output text 2>/dev/null | tr '\t' '\n' | sed 's/^/    - /' || echo "    (failed)"
echo ""

# Show roles
echo -e "${CYAN}────────────────────────────────────────${NC}"
echo -e "${CYAN}IAM ROLES:${NC}"
echo -e "${CYAN}────────────────────────────────────────${NC}"
echo ""
awslocal iam list-roles --query 'Roles[?starts_with(RoleName, `iam-demo`)].RoleName' --output table 2>/dev/null || echo "  (list roles failed)"
echo ""

# Users vs Roles explanation
echo -e "${CYAN}────────────────────────────────────────${NC}"
echo -e "${CYAN}USERS vs ROLES:${NC}"
echo -e "${CYAN}────────────────────────────────────────${NC}"
echo ""
echo "  ┌─────────────────┬─────────────────────────────────────┐"
echo "  │     USERS       │     ROLES                           │"
echo "  ├─────────────────┼─────────────────────────────────────┤"
echo "  │ For humans      │ For services (Lambda, EC2, etc.)    │"
echo "  │ Has password    │ No password - assumed via trust     │"
echo "  │ Permanent       │ Temporary credentials               │"
echo "  │ alice, bob      │ lambda-execution, api-gateway       │"
echo "  └─────────────────┴─────────────────────────────────────┘"
echo ""

# Policy example
echo -e "${CYAN}────────────────────────────────────────${NC}"
echo -e "${CYAN}POLICY STRUCTURE:${NC}"
echo -e "${CYAN}────────────────────────────────────────${NC}"
echo ""
echo '  {
    "Effect": "Allow",        ← Allow or Deny
    "Action": [               ← What operations
      "s3:GetObject",
      "s3:PutObject"
    ],
    "Resource": [             ← On what resources
      "arn:aws:s3:::my-bucket/*"
    ],
    "Condition": {            ← Optional conditions
      "IpAddress": {"aws:SourceIp": "10.0.0.0/8"}
    }
  }'
echo ""

# Trust vs Permission
echo -e "${CYAN}────────────────────────────────────────${NC}"
echo -e "${CYAN}TWO TYPES OF POLICIES:${NC}"
echo -e "${CYAN}────────────────────────────────────────${NC}"
echo ""
echo "  1. TRUST POLICY (attached to Role)"
echo "     → WHO can assume this role?"
echo "     → Example: Lambda service can assume"
echo ""
echo "  2. PERMISSION POLICY (attached to User/Group/Role)"
echo "     → WHAT can they do?"
echo "     → Example: Can read/write to S3"
echo ""

# Show trust policy example
echo -e "${GREEN}► Lambda Role Trust Policy:${NC}"
echo ""
awslocal iam get-role --role-name iam-demo-dev-lambda-execution \
  --query 'Role.AssumeRolePolicyDocument' 2>/dev/null | python3 -m json.tool || echo "  (failed to get trust policy)"
echo ""

# Least privilege
echo -e "${CYAN}────────────────────────────────────────${NC}"
echo -e "${CYAN}PRINCIPLE OF LEAST PRIVILEGE:${NC}"
echo -e "${CYAN}────────────────────────────────────────${NC}"
echo ""
echo -e "  ${RED}BAD:${NC}  \"Action\": \"*\", \"Resource\": \"*\""
echo "        (Full access to everything)"
echo ""
echo -e "  ${GREEN}GOOD:${NC} \"Action\": \"s3:GetObject\","
echo "        \"Resource\": \"arn:aws:s3:::my-bucket/*\""
echo "        (Only read from specific bucket)"
echo ""

# Architecture diagram
echo -e "${CYAN}────────────────────────────────────────${NC}"
echo -e "${CYAN}WHAT WE BUILT:${NC}"
echo -e "${CYAN}────────────────────────────────────────${NC}"
echo ""
echo "  USERS                    GROUPS              POLICIES"
echo "  ─────                    ──────              ────────"
echo ""
echo "  alice ───┐"
echo "           ├──► developers ──► developer-access"
echo "  bob   ───┘                   (s3:*, lambda:*, dynamodb:*)"
echo "                               ↓"
echo "                               deny-dangerous-actions"
echo "                               (can't delete buckets/tables)"
echo ""
echo "  charlie ───► read-only ──► read-only-access"
echo "                             (s3:Get*, s3:List*, etc.)"
echo ""
echo ""
echo "  ROLES                      TRUST              PERMISSIONS"
echo "  ─────                      ─────              ───────────"
echo ""
echo "  lambda-execution    ◄── lambda.amazonaws.com"
echo "                          Can: logs:*, dynamodb:GetItem/PutItem"
echo ""
echo "  api-gateway        ◄── apigateway.amazonaws.com"
echo "                          Can: lambda:InvokeFunction"
echo ""
echo "  ec2-instance       ◄── ec2.amazonaws.com"
echo "                          Can: s3:GetObject, s3:ListBucket"
echo ""

echo -e "${BLUE}============================================================${NC}"
echo -e "${BLUE}  Exercise 08 Complete!${NC}"
echo -e "${BLUE}============================================================${NC}"
echo ""
echo "Try these commands:"
echo ""
echo "  # List users"
echo "  awslocal iam list-users"
echo ""
echo "  # See who's in a group"
echo "  awslocal iam get-group --group-name developers"
echo ""
echo "  # See role trust policy (who can assume it)"
echo "  awslocal iam get-role --role-name iam-demo-dev-lambda-execution"
echo ""
echo "  # See a policy document"
echo "  awslocal iam get-policy-version --policy-arn arn:aws:iam::000000000000:policy/developer-access --version-id v1"
echo ""
echo "To clean up: terraform destroy"
