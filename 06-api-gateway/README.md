# Exercise 06: API Gateway + Lambda

Build a REST API with HTTP endpoints backed by Lambda functions.

## Concepts Covered

- `aws_api_gateway_rest_api` - Create a REST API
- `aws_api_gateway_resource` - Define URL paths
- `aws_api_gateway_method` - Define HTTP methods (GET, POST, etc.)
- `aws_api_gateway_integration` - Connect methods to Lambda
- `aws_api_gateway_deployment` - Deploy the API
- `aws_api_gateway_stage` - Create environments (dev, prod)
- `aws_lambda_permission` - Allow API Gateway to invoke Lambda
- Lambda proxy integration (AWS_PROXY)

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              API Gateway                                     │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  GET    /health           ──┐                                               │
│  GET    /users            ──┼──►  Lambda Function  ──►  Response            │
│  POST   /users            ──┤     (handler.py)                              │
│  GET    /users/{user_id}  ──┤                                               │
│  PUT    /users/{user_id}  ──┤     Routes by:                                │
│  DELETE /users/{user_id}  ──┘     - httpMethod                              │
│                                    - path                                    │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

## How API Gateway Works

### 1. REST API
The container for your entire API:
```hcl
resource "aws_api_gateway_rest_api" "api" {
  name = "users-api"
}
```

### 2. Resources (URL Paths)
Each path segment is a "resource":
```
/users          → aws_api_gateway_resource.users
/users/{id}     → aws_api_gateway_resource.user (child of users)
/health         → aws_api_gateway_resource.health
```

```hcl
resource "aws_api_gateway_resource" "users" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id  # /
  path_part   = "users"  # Creates /users
}

resource "aws_api_gateway_resource" "user" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_resource.users.id  # /users
  path_part   = "{user_id}"  # Creates /users/{user_id}
}
```

### 3. Methods (HTTP Verbs)
Define what HTTP methods are allowed on each resource:
```hcl
resource "aws_api_gateway_method" "get_users" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.users.id
  http_method   = "GET"
  authorization = "NONE"  # Or "AWS_IAM", "COGNITO", "CUSTOM"
}
```

### 4. Integration (Connect to Lambda)
Link the method to a backend (Lambda, HTTP, Mock):
```hcl
resource "aws_api_gateway_integration" "get_users" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_resource.users.id
  http_method             = aws_api_gateway_method.get_users.http_method
  integration_http_method = "POST"  # Always POST for Lambda
  type                    = "AWS_PROXY"  # Lambda proxy integration
  uri                     = aws_lambda_function.handler.invoke_arn
}
```

### 5. Lambda Permission
API Gateway needs permission to invoke Lambda:
```hcl
resource "aws_lambda_permission" "api_gateway" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.handler.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.api.execution_arn}/*/*"
}
```

### 6. Deployment & Stage
Deploy the API to a stage (like "dev" or "prod"):
```hcl
resource "aws_api_gateway_deployment" "api" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  # triggers force redeployment when config changes
}

resource "aws_api_gateway_stage" "dev" {
  deployment_id = aws_api_gateway_deployment.api.id
  rest_api_id   = aws_api_gateway_rest_api.api.id
  stage_name    = "dev"
}
```

## Lambda Proxy Integration

With `type = "AWS_PROXY"`, API Gateway passes the entire request to Lambda:

```json
{
  "httpMethod": "GET",
  "path": "/users/user-001",
  "pathParameters": { "user_id": "user-001" },
  "queryStringParameters": { "name": "tom" },
  "headers": { "Content-Type": "application/json" },
  "body": "{\"name\": \"Tom\"}"
}
```

Lambda must return this format:
```json
{
  "statusCode": 200,
  "headers": { "Content-Type": "application/json" },
  "body": "{\"id\": \"user-001\", \"name\": \"Tom\"}"
}
```

## Commands

```bash
# Deploy
./run.sh

# Or manually
terraform init
terraform apply

# Get the API URL from outputs
API_URL=$(terraform output -raw localstack_api_url)

# Test endpoints
curl $API_URL/health
curl $API_URL/users
curl $API_URL/users/user-001

# Create a user
curl -X POST $API_URL/users \
  -H "Content-Type: application/json" \
  -d '{"name": "Alice", "email": "alice@example.com"}'

# Update a user
curl -X PUT $API_URL/users/user-001 \
  -H "Content-Type: application/json" \
  -d '{"name": "Tom Spencer"}'

# Delete a user
curl -X DELETE $API_URL/users/user-003
```

## API Endpoints

| Method | Path | Description |
|--------|------|-------------|
| GET | /health | Health check |
| GET | /users | List all users |
| POST | /users | Create a user |
| GET | /users/{user_id} | Get a user |
| PUT | /users/{user_id} | Update a user |
| DELETE | /users/{user_id} | Delete a user |

## Resource Count

This exercise creates many resources because API Gateway is verbose:

| Resource Type | Count | Purpose |
|---------------|-------|---------|
| REST API | 1 | The API itself |
| Resources | 3 | /users, /users/{id}, /health |
| Methods | 6 | GET, POST, PUT, DELETE on resources |
| Integrations | 6 | Connect each method to Lambda |
| Lambda | 1 | Single handler for all routes |
| Permission | 1 | Allow API Gateway → Lambda |
| Deployment | 1 | Deploy the API |
| Stage | 1 | "dev" environment |

**Total: ~20 resources** for a simple CRUD API!

## Real AWS vs LocalStack

| Aspect | Real AWS | LocalStack |
|--------|----------|------------|
| URL format | `https://{api-id}.execute-api.{region}.amazonaws.com/{stage}` | `http://localhost:4566/restapis/{api-id}/{stage}/_user_request_` |
| Custom domains | Yes | Limited |
| API Keys | Yes | Yes |
| Throttling | Yes | No |

## Challenges

1. Add query parameter filtering (e.g., `GET /users?name=tom`)
2. Add input validation in Lambda
3. Add a `/users/{user_id}/orders` nested resource
4. Add API key authentication

## Clean Up

```bash
terraform destroy
```
