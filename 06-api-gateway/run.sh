#!/bin/bash
# ============================================================
# Exercise 06: API Gateway + Lambda - Run Script
# ============================================================

set -e  # Exit on error

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${BLUE}============================================================${NC}"
echo -e "${BLUE}  Exercise 06: API Gateway + Lambda${NC}"
echo -e "${BLUE}============================================================${NC}"
echo ""

echo -e "${YELLOW}Key Concepts:${NC}"
echo "  - aws_api_gateway_rest_api - REST API container"
echo "  - aws_api_gateway_resource - URL paths (/users, /users/{id})"
echo "  - aws_api_gateway_method - HTTP methods (GET, POST, PUT, DELETE)"
echo "  - aws_api_gateway_integration - Connect to Lambda (AWS_PROXY)"
echo "  - aws_api_gateway_deployment - Deploy the API"
echo "  - aws_api_gateway_stage - Environment (dev, prod)"
echo "  - aws_lambda_permission - Allow API Gateway to invoke Lambda"
echo ""

# Initialize
echo -e "${GREEN}► Initializing Terraform...${NC}"
terraform init -input=false > /dev/null
echo "  ✓ Initialized"
echo ""

# Apply
echo -e "${GREEN}► Deploying API Gateway + Lambda...${NC}"
terraform apply -auto-approve -input=false 2>&1 | grep -E "(Apply|created|Creation|complete)" | head -20
echo ""

# Get API URL
API_ID=$(terraform output -raw api_id)
API_URL="http://localhost:4566/restapis/${API_ID}/dev/_user_request_"

echo -e "${GREEN}► API deployed successfully!${NC}"
echo ""
echo "  API ID: $API_ID"
echo "  URL:    $API_URL"
echo ""

# Show endpoints
echo -e "${CYAN}────────────────────────────────────────${NC}"
echo -e "${CYAN}Available Endpoints:${NC}"
echo -e "${CYAN}────────────────────────────────────────${NC}"
echo ""
echo "  GET    /health           - Health check"
echo "  GET    /users            - List all users"
echo "  POST   /users            - Create a user"
echo "  GET    /users/{user_id}  - Get a user"
echo "  PUT    /users/{user_id}  - Update a user"
echo "  DELETE /users/{user_id}  - Delete a user"
echo ""

# Test the API
echo -e "${GREEN}► Testing API endpoints...${NC}"
echo ""

# Health check
echo -e "${CYAN}GET /health${NC}"
curl -s "$API_URL/health" | python3 -m json.tool
echo ""

# List users
echo -e "${CYAN}GET /users${NC}"
curl -s "$API_URL/users" | python3 -m json.tool
echo ""

# Get single user
echo -e "${CYAN}GET /users/user-001${NC}"
curl -s "$API_URL/users/user-001" | python3 -m json.tool
echo ""

# Create user
echo -e "${CYAN}POST /users (create Alice)${NC}"
curl -s -X POST "$API_URL/users" \
  -H "Content-Type: application/json" \
  -d '{"name": "Alice", "email": "alice@example.com"}' | python3 -m json.tool
echo ""

# Update user
echo -e "${CYAN}PUT /users/user-001 (update name)${NC}"
curl -s -X PUT "$API_URL/users/user-001" \
  -H "Content-Type: application/json" \
  -d '{"name": "Tom Spencer"}' | python3 -m json.tool
echo ""

# Architecture diagram
echo -e "${CYAN}────────────────────────────────────────${NC}"
echo -e "${CYAN}How It Works:${NC}"
echo -e "${CYAN}────────────────────────────────────────${NC}"
echo ""
echo "  Client Request"
echo "       │"
echo "       ▼"
echo "  ┌─────────────────┐"
echo "  │   API Gateway   │  ← Routes by path + method"
echo "  │  (REST API)     │"
echo "  └────────┬────────┘"
echo "           │"
echo "           ▼"
echo "  ┌─────────────────┐"
echo "  │     Lambda      │  ← Single handler, routes internally"
echo "  │  (handler.py)   │"
echo "  └────────┬────────┘"
echo "           │"
echo "           ▼"
echo "     JSON Response"
echo ""

# Lambda proxy integration
echo -e "${CYAN}────────────────────────────────────────${NC}"
echo -e "${CYAN}Lambda Proxy Integration (AWS_PROXY):${NC}"
echo -e "${CYAN}────────────────────────────────────────${NC}"
echo ""
echo "API Gateway sends this to Lambda:"
echo ""
echo '  {'
echo '    "httpMethod": "GET",'
echo '    "path": "/users/user-001",'
echo '    "pathParameters": {"user_id": "user-001"},'
echo '    "queryStringParameters": {...},'
echo '    "body": "..."'
echo '  }'
echo ""
echo "Lambda must return:"
echo ""
echo '  {'
echo '    "statusCode": 200,'
echo '    "headers": {"Content-Type": "application/json"},'
echo '    "body": "{\"id\": \"user-001\", ...}"'
echo '  }'
echo ""

echo -e "${BLUE}============================================================${NC}"
echo -e "${BLUE}  Exercise 06 Complete!${NC}"
echo -e "${BLUE}============================================================${NC}"
echo ""
echo "Try these commands:"
echo ""
echo "  # Set the API URL"
echo "  API_URL=\"$API_URL\""
echo ""
echo "  # List users"
echo "  curl \$API_URL/users"
echo ""
echo "  # Create a user"
echo "  curl -X POST \$API_URL/users -H 'Content-Type: application/json' -d '{\"name\":\"Bob\",\"email\":\"bob@test.com\"}'"
echo ""
echo "Resource Browser: https://app.localstack.cloud/inst/default/resources/apigateway"
echo ""
echo "To clean up: terraform destroy"
