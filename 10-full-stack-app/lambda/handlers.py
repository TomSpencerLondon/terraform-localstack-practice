"""
Lambda Handlers for Full Stack Application

This module contains all the Lambda function handlers for our API:
- health_check: Simple health check endpoint
- create_item: Create a new item in DynamoDB
- get_items: List all items from DynamoDB
- get_item: Get a single item by ID
"""

import json
import os
import uuid
from datetime import datetime
import boto3
from botocore.config import Config

# Configure boto3 for LocalStack
# In production, you wouldn't need this - just use boto3.resource('dynamodb')
LOCALSTACK_ENDPOINT = os.environ.get('LOCALSTACK_ENDPOINT', 'http://localhost:4566')

config = Config(
    connect_timeout=5,
    read_timeout=5,
    retries={'max_attempts': 3}
)

# Initialize clients
# For LocalStack, we need to specify the endpoint
# In real AWS, these would just be boto3.resource('dynamodb'), etc.
dynamodb = boto3.resource(
    'dynamodb',
    endpoint_url=LOCALSTACK_ENDPOINT,
    region_name='eu-west-2',
    aws_access_key_id='test',
    aws_secret_access_key='test',
    config=config
)

sns = boto3.client(
    'sns',
    endpoint_url=LOCALSTACK_ENDPOINT,
    region_name='eu-west-2',
    aws_access_key_id='test',
    aws_secret_access_key='test',
    config=config
)


def create_response(status_code: int, body: dict) -> dict:
    """Create a standardized API Gateway response."""
    return {
        'statusCode': status_code,
        'headers': {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Headers': 'Content-Type',
            'Access-Control-Allow-Methods': 'GET, POST, OPTIONS'
        },
        'body': json.dumps(body)
    }


def health_check(event, context):
    """
    Health check endpoint.

    Returns basic service status information.
    """
    return create_response(200, {
        'status': 'healthy',
        'service': 'fullstack-app',
        'timestamp': datetime.utcnow().isoformat(),
        'version': '1.0.0'
    })


def create_item(event, context):
    """
    Create a new item in DynamoDB.

    Expected body:
    {
        "name": "Item Name",
        "description": "Item description"
    }

    Returns the created item with generated ID and timestamps.
    """
    try:
        # Parse request body
        body = json.loads(event.get('body', '{}'))

        # Validate required fields
        if not body.get('name'):
            return create_response(400, {
                'error': 'Missing required field: name'
            })

        # Generate item data
        item_id = str(uuid.uuid4())
        timestamp = datetime.utcnow().isoformat()

        item = {
            'id': item_id,
            'name': body['name'],
            'description': body.get('description', ''),
            'created_at': timestamp,
            'updated_at': timestamp
        }

        # Save to DynamoDB
        table_name = os.environ.get('TABLE_NAME', 'fullstack-app-items')
        table = dynamodb.Table(table_name)
        table.put_item(Item=item)

        # Publish event to SNS
        sns_topic_arn = os.environ.get('SNS_TOPIC_ARN')
        if sns_topic_arn:
            try:
                sns.publish(
                    TopicArn=sns_topic_arn,
                    Message=json.dumps({
                        'event': 'item_created',
                        'item_id': item_id,
                        'name': item['name'],
                        'timestamp': timestamp
                    }),
                    Subject='New Item Created'
                )
            except Exception as e:
                # Don't fail the request if SNS fails
                print(f"SNS publish failed: {e}")

        return create_response(201, {
            'message': 'Item created successfully',
            'item': item
        })

    except json.JSONDecodeError:
        return create_response(400, {
            'error': 'Invalid JSON in request body'
        })
    except Exception as e:
        print(f"Error creating item: {e}")
        return create_response(500, {
            'error': 'Internal server error',
            'message': str(e)
        })


def get_items(event, context):
    """
    List all items from DynamoDB.

    Returns an array of all items, sorted by creation date (newest first).
    """
    try:
        table_name = os.environ.get('TABLE_NAME', 'fullstack-app-items')
        table = dynamodb.Table(table_name)

        # Scan the table (for small datasets - use Query with GSI for larger)
        response = table.scan()
        items = response.get('Items', [])

        # Sort by created_at descending
        items.sort(key=lambda x: x.get('created_at', ''), reverse=True)

        return create_response(200, {
            'count': len(items),
            'items': items
        })

    except Exception as e:
        print(f"Error listing items: {e}")
        return create_response(500, {
            'error': 'Internal server error',
            'message': str(e)
        })


def get_item(event, context):
    """
    Get a single item by ID.

    Path parameter: id

    Returns the item if found, 404 if not.
    """
    try:
        # Get ID from path parameters
        item_id = event.get('pathParameters', {}).get('id')

        if not item_id:
            return create_response(400, {
                'error': 'Missing item ID'
            })

        table_name = os.environ.get('TABLE_NAME', 'fullstack-app-items')
        table = dynamodb.Table(table_name)

        # Get item from DynamoDB
        response = table.get_item(Key={'id': item_id})
        item = response.get('Item')

        if not item:
            return create_response(404, {
                'error': 'Item not found',
                'id': item_id
            })

        return create_response(200, {
            'item': item
        })

    except Exception as e:
        print(f"Error getting item: {e}")
        return create_response(500, {
            'error': 'Internal server error',
            'message': str(e)
        })
