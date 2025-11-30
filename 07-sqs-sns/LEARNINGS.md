# SQS & SNS - What We Learned

## The Confusion: SNS vs SQS - They Have Similar Names!

You saw these in LocalStack's event trace:
- `SNS messaging-dev-order-events` (Topic)
- `SQS messaging-dev-orders` (Queue)

**These are completely different things:**

| | SNS (Simple Notification Service) | SQS (Simple Queue Service) |
|---|---|---|
| **What it is** | A **broadcast system** (like a radio station) | A **queue** (like a to-do list) |
| **Analogy** | Megaphone in a room | Ticket queue at a deli counter |
| **Stores messages?** | NO - delivers immediately, then forgets | YES - holds messages until processed |
| **How many receivers?** | Many subscribers get the SAME message | ONE consumer processes each message |
| **Command** | `sns publish` | `sqs send-message` |

---

## The Architecture We Built

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         WHAT WE ACTUALLY BUILT                              │
└─────────────────────────────────────────────────────────────────────────────┘

                              YOUR APPLICATION
                                    │
                 ┌──────────────────┴──────────────────┐
                 │                                     │
           Option A:                             Option B:
        Publish to SNS                      Send directly to SQS
                 │                                     │
                 ▼                                     │
    ┌────────────────────────┐                        │
    │   SNS Topic            │                        │
    │   order-events         │                        │
    │   (broadcaster)        │                        │
    └───────────┬────────────┘                        │
                │                                     │
         Filter Policy                                │
    (only order.created                               │
     and order.updated)                               │
                │                                     │
                ▼                                     ▼
    ┌────────────────────────────────────────────────────┐
    │              SQS Queue: orders                     │
    │              (message storage)                     │
    └───────────────────────┬────────────────────────────┘
                            │
                   Event Source Mapping
                   (Lambda polls automatically)
                            │
                            ▼
    ┌────────────────────────────────────────────────────┐
    │              Lambda: consumer                      │
    │              (processes messages)                  │
    └───────────────────────┬────────────────────────────┘
                            │
               ┌────────────┴────────────┐
               │                         │
           Success                    Failure
               │                         │
               ▼                         ▼
        Message deleted          After 3 retries → DLQ
```

---

## The 5 Commands We Ran (And What Each Did)

### Command 1: Direct to SQS (Bypassing SNS)

```bash
awslocal sqs send-message \
  --queue-url http://sqs.us-east-1.localhost.localstack.cloud:4566/000000000000/messaging-dev-orders \
  --message-body '{"order_id": "ord-001", "customer": "john@example.com", "amount": 150.00}'
```

**What happened:**
```
You ──► SQS Queue ──► Lambda
```

**Trace showed:**
| Producer | Action | Consumer |
|----------|--------|----------|
| External | SendMessage | SQS messaging-dev-orders |
| SQS messaging-dev-orders | EventSourceMapping | Lambda messaging-dev-consumer |

**Key point:** Message went DIRECTLY to the queue. No SNS involved.

---

### Command 2: FIFO Queue (No Lambda Connected)

```bash
awslocal sqs send-message \
  --queue-url http://sqs.us-east-1.localhost.localstack.cloud:4566/000000000000/messaging-dev-payments.fifo \
  --message-body '{"payment_id": "pay-001", "order_id": "ord-001", "amount": 150.00}' \
  --message-group-id "user-123"
```

**What happened:**
```
You ──► SQS FIFO Queue ──► (nothing - message just sits there)
```

**Trace showed:**
| Producer | Action | Consumer |
|----------|--------|----------|
| External | SendMessage | SQS messaging-dev-payments.fifo |

**Key point:** No EventSourceMapping = no Lambda trigger. Message waits forever (or until retention expires).

---

### Command 3: SNS Publish - order.created (FORWARDED)

```bash
awslocal sns publish \
  --topic-arn arn:aws:sns:us-east-1:000000000000:messaging-dev-order-events \
  --message '{"order_id": "ord-002", "customer": "jane@example.com", "amount": 299.99}' \
  --message-attributes '{"event_type": {"DataType": "String", "StringValue": "order.created"}}'
