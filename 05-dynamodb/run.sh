#!/bin/bash
# ============================================================
# Exercise 05: DynamoDB - Run Script
# ============================================================

set -e  # Exit on error

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${BLUE}============================================================${NC}"
echo -e "${BLUE}  Exercise 05: DynamoDB${NC}"
echo -e "${BLUE}============================================================${NC}"
echo ""

# Setup awslocal alias for this script
awslocal="AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test AWS_DEFAULT_REGION=us-east-1 aws --endpoint-url=http://localhost:4566"

echo -e "${YELLOW}Key Concepts:${NC}"
echo "  - Partition keys vs composite keys"
echo "  - PAY_PER_REQUEST vs PROVISIONED billing"
echo "  - Global Secondary Indexes (GSI)"
echo "  - Local Secondary Indexes (LSI)"
echo "  - Time To Live (TTL)"
echo "  - Attribute types: S, N, B"
echo ""

# Initialize
echo -e "${GREEN}► Initializing Terraform...${NC}"
terraform init -input=false > /dev/null
echo "  ✓ Initialized"
echo ""

# Apply
echo -e "${GREEN}► Deploying DynamoDB tables...${NC}"
terraform apply -auto-approve -input=false 2>&1 | grep -E "(Apply|created|Creation)"
echo ""

# List tables
echo -e "${GREEN}► Tables created:${NC}"
eval "$awslocal dynamodb list-tables --output table"
echo ""

# Demonstrate key types
echo -e "${CYAN}────────────────────────────────────────${NC}"
echo -e "${CYAN}Partition Key Only (users table):${NC}"
echo -e "${CYAN}────────────────────────────────────────${NC}"
echo ""
echo "hash_key = \"user_id\""
echo ""
echo "Access pattern: Get user by ID"
echo "  Key: { user_id: \"user-001\" }"
echo ""

echo -e "${CYAN}────────────────────────────────────────${NC}"
echo -e "${CYAN}Composite Key (orders table):${NC}"
echo -e "${CYAN}────────────────────────────────────────${NC}"
echo ""
echo "hash_key  = \"user_id\"   # Partition key"
echo "range_key = \"order_id\"  # Sort key"
echo ""
echo "Access patterns:"
echo "  1. Get specific order: { user_id + order_id }"
echo "  2. Get all orders for user: { user_id }"
echo "  3. Get orders in range: { user_id, order_id BETWEEN }"
echo ""

# Insert sample data
echo -e "${GREEN}► Inserting sample data...${NC}"
echo ""

# Users
eval "$awslocal dynamodb put-item \
  --table-name learn-dynamodb-dev-users \
  --item '{\"user_id\": {\"S\": \"user-001\"}, \"name\": {\"S\": \"Tom\"}, \"email\": {\"S\": \"tom@example.com\"}}'" 2>/dev/null
echo "  ✓ User: Tom (user-001)"

eval "$awslocal dynamodb put-item \
  --table-name learn-dynamodb-dev-users \
  --item '{\"user_id\": {\"S\": \"user-002\"}, \"name\": {\"S\": \"Jane\"}, \"email\": {\"S\": \"jane@example.com\"}}'" 2>/dev/null
echo "  ✓ User: Jane (user-002)"

# Orders
eval "$awslocal dynamodb put-item \
  --table-name learn-dynamodb-dev-orders \
  --item '{\"user_id\": {\"S\": \"user-001\"}, \"order_id\": {\"S\": \"order-001\"}, \"status\": {\"S\": \"pending\"}, \"created_at\": {\"S\": \"2024-01-15T10:00:00Z\"}, \"total\": {\"N\": \"99.99\"}}'" 2>/dev/null
echo "  ✓ Order: order-001 (pending)"

eval "$awslocal dynamodb put-item \
  --table-name learn-dynamodb-dev-orders \
  --item '{\"user_id\": {\"S\": \"user-001\"}, \"order_id\": {\"S\": \"order-002\"}, \"status\": {\"S\": \"shipped\"}, \"created_at\": {\"S\": \"2024-01-16T14:30:00Z\"}, \"total\": {\"N\": \"149.50\"}}'" 2>/dev/null
echo "  ✓ Order: order-002 (shipped)"

