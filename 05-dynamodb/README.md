# Exercise 05: DynamoDB

Learn how to create and manage DynamoDB tables with Terraform.

## Concepts Covered

- `aws_dynamodb_table` resource
- Partition keys vs composite keys (partition + sort)
- Billing modes: PAY_PER_REQUEST vs PROVISIONED
- Global Secondary Indexes (GSI)
- Local Secondary Indexes (LSI)
- Time To Live (TTL) for automatic item expiration
- Attribute types: S (String), N (Number), B (Binary)

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      DynamoDB Tables                         │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  users          Simple table, partition key only            │
│  ├── user_id (PK)                                           │
│                                                              │
│  orders         Composite key + GSI                         │
│  ├── user_id (PK)                                           │
│  ├── order_id (SK)                                          │
│  └── GSI: status-index (status + created_at)                │
│                                                              │
│  sessions       With TTL enabled                            │
│  ├── session_id (PK)                                        │
│  └── TTL: expires_at                                        │
│                                                              │
│  products       Provisioned capacity + LSI + GSI            │
│  ├── product_id (PK)                                        │
│  ├── LSI: category-price-index                              │
│  └── GSI: category-index                                    │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

## Key Concepts

### Partition Key vs Composite Key

**Partition Key Only** (users table):
- Single attribute uniquely identifies item
- Example: `user_id = "user-123"`

**Composite Key** (orders table):
- Partition key + Sort key together identify item
- Enables range queries within a partition
- Example: Get all orders for user-123, sorted by order_id

### Billing Modes

| Mode | Use Case | Pricing |
|------|----------|---------|
| PAY_PER_REQUEST | Unpredictable traffic | Pay per read/write |
| PROVISIONED | Predictable traffic | Pay for capacity units |

### Index Types

**Global Secondary Index (GSI)**:
- Different partition key than table
- Eventually consistent
- Has own capacity (if provisioned)
- Example: Query orders by status

**Local Secondary Index (LSI)**:
- Same partition key as table
- Different sort key
- Strongly consistent option
- Must be created with table

### Projection Types

| Type | What's Included |
|------|-----------------|
| ALL | All attributes |
| KEYS_ONLY | Only key attributes |
| INCLUDE | Keys + specified attributes |

## Commands

```bash
# Deploy
./run.sh

# Or manually
terraform init
terraform apply

# List tables
awslocal dynamodb list-tables

# Describe a table
awslocal dynamodb describe-table --table-name learn-dynamodb-dev-users

# Put an item
awslocal dynamodb put-item \
  --table-name learn-dynamodb-dev-users \
  --item '{"user_id": {"S": "user-001"}, "name": {"S": "Tom"}, "email": {"S": "tom@example.com"}}'

# Get an item
awslocal dynamodb get-item \
  --table-name learn-dynamodb-dev-users \
  --key '{"user_id": {"S": "user-001"}}'

# Query orders for a user
awslocal dynamodb query \
  --table-name learn-dynamodb-dev-orders \
  --key-condition-expression "user_id = :uid" \
  --expression-attribute-values '{":uid": {"S": "user-001"}}'

# Scan all items (expensive - avoid in production)
awslocal dynamodb scan --table-name learn-dynamodb-dev-users
```

## DynamoDB Data Types

| Type | Code | Example |
|------|------|---------|
| String | S | `{"S": "hello"}` |
| Number | N | `{"N": "42"}` |
| Binary | B | `{"B": "base64..."}` |
| Boolean | BOOL | `{"BOOL": true}` |
| Null | NULL | `{"NULL": true}` |
| List | L | `{"L": [{"S": "a"}, {"N": "1"}]}` |
| Map | M | `{"M": {"key": {"S": "value"}}}` |
| String Set | SS | `{"SS": ["a", "b", "c"]}` |
| Number Set | NS | `{"NS": ["1", "2", "3"]}` |

## Challenges

1. Add a new GSI to the users table for querying by email
2. Create an item with nested attributes (Map type)
3. Use a conditional write to prevent overwriting existing items
4. Query the orders table using the status-index GSI

## Clean Up

```bash
terraform destroy
```
