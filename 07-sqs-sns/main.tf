# ============================================================
# EXERCISE 07: SQS & SNS
# Learn messaging with queues and pub/sub notifications
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
    sqs    = var.localstack_endpoint
    sns    = var.localstack_endpoint
    lambda = var.localstack_endpoint
    iam    = var.localstack_endpoint
    logs   = var.localstack_endpoint
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
    Exercise    = "07-sqs-sns"
    ManagedBy   = "terraform"
  }
}

# ============================================================
# SQS QUEUES
# ============================================================

# ------------------------------------------------------------
# STANDARD QUEUE
# Best-effort ordering, at-least-once delivery
# ------------------------------------------------------------

resource "aws_sqs_queue" "orders" {
  name = "${local.prefix}-orders"

  # How long messages are invisible after being received (seconds)
  visibility_timeout_seconds = 30

  # How long messages stay in queue if not processed (seconds)
  message_retention_seconds = 86400  # 1 day

  # Max message size (bytes) - max 256KB
  max_message_size = 262144

  # Long polling - wait up to 20s for messages (reduces API calls)
  receive_wait_time_seconds = 10

  tags = local.default_tags
}

# ------------------------------------------------------------
# DEAD LETTER QUEUE (DLQ)
# Where failed messages go after max retries
# ------------------------------------------------------------

resource "aws_sqs_queue" "orders_dlq" {
  name = "${local.prefix}-orders-dlq"

  # Keep failed messages longer for debugging
  message_retention_seconds = 1209600  # 14 days

  tags = local.default_tags
}

# Configure the main queue to use the DLQ
resource "aws_sqs_queue_redrive_policy" "orders" {
  queue_url = aws_sqs_queue.orders.id

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.orders_dlq.arn
    maxReceiveCount     = 3  # After 3 failed attempts, move to DLQ
  })
}

# ------------------------------------------------------------
# FIFO QUEUE
# Exactly-once processing, strict ordering
# ------------------------------------------------------------

resource "aws_sqs_queue" "payments" {
  name                        = "${local.prefix}-payments.fifo"
  fifo_queue                  = true
  content_based_deduplication = true  # Dedupe based on message body

  # FIFO queues have stricter limits
  visibility_timeout_seconds = 30
  message_retention_seconds  = 86400

  tags = local.default_tags
}

# ============================================================
# SNS TOPICS
# ============================================================

# ------------------------------------------------------------
# SNS TOPIC - NOTIFICATIONS
# Pub/Sub - one message to many subscribers
# ------------------------------------------------------------

resource "aws_sns_topic" "notifications" {
  name = "${local.prefix}-notifications"
  tags = local.default_tags
}

# ------------------------------------------------------------
# SNS TOPIC - ORDER EVENTS
# Fan-out pattern - order events to multiple consumers
# ------------------------------------------------------------

resource "aws_sns_topic" "order_events" {
  name = "${local.prefix}-order-events"
  tags = local.default_tags
}

# ============================================================
# SNS SUBSCRIPTIONS
# ============================================================

# ------------------------------------------------------------
# SNS → SQS SUBSCRIPTION
# Send order events to the orders queue
# ------------------------------------------------------------

resource "aws_sns_topic_subscription" "order_events_to_sqs" {
  topic_arn = aws_sns_topic.order_events.arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.orders.arn

  # Filter - only receive certain message types
  filter_policy = jsonencode({
    event_type = ["order.created", "order.updated"]
  })
}

# Allow SNS to send messages to SQS
resource "aws_sqs_queue_policy" "orders_policy" {
  queue_url = aws_sqs_queue.orders.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowSNSToSendMessage"
        Effect    = "Allow"
        Principal = { Service = "sns.amazonaws.com" }
        Action    = "sqs:SendMessage"
        Resource  = aws_sqs_queue.orders.arn
        Condition = {
          ArnEquals = {
            "aws:SourceArn" = aws_sns_topic.order_events.arn
          }
        }
      }
    ]
  })
}

# ============================================================
# LAMBDA CONSUMER
# Process messages from SQS
# ============================================================

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/src"
  output_path = "${path.module}/lambda.zip"
}

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

resource "aws_iam_role" "lambda_role" {
  name               = "${local.prefix}-consumer-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
  tags               = local.default_tags
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Policy to allow Lambda to receive from SQS
resource "aws_iam_role_policy" "lambda_sqs" {
  name = "sqs-access"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ]
        Resource = aws_sqs_queue.orders.arn
      }
    ]
  })
}

resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${local.prefix}-consumer"
  retention_in_days = 7
  tags              = local.default_tags
}

resource "aws_lambda_function" "consumer" {
  function_name = "${local.prefix}-consumer"
  description   = "Processes messages from SQS queue"

  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  runtime     = "python3.11"
  handler     = "consumer.lambda_handler"
  timeout     = 30
  memory_size = 128

  role = aws_iam_role.lambda_role.arn

  environment {
    variables = {
      ENVIRONMENT = var.environment
      LOG_LEVEL   = "INFO"
    }
  }

  tags = local.default_tags

  depends_on = [
    aws_cloudwatch_log_group.lambda_logs,
    aws_iam_role_policy_attachment.lambda_basic
  ]
}

# ------------------------------------------------------------
# SQS → LAMBDA EVENT SOURCE MAPPING
# Automatically trigger Lambda when messages arrive
# ------------------------------------------------------------

resource "aws_lambda_event_source_mapping" "sqs_trigger" {
  event_source_arn = aws_sqs_queue.orders.arn
  function_name    = aws_lambda_function.consumer.arn
  batch_size       = 10  # Process up to 10 messages at once
  enabled          = true
}
