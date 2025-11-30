# SQS & SNS Message Flow Architecture

This document explains how messages flow through the Exercise 07 infrastructure.

## Overview

This exercise demonstrates two AWS messaging services working together:
- **SNS (Simple Notification Service)** - Pub/Sub: one message goes to many subscribers
- **SQS (Simple Queue Service)** - Queue: messages wait to be processed one at a time

## The Complete Message Flow

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         MESSAGE FLOW ARCHITECTURE                           │
└─────────────────────────────────────────────────────────────────────────────┘

                              APPLICATION
                           (API, Service, etc.)
                                   │
                                   │ 1. Publish event
                                   ▼
                         ┌─────────────────┐
                         │   SNS Topic     │
                         │  order-events   │
                         └────────┬────────┘
                                  │
                                  │ 2. SNS checks filter policy
                                  │    Only forwards if event_type matches:
                                  │    ["order.created", "order.updated"]
                                  │
                                  ▼
                         ┌─────────────────┐
                         │   SQS Queue     │
                         │    orders       │ 3. Message waits in queue
                         │   (Standard)    │    (up to 1 day retention)
                         └────────┬────────┘
                                  │
                                  │ 4. Lambda polls queue every few seconds
                                  │    (Event Source Mapping)
                                  │
                                  ▼
                         ┌─────────────────┐
                         │     Lambda      │
                         │    consumer     │ 5. Processes up to 10 messages
                         └────────┬────────┘    per batch
                                  │
                 ┌────────────────┴────────────────┐
                 │                                 │
              SUCCESS                           FAILURE
                 │                                 │
                 ▼                                 ▼
         6a. Delete message              6b. Message becomes visible
             from queue                      again after 30 seconds
                                             (visibility timeout)
                                                   │
                                         After 3 failed attempts
                                         (maxReceiveCount = 3)
                                                   │
                                                   ▼
                                         ┌─────────────────┐
                                         │   Dead Letter   │
                                         │   Queue (DLQ)   │
                                         │   orders-dlq    │ 7. Failed messages
                                         └─────────────────┘    kept for 14 days
```

## Step-by-Step Explanation

### Step 1: Publish Event to SNS

An application publishes an order event to the SNS topic:

```bash
awslocal sns publish \
  --topic-arn arn:aws:sns:us-east-1:000000000000:ex07-dev-order-events \
  --message '{"order_id": "123", "amount": 99.99}' \
  --message-attributes '{"event_type": {"DataType": "String", "StringValue": "order.created"}}'
```

**Why SNS?** It allows multiple subscribers to receive the same message. You could have:
- Orders queue (for processing)
- Analytics queue (for reporting)
- Email notification (for admins)

All receiving the same event simultaneously.

### Step 2: SNS Filter Policy

The subscription has a filter policy defined in Terraform:

```hcl
filter_policy = jsonencode({
  event_type = ["order.created", "order.updated"]
})
```

This means:
- `order.created` → Forwarded to SQS
- `order.updated` → Forwarded to SQS
- `order.cancelled` → **Filtered out, NOT forwarded**

### Step 3: Message Lands in SQS Queue

The message is now in the SQS queue, waiting to be processed. Key settings:

| Setting | Value | Meaning |
|---------|-------|---------|
| `message_retention_seconds` | 86400 | Messages kept for 1 day |
| `receive_wait_time_seconds` | 10 | Long polling (efficient) |
| `visibility_timeout_seconds` | 30 | Hide message for 30s while processing |

### Step 4: Lambda Polls the Queue

The Event Source Mapping automatically:
- Polls the queue for new messages
- Invokes Lambda when messages arrive
- Handles batching (up to 10 messages per invocation)

```hcl
resource "aws_lambda_event_source_mapping" "sqs_trigger" {
  event_source_arn = aws_sqs_queue.orders.arn
  function_name    = aws_lambda_function.consumer.arn
  batch_size       = 10
}
```

### Step 5: Lambda Processes Messages

The Lambda function (`consumer.py`) receives a batch of messages:

```python
def lambda_handler(event, context):
    for record in event.get('Records', []):
        message_id = record.get('messageId')
        body = record.get('body')

        # Parse and process the message
        message = parse_message(body)
        result = process_message(message)
```

### Step 6a: Success Path

If processing succeeds:
- Lambda returns successfully
- AWS automatically deletes the message from the queue
- Message is gone forever

### Step 6b: Failure Path

If processing fails:
1. Lambda throws an exception or times out
2. Message is NOT deleted
3. After `visibility_timeout` (30 seconds), message becomes visible again
4. Another Lambda invocation picks it up and retries

### Step 7: Dead Letter Queue

After 3 failed attempts (`maxReceiveCount = 3`):
- Message is moved to the DLQ
- Kept for 14 days for debugging
- You can inspect what went wrong

```bash
# Check the DLQ for failed messages
awslocal sqs receive-message \
  --queue-url http://localhost:4566/000000000000/ex07-dev-orders-dlq
```

## The FIFO Queue (Payments)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         FIFO QUEUE (SEPARATE)                               │
└─────────────────────────────────────────────────────────────────────────────┘

         ┌─────────────────┐
         │   SQS Queue     │
         │   payments      │  Not connected to SNS or Lambda
         │    (FIFO)       │  in this exercise
         └─────────────────┘

         Characteristics:
         - Exactly-once processing (no duplicates)
         - Strict ordering within MessageGroupId
         - Queue name must end in .fifo
         - Limited to 300 TPS (vs unlimited for Standard)
```

**When to use FIFO:**
- Payment processing (order matters, no duplicates)
- Sequential operations on the same entity
- When you can't tolerate duplicate processing

**Example FIFO message:**
```bash
awslocal sqs send-message \
  --queue-url http://localhost:4566/000000000000/ex07-dev-payments.fifo \
  --message-body '{"payment_id": "pay-123", "amount": 50.00}' \
  --message-group-id "user-001"  # Required for FIFO
```

## Key Concepts Summary

| Concept | What It Does |
|---------|--------------|
| **SNS Topic** | Broadcasts messages to multiple subscribers |
| **Filter Policy** | Routes only matching messages to subscriber |
| **SQS Queue** | Stores messages until processed |
| **Event Source Mapping** | Connects SQS to Lambda (auto-polling) |
| **Visibility Timeout** | Hides message while being processed |
| **Dead Letter Queue** | Catches failed messages for debugging |
| **FIFO Queue** | Guarantees order and exactly-once delivery |

## Testing the Flow

```bash
# 1. Send a message that WILL be forwarded (matches filter)
awslocal sns publish \
  --topic-arn arn:aws:sns:us-east-1:000000000000:ex07-dev-order-events \
  --message '{"order_id": "123"}' \
  --message-attributes '{"event_type": {"DataType": "String", "StringValue": "order.created"}}'

# 2. Check if Lambda processed it (check logs)
awslocal logs tail /aws/lambda/ex07-dev-consumer --follow

# 3. Send a message that WON'T be forwarded (filtered out)
awslocal sns publish \
  --topic-arn arn:aws:sns:us-east-1:000000000000:ex07-dev-order-events \
  --message '{"order_id": "456"}' \
  --message-attributes '{"event_type": {"DataType": "String", "StringValue": "order.cancelled"}}'

# This message won't reach the queue because "order.cancelled"
# is not in the filter policy
```
