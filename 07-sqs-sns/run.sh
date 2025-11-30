#!/bin/bash
# ============================================================
# Exercise 07: SQS & SNS - Run Script
# ============================================================

set -e  # Exit on error

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${BLUE}============================================================${NC}"
echo -e "${BLUE}  Exercise 07: SQS & SNS${NC}"
echo -e "${BLUE}============================================================${NC}"
echo ""

# Setup awslocal alias for this script
awslocal="AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test AWS_DEFAULT_REGION=us-east-1 aws --endpoint-url=http://localhost:4566"

echo -e "${YELLOW}Key Concepts:${NC}"
echo "  - SQS Standard Queue (best-effort ordering)"
echo "  - SQS FIFO Queue (exactly-once, strict ordering)"
echo "  - Dead Letter Queue (failed messages)"
echo "  - SNS Topic (pub/sub)"
echo "  - SNS → SQS subscription with filter"
echo "  - Lambda event source mapping (SQS trigger)"
echo ""

# Initialize
echo -e "${GREEN}► Initializing Terraform...${NC}"
terraform init -input=false > /dev/null
echo "  ✓ Initialized"
echo ""

# Fix permissions
chmod 644 src/consumer.py 2>/dev/null || true
rm -f lambda.zip 2>/dev/null || true

# Apply
echo -e "${GREEN}► Deploying SQS queues, SNS topics, and Lambda...${NC}"
terraform apply -auto-approve -input=false 2>&1 | grep -E "(Apply|created|Creation|complete)" | head -15
echo ""

# Get resource details
ORDERS_QUEUE_URL=$(terraform output -json orders_queue | python3 -c "import sys,json; print(json.load(sys.stdin)['url'])")
DLQ_URL=$(terraform output -json orders_dlq | python3 -c "import sys,json; print(json.load(sys.stdin)['url'])")
PAYMENTS_QUEUE_URL=$(terraform output -json payments_queue | python3 -c "import sys,json; print(json.load(sys.stdin)['url'])")
ORDER_EVENTS_ARN=$(terraform output -json order_events_topic | python3 -c "import sys,json; print(json.load(sys.stdin)['arn'])")

echo -e "${GREEN}► Resources created:${NC}"
echo ""
echo "  SQS Queues:"
echo "    - orders (Standard) → Lambda consumer"
echo "    - orders-dlq (Dead Letter Queue)"
echo "    - payments.fifo (FIFO)"
echo ""
echo "  SNS Topics:"
echo "    - notifications"
echo "    - order-events → subscribes to orders queue"
echo ""

# SQS vs SNS
echo -e "${CYAN}────────────────────────────────────────${NC}"
echo -e "${CYAN}SQS vs SNS:${NC}"
echo -e "${CYAN}────────────────────────────────────────${NC}"
echo ""
echo "  ┌─────────────────┬─────────────────┐"
echo "  │      SQS        │      SNS        │"
echo "  ├─────────────────┼─────────────────┤"
echo "  │ Point-to-point  │ Pub/Sub         │"
echo "  │ One consumer    │ Many subscribers│"
echo "  │ Pull (polling)  │ Push            │"
echo "  │ Persisted       │ No persistence  │"
echo "  │ Retry built-in  │ Deliver & forget│"
echo "  └─────────────────┴─────────────────┘"
echo ""

# Demo: Send to SQS
echo -e "${GREEN}► Sending message directly to SQS...${NC}"
echo ""
echo "  Command: awslocal sqs send-message --queue-url <url> --message-body '{...}'"
echo ""
eval "$awslocal sqs send-message \
  --queue-url '$ORDERS_QUEUE_URL' \
  --message-body '{\"order_id\": \"direct-001\", \"amount\": 49.99}'" | python3 -c "import sys,json; d=json.load(sys.stdin); print(f'  Message ID: {d[\"MessageId\"]}')"
echo ""

# Demo: Publish to SNS (will fan out to SQS)
echo -e "${GREEN}► Publishing to SNS (will deliver to subscribed SQS)...${NC}"
echo ""
echo "  Command: awslocal sns publish --topic-arn <arn> --message '{...}'"
echo ""
eval "$awslocal sns publish \
  --topic-arn '$ORDER_EVENTS_ARN' \
  --message '{\"order_id\": \"sns-001\", \"event_type\": \"order.created\"}' \
  --message-attributes '{\"event_type\": {\"DataType\": \"String\", \"StringValue\": \"order.created\"}}'" | python3 -c "import sys,json; d=json.load(sys.stdin); print(f'  Message ID: {d[\"MessageId\"]}')"
