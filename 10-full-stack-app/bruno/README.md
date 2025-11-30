# Full Stack App API - Bruno Collection

Bruno API collection for testing the Full Stack Serverless Application.

## Architecture

```
Client → API Gateway → Lambda → DynamoDB
              ↓
            SNS → SQS
```

## Prerequisites

1. **LocalStack** running on `localhost:4566`
2. **Full Stack App deployed** via Terraform

## Setup

### 1. Deploy the Application

```bash
cd terraform-localstack-practice/10-full-stack-app
localstack start -d
terraform init
terraform apply
```

### 2. Get the API ID

```bash
terraform output api_id
# Example: 7ry0xn3yoe
```

### 3. Update Environment

Edit `environments/localstack.bru` and update the `api_id` if different.

## Endpoints

| Request | Method | Path | Description |
|---------|--------|------|-------------|
| Health Check | GET | /health | Service health status |
| List Items | GET | /items | Get all items |
| Create Item | POST | /items | Create new item |
| Get Item | GET | /items/:id | Get item by ID |

## Running Requests

### Using Bruno GUI

1. Open Bruno
2. Import this collection folder
3. Select "localstack" environment
4. Run requests in order: Health → Create → List → Get

### Using Bruno CLI

```bash
# Run all requests
bru run --env localstack

# Run single request
bru run "Health Check.bru" --env localstack

# Run with output
bru run --env localstack --output results.json
```

## Request Flow

1. **Health Check** - Verify API is running
2. **Create Item** - Creates item and saves ID to `last_item_id` variable
3. **List Items** - See all created items
4. **Get Item** - Uses `last_item_id` from Create step

## Testing with curl

```bash
# Base URL
BASE=http://localhost:4566/restapis/7ry0xn3yoe/dev/_user_request_

# Health
curl $BASE/health | jq

# Create
curl -X POST $BASE/items \
  -H "Content-Type: application/json" \
  -d '{"name": "Test", "description": "Hello"}' | jq

# List
curl $BASE/items | jq

# Get (replace ID)
curl $BASE/items/YOUR-ITEM-ID | jq
```

## Connecting to DynamoDB

### Option 1: AWS CLI

```bash
# List tables
awslocal dynamodb list-tables

# Scan items
awslocal dynamodb scan --table-name fullstack-app-items

# Get specific item
awslocal dynamodb get-item \
  --table-name fullstack-app-items \
  --key '{"id": {"S": "your-uuid-here"}}'
```

### Option 2: DynamoDB Admin (Web UI)

```bash
# Install
npm install -g dynamodb-admin

# Run (connects to LocalStack)
DYNAMO_ENDPOINT=http://localhost:4566 dynamodb-admin

# Open http://localhost:8001
```

### Option 3: NoSQL Workbench

1. Download from AWS
2. Add connection:
   - Endpoint: `http://localhost:4566`
   - Region: `eu-west-2`
   - Access Key: `test`
   - Secret Key: `test`

### Option 4: DBeaver

1. New Connection → DynamoDB
2. Host: `localhost`
3. Port: `4566`
4. Region: `eu-west-2`
5. Access Key: `test`
6. Secret Key: `test`

## Checking SNS/SQS Messages

```bash
# View SQS messages (items created events)
awslocal sqs receive-message \
  --queue-url http://sqs.eu-west-2.localhost.localstack.cloud:4566/000000000000/fullstack-app-item-processing \
  --region eu-west-2

# List SNS topics
awslocal sns list-topics --region eu-west-2

# List SQS queues
awslocal sqs list-queues --region eu-west-2
```

## Troubleshooting

### API returns 500 Internal Server Error

Check Lambda logs:
```bash
awslocal logs tail /aws/lambda/fullstack-app-get-items --region eu-west-2
```

### DynamoDB connection issues

Ensure LocalStack is running:
```bash
localstack status
```

### API Gateway not responding

Verify the API ID in your environment matches terraform output:
```bash
terraform output api_id
```
