# ============================================================
# EXERCISE 08: IAM DEEP DIVE
# Learn Identity and Access Management
# ============================================================

terraform {
  required_version = ">= 1.0.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
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
    iam      = var.localstack_endpoint
    sts      = var.localstack_endpoint
    s3       = var.localstack_endpoint
    dynamodb = var.localstack_endpoint
    lambda   = var.localstack_endpoint
  }
}

# ------------------------------------------------------------
# LOCALS
# ------------------------------------------------------------

locals {
  prefix = "${var.project_name}-${var.environment}"

  default_tags = {
    Environment = var.environment
    Project     = "terraform-learning"
    Exercise    = "08-iam-deep-dive"
    ManagedBy   = "terraform"
  }
}

# ============================================================
# IAM USERS
# ============================================================

# ------------------------------------------------------------
# USER: alice (developer)
# ------------------------------------------------------------

resource "aws_iam_user" "alice" {
  name = "alice"
  tags = local.default_tags
}

# ------------------------------------------------------------
# USER: bob (developer)
# ------------------------------------------------------------

resource "aws_iam_user" "bob" {
  name = "bob"
  tags = local.default_tags
}

# ------------------------------------------------------------
# USER: charlie (read-only)
# ------------------------------------------------------------

resource "aws_iam_user" "charlie" {
  name = "charlie"
  tags = local.default_tags
}

# ============================================================
# IAM GROUPS
# ============================================================

# ------------------------------------------------------------
# GROUP: developers
# Members: alice, bob
# Permissions: Full access to S3, Lambda, DynamoDB
# ------------------------------------------------------------

resource "aws_iam_group" "developers" {
  name = "developers"
}

resource "aws_iam_group_membership" "developers" {
  name  = "developers-membership"
  group = aws_iam_group.developers.name
  users = [
    aws_iam_user.alice.name,
    aws_iam_user.bob.name,
  ]
}

# ------------------------------------------------------------
# GROUP: read_only
# Members: charlie
# Permissions: Read-only access
# ------------------------------------------------------------

resource "aws_iam_group" "read_only" {
  name = "read-only"
}

resource "aws_iam_group_membership" "read_only" {
  name  = "read-only-membership"
  group = aws_iam_group.read_only.name
  users = [
    aws_iam_user.charlie.name,
  ]
}

# ============================================================
# IAM POLICIES (using data sources for clean HCL)
# ============================================================

# ------------------------------------------------------------
# POLICY DOCUMENT: Developer Access
# Full access to common services
# ------------------------------------------------------------

