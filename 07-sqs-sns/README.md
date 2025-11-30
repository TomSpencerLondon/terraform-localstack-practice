# Exercise 07: SQS & SNS

Learn messaging patterns with queues (SQS) and pub/sub (SNS).

## Concepts Covered

- `aws_sqs_queue` - Standard and FIFO queues
- `aws_sqs_queue_redrive_policy` - Dead Letter Queues
- `aws_sns_topic` - Pub/Sub topics
- `aws_sns_topic_subscription` - Subscribe to topics
- `aws_lambda_event_source_mapping` - Trigger Lambda from SQS
- Message filtering with filter policies
- Fan-out pattern (SNS → multiple SQS)

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        Messaging Architecture                                │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│                        ┌─────────────┐                                      │
│                        │  SNS Topic  │ ← Publish order events               │
│                        │ order-events│                                      │
│                        └──────┬──────┘                                      │
│                               │                                              │
│                    Filter: event_type =                                     │
│               ["order.created", "order.updated"]                            │
│                               │                                              │
│                               ▼                                              │
│  ┌─────────────┐      ┌─────────────┐      ┌─────────────┐                 │
│  │  SQS Queue  │      │  SQS Queue  │      │  SQS Queue  │                 │
│  │   orders    │◄─────│  (others)   │      │   payments  │                 │
│  │  (Standard) │      │             │      │   (FIFO)    │                 │
│  └──────┬──────┘      └─────────────┘      └─────────────┘                 │
│         │                                                                    │
│         │ Event Source Mapping                                              │
│         ▼                                                                    │
│  ┌─────────────┐      ┌─────────────┐                                      │
│  │   Lambda    │      │    DLQ      │ ← Failed messages (after 3 retries)  │
│  │  consumer   │      │  orders-dlq │                                      │
│  └─────────────┘      └─────────────┘                                      │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

## SQS vs SNS

| Feature | SQS (Queue) | SNS (Topic) |
|---------|-------------|-------------|
| Pattern | Point-to-point | Pub/Sub |
| Consumers | One consumer processes each message | Many subscribers get the same message |
| Persistence | Messages stored until processed | No persistence (deliver and forget) |
| Polling | Consumer polls for messages | Push to subscribers |
| Use case | Task queue, job processing | Notifications, fan-out |

## The 3 Queues Explained

### 1. Standard Queue (`orders`)

```hcl
resource "aws_sqs_queue" "orders" {
  name                       = "orders"
  visibility_timeout_seconds = 30    # Hide message while processing
  message_retention_seconds  = 86400 # Keep for 1 day
  receive_wait_time_seconds  = 10    # Long polling
}
```

**Characteristics:**
- Best-effort ordering (may be out of order)
- At-least-once delivery (may get duplicates)
- Nearly unlimited throughput
- Use for: Order processing, job queues

### 2. Dead Letter Queue (`orders-dlq`)

```hcl
resource "aws_sqs_queue" "orders_dlq" {
  name = "orders-dlq"
  message_retention_seconds = 1209600  # 14 days
}

resource "aws_sqs_queue_redrive_policy" "orders" {
  queue_url = aws_sqs_queue.orders.id
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.orders_dlq.arn
    maxReceiveCount     = 3  # Move to DLQ after 3 failures
  })
}
```

