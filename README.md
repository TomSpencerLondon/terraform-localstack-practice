# Terraform + LocalStack Practice

Learn Terraform by building real AWS infrastructure locally using LocalStack.

## Prerequisites

Before starting, you need:
1. **Docker** - LocalStack runs in Docker
2. **Terraform** - Infrastructure as Code tool
3. **LocalStack** - AWS cloud emulator
4. **AWS CLI Local** - CLI wrapper for LocalStack

## Installation

### 1. Check Docker is running
```bash
docker --version
docker ps  # Should work without errors
```

### 2. Install Terraform
```bash
brew install terraform
terraform --version
```

### 3. Install LocalStack
```bash
brew install localstack/tap/localstack-cli
localstack --version
```

### 4. Install AWS CLI Local (optional but helpful)
```bash
pip install awscli-local
```

## Starting LocalStack

```bash
# Start LocalStack (runs on http://localhost:4566)
localstack start

# Or run in background
localstack start -d

# Check status
localstack status
```

## Exercise Structure

Each exercise folder contains:
- `main.tf` - Main Terraform configuration
- `variables.tf` - Input variables (if needed)
- `outputs.tf` - Output values (if needed)
- `README.md` - Exercise instructions

## Exercises

| # | Exercise | Concepts | Status |
|---|----------|----------|--------|
| 01 | [Hello S3](./01-hello-s3/) | Providers, resources, basic workflow | Done |
| 02 | [Variables & Outputs](./02-variables-outputs/) | Variables, outputs, data types | Done |
| 03 | [S3 Static Website](./03-s3-static-website/) | S3 website hosting, bucket policies | Done |
| 04 | [Lambda Functions](./04-lambda-functions/) | Lambda, IAM roles, permissions | Done |
| 05 | [DynamoDB](./05-dynamodb/) | NoSQL tables, attributes | Done |
| 06 | [API Gateway](./06-api-gateway/) | REST APIs, integrations | Done |
| 07 | [SQS & SNS](./07-sqs-sns/) | Messaging, pub/sub | Done |
| 08 | [IAM Deep Dive](./08-iam-deep-dive/) | Policies, roles, permissions | Done |
| 09 | [VPC Networking](./09-vpc/) | VPCs, subnets, security groups | Done |
| 10 | [Full Stack App](./10-full-stack-app/) | Complete serverless application | **Current** |

## Basic Terraform Workflow

```bash
cd 01-hello-s3

# Initialize - downloads providers
terraform init

# Plan - preview changes
terraform plan

# Apply - create resources
terraform apply

# Show current state
terraform show

# Destroy - clean up
terraform destroy
```

## Useful Commands

```bash
# Format code
terraform fmt

# Validate configuration
terraform validate

# List resources in state
terraform state list

# View specific resource
terraform state show <resource>
```
