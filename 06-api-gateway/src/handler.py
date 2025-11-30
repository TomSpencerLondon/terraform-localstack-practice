"""
API Gateway + Lambda Handler - Exercise 06

This Lambda handles HTTP requests from API Gateway.
Demonstrates:
- Parsing API Gateway event format
- Routing based on HTTP method and path
- Returning proper API Gateway responses
- Error handling
"""

import json
import logging
import os
from datetime import datetime

logger = logging.getLogger()
logger.setLevel(logging.INFO)

# In-memory "database" for demo purposes
USERS = {
    "user-001": {"id": "user-001", "name": "Tom", "email": "tom@example.com"},
    "user-002": {"id": "user-002", "name": "Jane", "email": "jane@example.com"},
    "user-003": {"id": "user-003", "name": "Bob", "email": "bob@example.com"},
}


def lambda_handler(event, context):
    """
    Main handler - routes requests based on HTTP method and path.
    """
    logger.info(f"Received event: {json.dumps(event)}")

    # Extract request details
    http_method = event.get("httpMethod", "GET")
    path = event.get("path", "/")
    path_params = event.get("pathParameters") or {}
    query_params = event.get("queryStringParameters") or {}
    body = event.get("body")

    # Parse JSON body if present
    if body:
        try:
            body = json.loads(body)
        except json.JSONDecodeError:
            return error_response(400, "Invalid JSON in request body")

    # Route to appropriate handler
    try:
        if path == "/users" and http_method == "GET":
            return get_all_users(query_params)
        elif path == "/users" and http_method == "POST":
            return create_user(body)
        elif path.startswith("/users/") and http_method == "GET":
            user_id = path_params.get("user_id") or path.split("/")[-1]
            return get_user(user_id)
        elif path.startswith("/users/") and http_method == "PUT":
            user_id = path_params.get("user_id") or path.split("/")[-1]
            return update_user(user_id, body)
        elif path.startswith("/users/") and http_method == "DELETE":
            user_id = path_params.get("user_id") or path.split("/")[-1]
            return delete_user(user_id)
        elif path == "/health":
            return health_check()
        else:
            return error_response(404, f"Not found: {http_method} {path}")

    except Exception as e:
        logger.error(f"Error: {str(e)}")
        return error_response(500, str(e))


def get_all_users(query_params):
    """GET /users - List all users"""
    users = list(USERS.values())

    # Optional: filter by name
    name_filter = query_params.get("name")
    if name_filter:
        users = [u for u in users if name_filter.lower() in u["name"].lower()]

    return success_response({"users": users, "count": len(users)})


def get_user(user_id):
    """GET /users/{user_id} - Get single user"""
    if user_id not in USERS:
        return error_response(404, f"User not found: {user_id}")

    return success_response(USERS[user_id])


def create_user(body):
    """POST /users - Create new user"""
    if not body:
        return error_response(400, "Request body required")

    if not body.get("name") or not body.get("email"):
        return error_response(400, "name and email are required")

    # Generate ID
    user_id = f"user-{len(USERS) + 1:03d}"

    user = {
        "id": user_id,
        "name": body["name"],
        "email": body["email"],
        "created_at": datetime.utcnow().isoformat()
    }

    USERS[user_id] = user
    return success_response(user, status_code=201)


def update_user(user_id, body):
    """PUT /users/{user_id} - Update user"""
    if user_id not in USERS:
        return error_response(404, f"User not found: {user_id}")

    if not body:
        return error_response(400, "Request body required")

    user = USERS[user_id]
    if "name" in body:
        user["name"] = body["name"]
    if "email" in body:
        user["email"] = body["email"]

    user["updated_at"] = datetime.utcnow().isoformat()
    return success_response(user)


def delete_user(user_id):
    """DELETE /users/{user_id} - Delete user"""
    if user_id not in USERS:
        return error_response(404, f"User not found: {user_id}")

    del USERS[user_id]
    return success_response({"message": f"User {user_id} deleted"})


def health_check():
    """GET /health - Health check endpoint"""
    return success_response({
        "status": "healthy",
        "timestamp": datetime.utcnow().isoformat(),
        "environment": os.environ.get("ENVIRONMENT", "unknown")
    })


def success_response(data, status_code=200):
    """Build successful API Gateway response"""
    return {
        "statusCode": status_code,
        "headers": {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*"
        },
        "body": json.dumps(data)
    }


def error_response(status_code, message):
    """Build error API Gateway response"""
    return {
        "statusCode": status_code,
        "headers": {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*"
        },
        "body": json.dumps({"error": message})
    }
