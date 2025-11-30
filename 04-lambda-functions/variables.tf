# ============================================================
# VARIABLES
# ============================================================

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "localstack_endpoint" {
  description = "LocalStack endpoint URL"
  type        = string
  default     = "http://localhost:4566"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "function_name" {
  description = "Name of the Lambda function"
  type        = string
  default     = "hello-lambda"
}

variable "log_level" {
  description = "Logging level for the function"
  type        = string
  default     = "INFO"
}
