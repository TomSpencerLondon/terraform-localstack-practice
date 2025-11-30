# ============================================================
# OUTPUTS
# ============================================================

# SQS Queues
output "orders_queue" {
  description = "Orders SQS queue details"
  value = {
    name = aws_sqs_queue.orders.name
    url  = aws_sqs_queue.orders.url
    arn  = aws_sqs_queue.orders.arn
    type = "Standard"
  }
}

output "orders_dlq" {
  description = "Orders Dead Letter Queue details"
  value = {
    name = aws_sqs_queue.orders_dlq.name
    url  = aws_sqs_queue.orders_dlq.url
    arn  = aws_sqs_queue.orders_dlq.arn
  }
}

output "payments_queue" {
  description = "Payments FIFO queue details"
  value = {
    name = aws_sqs_queue.payments.name
    url  = aws_sqs_queue.payments.url
    arn  = aws_sqs_queue.payments.arn
    type = "FIFO"
  }
}

# SNS Topics
output "notifications_topic" {
  description = "Notifications SNS topic"
  value = {
    name = aws_sns_topic.notifications.name
    arn  = aws_sns_topic.notifications.arn
  }
}

output "order_events_topic" {
  description = "Order events SNS topic"
  value = {
    name = aws_sns_topic.order_events.name
    arn  = aws_sns_topic.order_events.arn
  }
}

# Lambda Consumer
output "consumer_function" {
  description = "Consumer Lambda function"
  value = {
    name = aws_lambda_function.consumer.function_name
    arn  = aws_lambda_function.consumer.arn
  }
}

# Example Commands
output "example_commands" {
  description = "Example CLI commands"
  value       = <<-EOT

    # ============================================================
    # SQS Commands
    # ============================================================

    # Send message to queue
    awslocal sqs send-message \
      --queue-url ${aws_sqs_queue.orders.url} \
      --message-body '{"order_id": "ord-123", "amount": 99.99}'

    # Receive messages (polls for up to 10 seconds)
    awslocal sqs receive-message \
      --queue-url ${aws_sqs_queue.orders.url} \
      --wait-time-seconds 10

    # Check queue attributes (message count)
    awslocal sqs get-queue-attributes \
      --queue-url ${aws_sqs_queue.orders.url} \
      --attribute-names ApproximateNumberOfMessages

    # Send FIFO message (requires MessageGroupId)
    awslocal sqs send-message \
      --queue-url ${aws_sqs_queue.payments.url} \
      --message-body '{"payment_id": "pay-123"}' \
      --message-group-id "user-001"

    # ============================================================
    # SNS Commands
    # ============================================================

    # Publish to SNS (fans out to all subscribers)
    awslocal sns publish \
      --topic-arn ${aws_sns_topic.order_events.arn} \
      --message '{"order_id": "ord-456", "event_type": "order.created"}' \
      --message-attributes '{"event_type": {"DataType": "String", "StringValue": "order.created"}}'

    # List subscriptions
    awslocal sns list-subscriptions-by-topic \
      --topic-arn ${aws_sns_topic.order_events.arn}

  EOT
}
