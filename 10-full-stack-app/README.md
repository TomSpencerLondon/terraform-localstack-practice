# Exercise 10: Full Stack Serverless Application

Build a complete serverless application combining everything you've learned!

## Architecture

```
                                    ┌─────────────────────────────────────────┐
                                    │              VPC (10.0.0.0/16)          │
                                    │                                         │
┌──────────┐     ┌──────────────┐   │  ┌─────────────────────────────────┐   │
│  Client  │────▶│ API Gateway  │───┼─▶│  Lambda Functions               │   │
└──────────┘     └──────────────┘   │  │  (in private subnets)           │   │
                                    │  │                                  │   │
                                    │  │  ┌─────────┐    ┌─────────────┐ │   │
                                    │  │  │ Create  │    │    Get      │ │   │
                                    │  │  │  Item   │    │   Items     │ │   │
                                    │  │  └────┬────┘    └──────┬──────┘ │   │
                                    │  └───────┼────────────────┼────────┘   │
                                    │          │                │            │
                                    │          ▼                ▼            │
                                    │  ┌─────────────────────────────────┐   │
                                    │  │         DynamoDB Table          │   │
                                    │  │         (items table)           │   │
                                    │  └─────────────────────────────────┘   │
                                    │                                         │
                                    │  ┌─────────────────────────────────┐   │
                                    │  │         S3 Bucket               │   │
                                    │  │    (static website hosting)     │◀──┼── Static Files
                                    │  └─────────────────────────────────┘   │
                                    └─────────────────────────────────────────┘
                                                      │
                                                      ▼
                                    ┌─────────────────────────────────────────┐
                                    │         SNS Topic                       │
                                    │   (notifications on item creation)      │
                                    │              │                          │
                                    │              ▼                          │
                                    │         SQS Queue                       │
                                    │    (for async processing)               │
                                    └─────────────────────────────────────────┘
```

## What This Builds

1. **VPC** - Isolated network with public/private subnets
2. **API Gateway** - REST API with multiple endpoints
3. **Lambda Functions** - Create and Get operations
4. **DynamoDB** - NoSQL database for items
5. **S3** - Static website hosting
6. **SNS/SQS** - Event notifications
7. **IAM** - Proper roles and policies

## Endpoints

| Method | Path | Description |
|--------|------|-------------|
| GET | `/items` | List all items |
| GET | `/items/{id}` | Get single item |
| POST | `/items` | Create new item |
| GET | `/health` | Health check |

## Steps

### Step 1: Start LocalStack

```bash
localstack start -d
```

### Step 2: Initialize and Apply

```bash
cd 10-full-stack-app
terraform init
terraform plan
terraform apply
```

### Step 3: Test the API

```bash
# Get the API URL from outputs
API_URL=$(terraform output -raw api_url)

# Health check
curl $API_URL/health

# Create an item
curl -X POST $API_URL/items \
  -H "Content-Type: application/json" \
  -d '{"name": "Test Item", "description": "My first item"}'

# List all items
curl $API_URL/items

# Get specific item (use ID from create response)
curl $API_URL/items/{id}
```

### Step 4: Check the Static Website

```bash
WEBSITE_URL=$(terraform output -raw website_url)
curl $WEBSITE_URL
```

### Step 5: Verify SNS/SQS Integration

```bash
# Check messages in SQS queue
awslocal sqs receive-message --queue-url $(terraform output -raw sqs_queue_url)
```

## Concepts Demonstrated

| Component | Concepts |
|-----------|----------|
| VPC | Subnets, Security Groups, NAT |
| API Gateway | REST API, Lambda Integration, CORS |
| Lambda | Python handlers, Environment vars, VPC attachment |
| DynamoDB | Table design, GSI, CRUD operations |
| S3 | Static hosting, Bucket policies |
| SNS/SQS | Pub/Sub, Decoupled messaging |
| IAM | Least privilege, Role assumption |

## Challenge Extensions

1. **Add Authentication** - Implement API key or Cognito
2. **Add CloudWatch Alarms** - Monitor Lambda errors
3. **Add Step Functions** - Orchestrate multi-step workflows
4. **Add ElastiCache** - Cache frequently accessed items

## Clean Up

```bash
terraform destroy
```