# Products
eval "$awslocal dynamodb put-item \
  --table-name learn-dynamodb-dev-products \
  --item '{\"product_id\": {\"S\": \"prod-001\"}, \"name\": {\"S\": \"Laptop\"}, \"category\": {\"S\": \"Electronics\"}, \"price\": {\"N\": \"999.99\"}}'" 2>/dev/null
echo "  ✓ Product: Laptop"

echo ""

# Query examples
echo -e "${GREEN}► Query: Get user by ID${NC}"
echo "awslocal dynamodb get-item --table-name learn-dynamodb-dev-users --key '{\"user_id\": {\"S\": \"user-001\"}}'"
echo ""
eval "$awslocal dynamodb get-item \
  --table-name learn-dynamodb-dev-users \
  --key '{\"user_id\": {\"S\": \"user-001\"}}' \
  --output json" | python3 -c "import sys,json; item=json.load(sys.stdin).get('Item',{}); print(json.dumps({k:list(v.values())[0] for k,v in item.items()}, indent=2))"
echo ""

echo -e "${GREEN}► Query: Get all orders for user-001${NC}"
echo "awslocal dynamodb query --table-name learn-dynamodb-dev-orders --key-condition-expression \"user_id = :uid\""
echo ""
eval "$awslocal dynamodb query \
  --table-name learn-dynamodb-dev-orders \
  --key-condition-expression 'user_id = :uid' \
  --expression-attribute-values '{\":uid\": {\"S\": \"user-001\"}}' \
  --output json" | python3 -c "
import sys,json
items=json.load(sys.stdin).get('Items',[])
for item in items:
    simple = {k:list(v.values())[0] for k,v in item.items()}
    print(f\"  - Order: {simple['order_id']}, Status: {simple['status']}, Total: \${simple['total']}\")"
echo ""

# GSI demo
echo -e "${CYAN}────────────────────────────────────────${NC}"
echo -e "${CYAN}Global Secondary Index (GSI):${NC}"
echo -e "${CYAN}────────────────────────────────────────${NC}"
echo ""
echo "global_secondary_index {"
echo "  name     = \"status-index\""
echo "  hash_key = \"status\""
echo "  range_key = \"created_at\""
echo "}"
echo ""
echo "Query all 'pending' orders across ALL users:"
echo ""

RESULT=$(eval "$awslocal dynamodb query \
  --table-name learn-dynamodb-dev-orders \
  --index-name status-index \
  --key-condition-expression '#s = :s' \
  --expression-attribute-names '{\"#s\": \"status\"}' \
  --expression-attribute-values '{\":s\": {\"S\": \"pending\"}}' \
  --output json" 2>&1)

if echo "$RESULT" | grep -q "Items"; then
  echo "$RESULT" | python3 -c "
import sys,json
items=json.load(sys.stdin).get('Items',[])
for item in items:
    simple = {k:list(v.values())[0] for k,v in item.items()}
    print(f\"  - User: {simple['user_id']}, Order: {simple['order_id']}, Created: {simple['created_at']}\")"
else
  echo "  (GSI query - may take a moment to propagate in LocalStack)"
fi
echo ""

# TTL demo
echo -e "${CYAN}────────────────────────────────────────${NC}"
echo -e "${CYAN}Time To Live (TTL):${NC}"
echo -e "${CYAN}────────────────────────────────────────${NC}"
echo ""
echo "ttl {"
echo "  attribute_name = \"expires_at\""
echo "  enabled        = true"
echo "}"
echo ""
echo "Items with expires_at in the past are automatically deleted"
echo "Useful for: sessions, caches, temporary tokens"
echo ""

# Show table details
echo -e "${GREEN}► Table details:${NC}"
terraform output
echo ""

echo -e "${BLUE}============================================================${NC}"
echo -e "${BLUE}  Exercise 05 Complete!${NC}"
echo -e "${BLUE}============================================================${NC}"
echo ""
echo "Try these commands:"
echo "  awslocal dynamodb scan --table-name learn-dynamodb-dev-users"
echo "  awslocal dynamodb describe-table --table-name learn-dynamodb-dev-orders"
echo ""
echo "Resource Browser: https://app.localstack.cloud/inst/default/resources/dynamodb"
echo ""
echo "To clean up: terraform destroy"