```

**What happened:**
```
You ──► SNS Topic ──► SQS Queue ──► Lambda
```

**Trace showed:**
| Producer | Action | Consumer |
|----------|--------|----------|
| External | Publish | SNS messaging-dev-order-events |
| SNS messaging-dev-order-events | SendMessage | SQS messaging-dev-orders |
| SQS messaging-dev-orders | EventSourceMapping | Lambda messaging-dev-consumer |

**Key point:** THREE HOPS. SNS received it, checked the filter policy, forwarded to SQS, then Lambda processed it.

---

### Command 4: SNS Publish - order.updated (FORWARDED)

```bash
awslocal sns publish \
  --topic-arn arn:aws:sns:us-east-1:000000000000:messaging-dev-order-events \
  --message '{"order_id": "ord-002", "status": "shipped", "tracking": "1Z999AA10123456784"}' \
  --message-attributes '{"event_type": {"DataType": "String", "StringValue": "order.updated"}}'
```

**What happened:** Same as Command 3 - filter matched, message forwarded.

---

### Command 5: SNS Publish - order.cancelled (FILTERED OUT!)

```bash
awslocal sns publish \
  --topic-arn arn:aws:sns:us-east-1:000000000000:messaging-dev-order-events \
  --message '{"order_id": "ord-003", "reason": "customer request"}' \
  --message-attributes '{"event_type": {"DataType": "String", "StringValue": "order.cancelled"}}'
```

**What happened:**
```
You ──► SNS Topic ──X (STOPPED - filter rejected it)
```

**Trace showed:**
| Producer | Action | Consumer |
|----------|--------|----------|
| External | Publish | SNS messaging-dev-order-events |

**Key point:** Only ONE hop! SNS received it but the filter policy rejected `order.cancelled`, so it was NEVER sent to SQS. Lambda never saw it.

---

## The Filter Policy (This Is The Magic)

Defined in Terraform:
```hcl
resource "aws_sns_topic_subscription" "order_events_to_sqs" {
  topic_arn = aws_sns_topic.order_events.arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.orders.arn

  filter_policy = jsonencode({
    event_type = ["order.created", "order.updated"]  # ← ONLY these pass through
  })
}
```

| event_type value | Matches filter? | Result |
|------------------|-----------------|--------|
| `order.created` | ✅ Yes | Forwarded to SQS |
| `order.updated` | ✅ Yes | Forwarded to SQS |
| `order.cancelled` | ❌ No | Dropped silently |
| `order.refunded` | ❌ No | Dropped silently |

---

## Why Use SNS At All? (The Fan-Out Pattern)

If you only have one consumer, you could just send directly to SQS. But SNS lets you do this:

```
                              ┌──► SQS: orders     ──► Lambda (process order)
                              │
You ──► SNS: order-events ────┼──► SQS: analytics  ──► Lambda (track metrics)
                              │
                              └──► SQS: email      ──► Lambda (send confirmation)
```

**ONE publish, THREE different systems receive it.** Each queue can have its own filter:
- Orders queue: only `order.created`, `order.updated`
- Analytics queue: ALL events
- Email queue: only `order.created`

---

## Summary: When To Use What

| Scenario | Use This |
|----------|----------|
| One producer, one consumer | SQS directly |
| One producer, many consumers | SNS → multiple SQS queues |
| Need to filter events | SNS with filter policies |
| Need guaranteed order | FIFO queue |
| Need retry on failure | SQS + DLQ |
| Background job processing | SQS → Lambda |

---

## The Resources We Created

| Resource | Type | Purpose |
|----------|------|---------|
| `messaging-dev-orders` | SQS Standard Queue | Holds order messages |
| `messaging-dev-orders-dlq` | SQS Standard Queue | Holds failed messages |
| `messaging-dev-payments.fifo` | SQS FIFO Queue | Holds payment messages (ordered) |
| `messaging-dev-order-events` | SNS Topic | Broadcasts order events |
| `messaging-dev-notifications` | SNS Topic | (unused in demo) |
| `messaging-dev-consumer` | Lambda Function | Processes messages from orders queue |

---

## Quick Reference Commands

```bash
# Check what's in a queue
awslocal sqs get-queue-attributes \
  --queue-url http://sqs.us-east-1.localhost.localstack.cloud:4566/000000000000/messaging-dev-orders \
  --attribute-names ApproximateNumberOfMessages

# Read a message (without deleting)
awslocal sqs receive-message \
  --queue-url http://sqs.us-east-1.localhost.localstack.cloud:4566/000000000000/messaging-dev-orders \
  --visibility-timeout 0

# Check Lambda logs
awslocal logs filter-log-events \
  --log-group-name /aws/lambda/messaging-dev-consumer \
  --limit 10

# List SNS subscriptions
awslocal sns list-subscriptions-by-topic \
  --topic-arn arn:aws:sns:us-east-1:000000000000:messaging-dev-order-events
```