**How DLQ works:**
1. Message received by consumer
2. Consumer fails to process (doesn't delete message)
3. Message becomes visible again after `visibility_timeout`
4. After `maxReceiveCount` attempts, moved to DLQ
5. Inspect DLQ to debug failures

### 3. FIFO Queue (`payments`)

```hcl
resource "aws_sqs_queue" "payments" {
  name                        = "payments.fifo"  # Must end in .fifo
  fifo_queue                  = true
  content_based_deduplication = true
}
```

**Characteristics:**
- Exactly-once processing (no duplicates)
- Strict ordering within MessageGroupId
- Limited to 300 TPS (3000 with batching)
- Use for: Payments, sequential operations

**FIFO requirements:**
- Queue name must end in `.fifo`
- Messages need `MessageGroupId`
- Either `MessageDeduplicationId` or `content_based_deduplication`

## SNS Topics

### Publishing Messages

```bash
# Publish to SNS
awslocal sns publish \
  --topic-arn arn:aws:sns:us-east-1:000000000000:order-events \
  --message '{"order_id": "123", "event_type": "order.created"}' \
  --message-attributes '{"event_type": {"DataType": "String", "StringValue": "order.created"}}'
```

### Subscription with Filter

```hcl
resource "aws_sns_topic_subscription" "order_events_to_sqs" {
  topic_arn = aws_sns_topic.order_events.arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.orders.arn

  # Only receive these event types
  filter_policy = jsonencode({
    event_type = ["order.created", "order.updated"]
  })
}
```

**Filter policy options:**
```json
{"event_type": ["order.created"]}           // Exact match
{"amount": [{"numeric": [">", 100]}]}       // Numeric comparison
{"status": [{"prefix": "order."}]}          // Prefix match
{"region": [{"anything-but": "us-west-2"}]} // Exclusion
```

## Lambda Event Source Mapping

```hcl
resource "aws_lambda_event_source_mapping" "sqs_trigger" {
  event_source_arn = aws_sqs_queue.orders.arn
  function_name    = aws_lambda_function.consumer.arn
  batch_size       = 10  # Process up to 10 messages at once
  enabled          = true
}
```

**How it works:**
1. Lambda polls SQS automatically
2. Receives batch of messages (up to batch_size)
3. Processes messages
4. If successful, deletes messages from queue
5. If failed, messages become visible again for retry

## Message Flow Example

```
1. API receives order
   │
   ▼
2. Publish to SNS: order-events
   {"order_id": "123", "event_type": "order.created"}
   │
   ▼
3. SNS delivers to subscribers
   ├── SQS: orders (filter matches)
   ├── SQS: analytics (different filter)
   └── Email: admin@example.com
   │
   ▼
4. Lambda polls orders queue
   │
   ▼
5. Lambda processes message
   │
   ├── Success → Delete from queue
   └── Failure → Retry (up to 3x) → DLQ
```

## Commands

```bash
# Deploy
./run.sh

# Or manually
terraform init
terraform apply

# Send message to SQS
awslocal sqs send-message \
  --queue-url <queue-url> \
  --message-body '{"order_id": "123"}'

# Publish to SNS (fans out to all subscribers)
awslocal sns publish \
  --topic-arn <topic-arn> \
  --message '{"order_id": "123", "event_type": "order.created"}'

# Receive messages
awslocal sqs receive-message --queue-url <queue-url>

# Check message count
awslocal sqs get-queue-attributes \
  --queue-url <queue-url> \
  --attribute-names ApproximateNumberOfMessages

# Check DLQ for failed messages
awslocal sqs receive-message --queue-url <dlq-url>
```

## Common Patterns

### 1. Fan-out (One to Many)
SNS → Multiple SQS queues
Use for: Sending same event to multiple services

### 2. Work Queue
SQS → Lambda
Use for: Background job processing

### 3. Retry with DLQ
SQS + DLQ
Use for: Handling failures gracefully

### 4. Ordered Processing
FIFO Queue + MessageGroupId
Use for: Maintaining order per entity

## Real AWS vs LocalStack

| Feature | Real AWS | LocalStack |
|---------|----------|------------|
| Long polling | Yes | Yes |
| FIFO queues | Yes | Yes |
| Dead letter queues | Yes | Yes |
| SNS filter policies | Yes | Partial |
| SMS/Email delivery | Yes | No |
| Lambda triggers | Yes | Yes |

## Challenges

1. Add a second SQS subscriber to SNS with different filter
2. Implement partial batch failure handling in Lambda
3. Add SNS → Lambda subscription (direct, no queue)
4. Create an SNS topic with email subscription

## Clean Up

```bash
terraform destroy
```
