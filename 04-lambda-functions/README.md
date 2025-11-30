# Exercise 04: Lambda Functions

Learn how to deploy and invoke AWS Lambda functions with Terraform.

## Concepts Covered

- `aws_lambda_function` - Deploy serverless functions
- `aws_iam_role` - IAM role for Lambda execution
- `aws_iam_role_policy_attachment` - Attach policies to roles
- `archive_file` data source - Zip source code for deployment
- `aws_cloudwatch_log_group` - Lambda logging
- Environment variables in Lambda
- Invoking Lambda functions via CLI

## Architecture

```
┌─────────────────┐     ┌─────────────────┐
│   Lambda        │────▶│  CloudWatch     │
│   Function      │     │  Logs           │
└─────────────────┘     └─────────────────┘
        │
        ▼
   Returns JSON
   response
```

## Files

| File | Purpose |
|------|---------|
| main.tf | Lambda function, IAM role, CloudWatch logs |
| variables.tf | Configuration variables |
| outputs.tf | Function ARN, name, invoke URL |
| src/handler.py | Python Lambda handler code |

## Commands

```bash
# Initialize and deploy
terraform init
terraform apply

# Invoke the Lambda function
awslocal lambda invoke \
  --function-name hello-lambda-dev \
  --payload '{"name": "Tom"}' \
  output.json && cat output.json

# View logs
awslocal logs describe-log-groups
awslocal logs get-log-events \
  --log-group-name /aws/lambda/hello-lambda-dev \
  --log-stream-name '<stream-name>'

# List functions
awslocal lambda list-functions
```

## Key Concepts

### 1. IAM Role for Lambda

Lambda needs an IAM role to execute. The role has:
- **Trust policy**: Allows Lambda service to assume the role
- **Execution policy**: Grants permissions (logs, etc.)

### 2. archive_file Data Source

Terraform zips your source code automatically:
```hcl
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/src"
  output_path = "${path.module}/lambda.zip"
}
```

### 3. Lambda Handler Format

For Python: `filename.function_name`
- File: `handler.py`
- Function: `lambda_handler`
- Handler: `handler.lambda_handler`

### 4. Environment Variables

Pass configuration to Lambda at runtime:
```hcl
environment {
  variables = {
    ENVIRONMENT = var.environment
    LOG_LEVEL   = "INFO"
  }
}
```

## Clean Up

```bash
terraform destroy
```
