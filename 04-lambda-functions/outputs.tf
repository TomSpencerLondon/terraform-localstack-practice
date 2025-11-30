# ============================================================
# OUTPUTS
# ============================================================

output "function_name" {
  description = "Name of the Lambda function"
  value       = aws_lambda_function.hello.function_name
}

output "function_arn" {
  description = "ARN of the Lambda function"
  value       = aws_lambda_function.hello.arn
}

output "function_role" {
  description = "IAM role ARN for the Lambda function"
  value       = aws_iam_role.lambda_role.arn
}

output "log_group_name" {
  description = "CloudWatch log group name"
  value       = aws_cloudwatch_log_group.lambda_logs.name
}

output "invoke_command" {
  description = "Command to invoke the Lambda function"
  value       = <<-EOT
    awslocal lambda invoke \
      --function-name ${aws_lambda_function.hello.function_name} \
      --payload '{"name": "Your Name"}' \
      output.json && cat output.json
  EOT
}
