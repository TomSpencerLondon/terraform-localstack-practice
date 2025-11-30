# ============================================================
# EXERCISE 05: DynamoDB
# Learn NoSQL database tables, keys, indexes, and CRUD operations
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
    dynamodb = var.localstack_endpoint
  }
}

# ------------------------------------------------------------
# LOCALS
# ------------------------------------------------------------

locals {
  table_prefix = "${var.project_name}-${var.environment}"

  default_tags = {
    Environment = var.environment
    Project     = "terraform-learning"
    Exercise    = "05-dynamodb"
    ManagedBy   = "terraform"
  }
}

# ------------------------------------------------------------
# DYNAMODB TABLE: USERS
# Simple table with partition key only
# ------------------------------------------------------------

resource "aws_dynamodb_table" "users" {
  name         = "${local.table_prefix}-users"
  billing_mode = "PAY_PER_REQUEST"  # On-demand pricing (no capacity planning)
  hash_key     = "user_id"          # Partition key

  # Define the key attribute
  attribute {
    name = "user_id"
    type = "S"  # S = String, N = Number, B = Binary
  }

  tags = local.default_tags
}

# ------------------------------------------------------------
# DYNAMODB TABLE: ORDERS
# Table with composite key (partition + sort key)
# ------------------------------------------------------------

resource "aws_dynamodb_table" "orders" {
  name         = "${local.table_prefix}-orders"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "user_id"      # Partition key - which user
  range_key    = "order_id"     # Sort key - which order

  # Must define all key attributes
  attribute {
    name = "user_id"
    type = "S"
  }

  attribute {
    name = "order_id"
    type = "S"
  }

  # Attribute for GSI (must be defined if used in index)
  attribute {
    name = "status"
    type = "S"
  }

  attribute {
    name = "created_at"
    type = "S"
  }

  # ------------------------------------------------------------
  # GLOBAL SECONDARY INDEX (GSI)
  # Query orders by status across all users
  # ------------------------------------------------------------
  global_secondary_index {
    name            = "status-index"
    hash_key        = "status"
    range_key       = "created_at"
    projection_type = "ALL"  # Include all attributes
  }

  tags = local.default_tags
}

# ------------------------------------------------------------
# DYNAMODB TABLE: SESSIONS
# Table with TTL (Time To Live) for automatic expiration
# ------------------------------------------------------------

resource "aws_dynamodb_table" "sessions" {
  name         = "${local.table_prefix}-sessions"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "session_id"

  attribute {
    name = "session_id"
    type = "S"
  }

  # Enable TTL - items automatically deleted after expiry
  ttl {
    attribute_name = "expires_at"
    enabled        = true
  }

  tags = local.default_tags
}

# ------------------------------------------------------------
# DYNAMODB TABLE: PRODUCTS
# Table with provisioned capacity (for learning)
# ------------------------------------------------------------

resource "aws_dynamodb_table" "products" {
  name           = "${local.table_prefix}-products"
  billing_mode   = "PROVISIONED"
  read_capacity  = 5   # Read capacity units
  write_capacity = 5   # Write capacity units
  hash_key       = "product_id"
  range_key      = "category"  # Sort key required for LSI

  attribute {
    name = "product_id"
    type = "S"
  }

  attribute {
    name = "category"
    type = "S"
  }

  attribute {
    name = "price"
    type = "N"  # Number type for price
  }

  # LSI - must have same partition key as table, different sort key
  local_secondary_index {
    name            = "price-index"
    range_key       = "price"
    projection_type = "ALL"
  }

  # GSI - can have different partition key
  global_secondary_index {
    name            = "category-index"
    hash_key        = "category"
    range_key       = "price"
    projection_type = "INCLUDE"
    non_key_attributes = ["name", "description"]
    read_capacity   = 5
    write_capacity  = 5
  }

  tags = local.default_tags
}
