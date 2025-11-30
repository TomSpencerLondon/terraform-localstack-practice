# ============================================================
# OUTPUTS
# ============================================================

output "api_id" {
  description = "API Gateway REST API ID"
  value       = aws_api_gateway_rest_api.api.id
}

output "api_name" {
  description = "API Gateway REST API name"
  value       = aws_api_gateway_rest_api.api.name
}

output "stage_name" {
  description = "API Gateway stage name"
  value       = aws_api_gateway_stage.api.stage_name
}

output "api_endpoint" {
  description = "API Gateway invoke URL (real AWS format)"
  value       = aws_api_gateway_stage.api.invoke_url
}

output "localstack_api_url" {
  description = "LocalStack API URL"
  value       = "http://localhost:4566/restapis/${aws_api_gateway_rest_api.api.id}/${var.environment}/_user_request_"
}

output "lambda_function" {
  description = "Lambda function name"
  value       = aws_lambda_function.api_handler.function_name
}

output "endpoints" {
  description = "Available API endpoints"
  value = {
    health      = "GET  /health"
    list_users  = "GET  /users"
    create_user = "POST /users"
    get_user    = "GET  /users/{user_id}"
    update_user = "PUT  /users/{user_id}"
    delete_user = "DELETE /users/{user_id}"
  }
}

output "example_commands" {
  description = "Example curl commands"
  value       = <<-EOT

    # Set base URL
    API_URL="http://localhost:4566/restapis/${aws_api_gateway_rest_api.api.id}/${var.environment}/_user_request_"

    # Health check
    curl $API_URL/health

    # List all users
    curl $API_URL/users

    # Get single user
    curl $API_URL/users/user-001

    # Create user
    curl -X POST $API_URL/users \
      -H "Content-Type: application/json" \
      -d '{"name": "Alice", "email": "alice@example.com"}'

    # Update user
    curl -X PUT $API_URL/users/user-001 \
      -H "Content-Type: application/json" \
      -d '{"name": "Tom Spencer"}'

    # Delete user
    curl -X DELETE $API_URL/users/user-003

  EOT
}
