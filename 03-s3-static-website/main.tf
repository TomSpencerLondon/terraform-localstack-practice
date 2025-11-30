# ============================================================
# EXERCISE 03: S3 Static Website
# Learn S3 website hosting, bucket policies, and templatefile()
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
    s3 = var.localstack_endpoint
  }

  s3_use_path_style = true
}

# ------------------------------------------------------------
# LOCALS
# ------------------------------------------------------------

locals {
  bucket_name = "${var.bucket_prefix}-${var.environment}-website"

  default_tags = {
    Environment = var.environment
    Project     = "terraform-learning"
    Exercise    = "03-s3-static-website"
    ManagedBy   = "terraform"
  }
}

# ------------------------------------------------------------
# S3 BUCKET
# ------------------------------------------------------------

resource "aws_s3_bucket" "website" {
  bucket = local.bucket_name
  tags   = local.default_tags
}

# ------------------------------------------------------------
# S3 WEBSITE CONFIGURATION
# This enables static website hosting on the bucket
# ------------------------------------------------------------

resource "aws_s3_bucket_website_configuration" "website" {
  bucket = aws_s3_bucket.website.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "error.html"
  }
}

# ------------------------------------------------------------
# PUBLIC ACCESS SETTINGS
# By default, S3 buckets block public access
# For a static website, we need to allow it
# ------------------------------------------------------------

resource "aws_s3_bucket_public_access_block" "website" {
  bucket = aws_s3_bucket.website.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# ------------------------------------------------------------
# BUCKET POLICY
# Allow anyone to read objects (required for public website)
# ------------------------------------------------------------

resource "aws_s3_bucket_policy" "website" {
  bucket = aws_s3_bucket.website.id

  # Wait for public access block to be configured first
  depends_on = [aws_s3_bucket_public_access_block.website]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.website.arn}/*"
      }
    ]
  })
}

# ------------------------------------------------------------
# WEBSITE FILES
# Using templatefile() to inject variables into HTML
# ------------------------------------------------------------

resource "aws_s3_object" "index" {
  bucket       = aws_s3_bucket.website.id
  key          = "index.html"
  content_type = "text/html"

  # templatefile() reads a file and substitutes variables
  content = templatefile("${path.module}/website/index.html", {
    site_name   = var.site_name
    author      = var.author
    environment = var.environment
  })

  # etag triggers re-upload when content changes
  etag = md5(templatefile("${path.module}/website/index.html", {
    site_name   = var.site_name
    author      = var.author
    environment = var.environment
  }))
}

resource "aws_s3_object" "error" {
  bucket       = aws_s3_bucket.website.id
  key          = "error.html"
  content_type = "text/html"
  source       = "${path.module}/website/error.html"
  etag         = filemd5("${path.module}/website/error.html")
}

resource "aws_s3_object" "styles" {
  bucket       = aws_s3_bucket.website.id
  key          = "styles.css"
  content_type = "text/css"
  source       = "${path.module}/website/styles.css"
  etag         = filemd5("${path.module}/website/styles.css")
}
