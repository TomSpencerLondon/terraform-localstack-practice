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

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "iam-demo"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}
