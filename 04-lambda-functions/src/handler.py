"""
Lambda Handler - Exercise 04

This is a simple Lambda function that demonstrates:
- Handling events
- Returning responses
- Using environment variables
- Basic logging
"""

import json
import os
import logging

# Configure logging
logger = logging.getLogger()
log_level = os.environ.get('LOG_LEVEL', 'INFO')
logger.setLevel(getattr(logging, log_level))


def lambda_handler(event, context):
    """
    Main Lambda handler function.

    Args:
        event: The event data passed to the function
        context: Runtime information about the function

    Returns:
        dict: API Gateway compatible response
    """
    logger.info(f"Received event: {json.dumps(event)}")

    # Get environment info
    environment = os.environ.get('ENVIRONMENT', 'unknown')
    function_name = context.function_name if context else 'local'

    # Extract name from event (supports multiple input formats)
    name = event.get('name') or \
           event.get('queryStringParameters', {}).get('name') or \
           'World'

    # Build response
    message = f"Hello, {name}! Welcome to Lambda."

    response_body = {
        'message': message,
        'environment': environment,
        'function': function_name,
        'event_keys': list(event.keys()) if event else []
    }

    logger.info(f"Returning response: {json.dumps(response_body)}")

    # Return API Gateway compatible response
    return {
        'statusCode': 200,
        'headers': {
            'Content-Type': 'application/json'
        },
        'body': json.dumps(response_body)
    }
