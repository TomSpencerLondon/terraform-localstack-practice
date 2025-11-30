# ============================================================
# EXERCISE 04: Lambda Functions
# Learn Lambda deployment, IAM roles, and function invocation
# ============================================================

terraform {
  required_version = ">= 1.0.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
  }
}

# ------------------------------------------------------------
# PROVIDER CONFIGURATION
# ------------------------------------------------------------

provider "aws" {
  region     = var.aws_region
  access_key = "test"
  secret_key = "test"

  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true

  endpoints {
    lambda = var.localstack_endpoint
    iam    = var.localstack_endpoint
    logs   = var.localstack_endpoint
  }
}

# ------------------------------------------------------------
# LOCALS
# ------------------------------------------------------------

locals {
  function_full_name = "${var.function_name}-${var.environment}"

  default_tags = {
    Environment = var.environment
    Project     = "terraform-learning"
    Exercise    = "04-lambda-functions"
    ManagedBy   = "terraform"
  }
}

# ------------------------------------------------------------
# ARCHIVE: ZIP THE LAMBDA SOURCE CODE
# This data source creates a zip file from our source directory
# ------------------------------------------------------------

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/src"
  output_path = "${path.module}/lambda.zip"
}

# ------------------------------------------------------------
# IAM ROLE FOR LAMBDA
# Lambda needs a role to execute - this defines what it can do
# ------------------------------------------------------------

# Trust policy: Allow Lambda service to assume this role
data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

# Create the IAM role
resource "aws_iam_role" "lambda_role" {
  name               = "${local.function_full_name}-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
  tags               = local.default_tags
}

# Attach the basic execution policy (allows CloudWatch Logs)
resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# ------------------------------------------------------------
# CLOUDWATCH LOG GROUP
# Create log group before Lambda to control retention
# ------------------------------------------------------------

resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${local.function_full_name}"
  retention_in_days = 7
  tags              = local.default_tags
}

# ------------------------------------------------------------
# LAMBDA FUNCTION
# The actual serverless function
# ------------------------------------------------------------

resource "aws_lambda_function" "hello" {
  function_name = local.function_full_name
  description   = "Hello World Lambda function - Exercise 04"

  # Deployment package
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  # Runtime configuration
  runtime = "python3.11"
  handler = "handler.lambda_handler"  # file.function
  timeout = 30
  memory_size = 128

  # IAM role
  role = aws_iam_role.lambda_role.arn

  # Environment variables - available in os.environ
  environment {
    variables = {
      ENVIRONMENT = var.environment
      LOG_LEVEL   = var.log_level
    }
  }

  tags = local.default_tags

  # Ensure log group exists first
  depends_on = [
    aws_cloudwatch_log_group.lambda_logs,
    aws_iam_role_policy_attachment.lambda_basic_execution
  ]
}