data "aws_iam_policy_document" "developer_access" {
  # S3 full access
  statement {
    sid    = "S3FullAccess"
    effect = "Allow"
    actions = [
      "s3:*"
    ]
    resources = ["*"]
  }

  # Lambda full access
  statement {
    sid    = "LambdaFullAccess"
    effect = "Allow"
    actions = [
      "lambda:*"
    ]
    resources = ["*"]
  }

  # DynamoDB full access
  statement {
    sid    = "DynamoDBFullAccess"
    effect = "Allow"
    actions = [
      "dynamodb:*"
    ]
    resources = ["*"]
  }

  # CloudWatch Logs (for debugging)
  statement {
    sid    = "CloudWatchLogsAccess"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams",
      "logs:GetLogEvents"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "developer_access" {
  name        = "developer-access"
  description = "Full access to S3, Lambda, DynamoDB for developers"
  policy      = data.aws_iam_policy_document.developer_access.json
  tags        = local.default_tags
}

# Attach policy to developers group
resource "aws_iam_group_policy_attachment" "developers_policy" {
  group      = aws_iam_group.developers.name
  policy_arn = aws_iam_policy.developer_access.arn
}

# ------------------------------------------------------------
# POLICY DOCUMENT: Read Only Access
# Only Get/List/Describe operations
# ------------------------------------------------------------

data "aws_iam_policy_document" "read_only_access" {
  # S3 read-only
  statement {
    sid    = "S3ReadOnly"
    effect = "Allow"
    actions = [
      "s3:Get*",
      "s3:List*"
    ]
    resources = ["*"]
  }

  # DynamoDB read-only
  statement {
    sid    = "DynamoDBReadOnly"
    effect = "Allow"
    actions = [
      "dynamodb:GetItem",
      "dynamodb:BatchGetItem",
      "dynamodb:Scan",
      "dynamodb:Query",
      "dynamodb:DescribeTable",
      "dynamodb:ListTables"
    ]
    resources = ["*"]
  }

  # Lambda read-only (view functions, not invoke)
  statement {
    sid    = "LambdaReadOnly"
    effect = "Allow"
    actions = [
      "lambda:GetFunction",
      "lambda:ListFunctions",
      "lambda:GetFunctionConfiguration"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "read_only_access" {
  name        = "read-only-access"
  description = "Read-only access to AWS resources"
  policy      = data.aws_iam_policy_document.read_only_access.json
  tags        = local.default_tags
}

# Attach policy to read-only group
resource "aws_iam_group_policy_attachment" "read_only_policy" {
  group      = aws_iam_group.read_only.name
  policy_arn = aws_iam_policy.read_only_access.arn
}

# ============================================================
# IAM ROLES (for services)
# ============================================================

# ------------------------------------------------------------
# ROLE: Lambda Execution Role
# Trust: Lambda service can assume this role
# Permissions: Logs + DynamoDB access
# ------------------------------------------------------------

# Trust policy - WHO can assume this role
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

resource "aws_iam_role" "lambda_execution" {
  name               = "${local.prefix}-lambda-execution"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
  tags               = local.default_tags
}

# Permission policy - WHAT can they do
data "aws_iam_policy_document" "lambda_permissions" {
  # CloudWatch Logs
  statement {
    sid    = "CloudWatchLogs"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = ["arn:aws:logs:*:*:*"]
  }

  # DynamoDB - specific table only (least privilege)
  statement {
    sid    = "DynamoDBAccess"
    effect = "Allow"
    actions = [
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:UpdateItem",
      "dynamodb:DeleteItem",
      "dynamodb:Query"
    ]
    resources = [
      "arn:aws:dynamodb:${var.aws_region}:*:table/${local.prefix}-*"
    ]
  }
}

resource "aws_iam_role_policy" "lambda_permissions" {
  name   = "lambda-permissions"
  role   = aws_iam_role.lambda_execution.id
  policy = data.aws_iam_policy_document.lambda_permissions.json
}

# Also attach the basic Lambda execution policy (AWS managed)
resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# ------------------------------------------------------------
# ROLE: API Gateway Role
# Trust: API Gateway service
# Permissions: Invoke Lambda functions
# ------------------------------------------------------------

data "aws_iam_policy_document" "apigateway_assume_role" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["apigateway.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "api_gateway" {
  name               = "${local.prefix}-api-gateway"
  assume_role_policy = data.aws_iam_policy_document.apigateway_assume_role.json
  tags               = local.default_tags
}

data "aws_iam_policy_document" "apigateway_permissions" {
  statement {
    sid    = "InvokeLambda"
    effect = "Allow"
    actions = [
      "lambda:InvokeFunction"
    ]
    resources = ["arn:aws:lambda:${var.aws_region}:*:function:${local.prefix}-*"]
  }
}

resource "aws_iam_role_policy" "apigateway_permissions" {
  name   = "apigateway-permissions"
  role   = aws_iam_role.api_gateway.id
  policy = data.aws_iam_policy_document.apigateway_permissions.json
}

# ------------------------------------------------------------
# ROLE: EC2 Instance Role
# Trust: EC2 service
# Permissions: Read from S3
# ------------------------------------------------------------

data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "ec2_instance" {
  name               = "${local.prefix}-ec2-instance"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
  tags               = local.default_tags
}

data "aws_iam_policy_document" "ec2_permissions" {
  # S3 read-only for specific bucket
  statement {
    sid    = "S3ReadAccess"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:ListBucket"
    ]
    resources = [
      "arn:aws:s3:::${local.prefix}-*",
      "arn:aws:s3:::${local.prefix}-*/*"
    ]
  }
}

resource "aws_iam_role_policy" "ec2_permissions" {
  name   = "ec2-permissions"
  role   = aws_iam_role.ec2_instance.id
  policy = data.aws_iam_policy_document.ec2_permissions.json
}

# Instance profile (required to attach role to EC2)
resource "aws_iam_instance_profile" "ec2_instance" {
  name = "${local.prefix}-ec2-instance"
  role = aws_iam_role.ec2_instance.name
  tags = local.default_tags
}

# ============================================================
# EXAMPLE: DENY POLICY
# Explicitly deny dangerous actions
# ============================================================

data "aws_iam_policy_document" "deny_dangerous_actions" {
  # Deny deleting S3 buckets
  statement {
    sid    = "DenyS3BucketDeletion"
    effect = "Deny"
    actions = [
      "s3:DeleteBucket"
    ]
    resources = ["*"]
  }

  # Deny deleting DynamoDB tables
  statement {
    sid    = "DenyDynamoDBTableDeletion"
    effect = "Deny"
    actions = [
      "dynamodb:DeleteTable"
    ]
    resources = ["*"]
  }

  # Deny modifying IAM (prevent privilege escalation)
  statement {
    sid    = "DenyIAMModifications"
    effect = "Deny"
    actions = [
      "iam:CreateUser",
      "iam:DeleteUser",
      "iam:CreateRole",
      "iam:DeleteRole",
      "iam:AttachUserPolicy",
      "iam:AttachRolePolicy"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "deny_dangerous_actions" {
  name        = "deny-dangerous-actions"
  description = "Deny dangerous actions like deleting resources"
  policy      = data.aws_iam_policy_document.deny_dangerous_actions.json
  tags        = local.default_tags
}

# Attach deny policy to developers (safety net)
resource "aws_iam_group_policy_attachment" "developers_deny" {
  group      = aws_iam_group.developers.name
  policy_arn = aws_iam_policy.deny_dangerous_actions.arn
}

# ============================================================
# EXAMPLE: CONDITIONAL POLICY
# Only allow actions under certain conditions
# ============================================================

data "aws_iam_policy_document" "conditional_access" {
  # Only allow S3 access from specific IP range
  statement {
    sid    = "S3AccessFromOfficeOnly"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject"
    ]
    resources = ["arn:aws:s3:::${local.prefix}-secure-*/*"]

    condition {
      test     = "IpAddress"
      variable = "aws:SourceIp"
      values   = ["192.168.1.0/24", "10.0.0.0/8"]
    }
  }

  # Only allow DynamoDB access during business hours
  # (This is a demo - real implementation would use aws:CurrentTime)
  statement {
    sid    = "DynamoDBWithMFA"
    effect = "Allow"
    actions = [
      "dynamodb:*"
    ]
    resources = ["arn:aws:dynamodb:*:*:table/${local.prefix}-sensitive-*"]

    # Require MFA
    condition {
      test     = "Bool"
      variable = "aws:MultiFactorAuthPresent"
      values   = ["true"]
    }
  }
}

resource "aws_iam_policy" "conditional_access" {
  name        = "conditional-access"
  description = "Access with conditions (IP, MFA, etc.)"
  policy      = data.aws_iam_policy_document.conditional_access.json
  tags        = local.default_tags
}