echo ""

# Wait for Lambda to process
echo -e "${GREEN}► Waiting for Lambda to process messages...${NC}"
sleep 3
echo "  ✓ Lambda consumer triggered by SQS"
echo ""

# Check queue depth
echo -e "${GREEN}► Checking queue message count...${NC}"
QUEUE_DEPTH=$(eval "$awslocal sqs get-queue-attributes \
  --queue-url '$ORDERS_QUEUE_URL' \
  --attribute-names ApproximateNumberOfMessages" 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin).get('Attributes', {}).get('ApproximateNumberOfMessages', 'unknown'))")
echo "  Orders queue: $QUEUE_DEPTH messages"
echo ""

# FIFO demo
echo -e "${CYAN}────────────────────────────────────────${NC}"
echo -e "${CYAN}FIFO Queue (payments):${NC}"
echo -e "${CYAN}────────────────────────────────────────${NC}"
echo ""
echo "  FIFO = First In, First Out"
echo "  - Exactly-once processing"
echo "  - Strict ordering within MessageGroupId"
echo "  - Requires --message-group-id"
echo ""
echo "  Sending 3 messages to FIFO queue..."
for i in 1 2 3; do
  eval "$awslocal sqs send-message \
    --queue-url '$PAYMENTS_QUEUE_URL' \
    --message-body '{\"payment_id\": \"pay-00$i\", \"amount\": $((i * 100))}' \
    --message-group-id 'user-001'" > /dev/null 2>&1
  echo "    ✓ payment $i sent"
done
echo ""

# DLQ explanation
echo -e "${CYAN}────────────────────────────────────────${NC}"
echo -e "${CYAN}Dead Letter Queue (DLQ):${NC}"
echo -e "${CYAN}────────────────────────────────────────${NC}"
echo ""
echo "  redrive_policy = {"
echo "    deadLetterTargetArn = orders-dlq.arn"
echo "    maxReceiveCount     = 3"
echo "  }"
echo ""
echo "  After 3 failed processing attempts,"
echo "  message is moved to DLQ for investigation."
echo ""
echo "  Check DLQ:"
echo "  awslocal sqs receive-message --queue-url $DLQ_URL"
echo ""

# SNS filter demo
echo -e "${CYAN}────────────────────────────────────────${NC}"
echo -e "${CYAN}SNS Filter Policy:${NC}"
echo -e "${CYAN}────────────────────────────────────────${NC}"
echo ""
echo '  filter_policy = jsonencode({'
echo '    event_type = ["order.created", "order.updated"]'
echo '  })'
echo ""
echo "  Only matching messages are delivered to subscriber."
echo "  This message would be FILTERED OUT:"
echo '    {"event_type": "order.cancelled"}'
echo ""

# Architecture
echo -e "${CYAN}────────────────────────────────────────${NC}"
echo -e "${CYAN}Architecture:${NC}"
echo -e "${CYAN}────────────────────────────────────────${NC}"
echo ""
echo "  Producer"
echo "     │"
echo "     ▼"
echo "  ┌─────────┐"
echo "  │   SNS   │ order-events topic"
echo "  └────┬────┘"
echo "       │ (filtered subscription)"
echo "       ▼"
echo "  ┌─────────┐     ┌─────────┐"
echo "  │   SQS   │────▶│ Lambda  │"
echo "  │ orders  │     │consumer │"
echo "  └────┬────┘     └─────────┘"
echo "       │ (after 3 failures)"
echo "       ▼"
echo "  ┌─────────┐"
echo "  │   DLQ   │ orders-dlq"
echo "  └─────────┘"
echo ""

echo -e "${BLUE}============================================================${NC}"
echo -e "${BLUE}  Exercise 07 Complete!${NC}"
echo -e "${BLUE}============================================================${NC}"
echo ""
echo "Try these commands:"
echo ""
echo "  # Send to SQS"
echo "  awslocal sqs send-message --queue-url '$ORDERS_QUEUE_URL' --message-body '{\"test\": 1}'"
echo ""
echo "  # Publish to SNS"
echo "  awslocal sns publish --topic-arn '$ORDER_EVENTS_ARN' --message '{\"order_id\": \"123\"}'"
echo ""
echo "  # Check queue"
echo "  awslocal sqs receive-message --queue-url '$ORDERS_QUEUE_URL'"
echo ""
echo "Resource Browser: https://app.localstack.cloud/inst/default/resources/sqs"
echo ""
echo "To clean up: terraform destroy"
