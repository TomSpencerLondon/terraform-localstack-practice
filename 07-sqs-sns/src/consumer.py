"""
SQS Consumer Lambda - Exercise 07

This Lambda is triggered by SQS messages.
Demonstrates:
- Processing SQS event batches
- Handling SNS-wrapped messages
- Parsing message bodies
- Error handling for partial batch failures
"""

import json
import logging
import os

logger = logging.getLogger()
logger.setLevel(os.environ.get('LOG_LEVEL', 'INFO'))


def lambda_handler(event, context):
    """
    Process messages from SQS queue.

    SQS sends batches of messages. Each record contains:
    - messageId: Unique message ID
    - body: Message content (string)
    - attributes: Message metadata
    - receiptHandle: Token to delete message
    """
    logger.info(f"Received {len(event.get('Records', []))} messages")

    processed = 0
    failed = 0

    for record in event.get('Records', []):
        try:
            message_id = record.get('messageId')
            body = record.get('body', '{}')

            logger.info(f"Processing message {message_id}")

            # Parse the body - might be direct SQS or SNS-wrapped
            message = parse_message(body)

            # Process the message (your business logic here)
            result = process_message(message)

            logger.info(f"Successfully processed message {message_id}: {result}")
            processed += 1

        except Exception as e:
            logger.error(f"Failed to process message {record.get('messageId')}: {e}")
            failed += 1
            # Don't re-raise - let other messages in batch continue
            # Failed messages will be retried based on visibility timeout

    response = {
        'statusCode': 200,
        'body': json.dumps({
            'processed': processed,
            'failed': failed,
            'total': len(event.get('Records', []))
        })
    }

    logger.info(f"Batch complete: {response}")
    return response


def parse_message(body):
    """
    Parse message body - handles both direct SQS and SNS-wrapped messages.

    Direct SQS message:
    {"order_id": "123", "amount": 99.99}

    SNS-wrapped message:
    {"Type": "Notification", "Message": "{...}", "TopicArn": "..."}
    """
    try:
        data = json.loads(body)

        # Check if this is an SNS notification
        if data.get('Type') == 'Notification':
            # Extract the actual message from SNS wrapper
            message_str = data.get('Message', '{}')
            message = json.loads(message_str)

            # Add SNS metadata
            message['_sns'] = {
                'topic_arn': data.get('TopicArn'),
                'message_id': data.get('MessageId'),
                'timestamp': data.get('Timestamp')
            }
            return message

        # Direct SQS message
        return data

    except json.JSONDecodeError:
        # Return raw body if not JSON
        return {'raw': body}


def process_message(message):
    """
    Process the parsed message - your business logic goes here.
    """
    # Example: Handle order events
    if 'order_id' in message:
        order_id = message['order_id']
        event_type = message.get('event_type', 'unknown')

        logger.info(f"Processing order {order_id}, event: {event_type}")

        # Simulate processing based on event type
        if event_type == 'order.created':
            return f"Created order {order_id}"
        elif event_type == 'order.updated':
            return f"Updated order {order_id}"
        elif event_type == 'order.cancelled':
            return f"Cancelled order {order_id}"
        else:
            return f"Processed order {order_id}"

    # Generic message
    return f"Processed message: {json.dumps(message)[:100]}"
