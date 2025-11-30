# =============================================================================
# Outputs
# =============================================================================

# API Gateway
output "api_url" {
  description = "Base URL for the API"
  value       = "http://localhost:4566/restapis/${aws_api_gateway_rest_api.main.id}/${var.environment}/_user_request_"
}

output "api_id" {
  description = "API Gateway ID"
  value       = aws_api_gateway_rest_api.main.id
}

# Endpoints
output "endpoints" {
  description = "API endpoints"
  value = {
    health    = "GET  /health"
    get_items = "GET  /items"
    get_item  = "GET  /items/{id}"
    create    = "POST /items"
  }
}

# DynamoDB
output "dynamodb_table_name" {
  description = "DynamoDB table name"
  value       = aws_dynamodb_table.items.name
}

output "dynamodb_table_arn" {
  description = "DynamoDB table ARN"
  value       = aws_dynamodb_table.items.arn
}

# S3 Website
output "website_bucket" {
  description = "S3 website bucket name"
  value       = aws_s3_bucket.website.id
}

output "website_url" {
  description = "S3 website URL"
  value       = "http://${aws_s3_bucket.website.id}.s3.localhost.localstack.cloud:4566/index.html"
}

# SNS/SQS
output "sns_topic_arn" {
  description = "SNS topic ARN"
  value       = aws_sns_topic.item_events.arn
}

output "sqs_queue_url" {
  description = "SQS queue URL"
  value       = aws_sqs_queue.item_processing.url
}

# Lambda Functions
output "lambda_functions" {
  description = "Lambda function names"
  value = {
    create_item = aws_lambda_function.create_item.function_name
    get_items   = aws_lambda_function.get_items.function_name
    get_item    = aws_lambda_function.get_item.function_name
    health      = aws_lambda_function.health.function_name
  }
}

# VPC
output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

# Summary
output "summary" {
  description = "Deployment summary"
  value       = <<-EOT

    ==============================================
    FULL STACK APP DEPLOYED!
    ==============================================

    API BASE URL:
    http://localhost:4566/restapis/${aws_api_gateway_rest_api.main.id}/${var.environment}/_user_request_

    ENDPOINTS:
    - GET  /health      - Health check
    - GET  /items       - List all items
    - POST /items       - Create new item
    - GET  /items/{id}  - Get single item

    TEST COMMANDS:

    # Health check
    curl http://localhost:4566/restapis/${aws_api_gateway_rest_api.main.id}/${var.environment}/_user_request_/health

    # Create item
    curl -X POST http://localhost:4566/restapis/${aws_api_gateway_rest_api.main.id}/${var.environment}/_user_request_/items \
      -H "Content-Type: application/json" \
      -d '{"name": "Test", "description": "My item"}'

    # List items
    curl http://localhost:4566/restapis/${aws_api_gateway_rest_api.main.id}/${var.environment}/_user_request_/items

    STATIC WEBSITE:
    http://${aws_s3_bucket.website.id}.s3.localhost.localstack.cloud:4566/index.html

    ==============================================
  EOT
}
