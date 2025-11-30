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

## The 4 Tables Explained

We create 4 different tables to demonstrate different DynamoDB patterns:

### Table 1: `users` - Simple Partition Key

```
┌─────────────────────────────────────────────────────────────┐
│  users table                                                 │
├─────────────────────────────────────────────────────────────┤
│  user_id (PK)  │  name      │  email                        │
├────────────────┼────────────┼───────────────────────────────┤
│  user-001      │  Tom       │  tom@example.com              │
│  user-002      │  Jane      │  jane@example.com             │
└────────────────┴────────────┴───────────────────────────────┘
```

**Key Structure:** `hash_key = "user_id"` (partition key only)

**Use Case:** Simple entity lookup by unique ID

**Access Patterns:**
- ✅ Get user by ID: `{ user_id: "user-001" }`
- ❌ Cannot query by email (would need a GSI)
- ❌ Cannot get "all users" efficiently (requires full table scan)

**When to use this pattern:**
- Each item has a unique identifier
- You always know the ID when querying
- Examples: user profiles, product details, configuration items

---

### Table 2: `orders` - Composite Key + GSI

```
┌──────────────────────────────────────────────────────────────────────────────┐
│  orders table                                                                 │
├──────────────────────────────────────────────────────────────────────────────┤
│  user_id (PK)  │  order_id (SK)  │  status   │  created_at         │  total  │
├────────────────┼─────────────────┼───────────┼─────────────────────┼─────────┤
│  user-001      │  order-001      │  pending  │  2024-01-15T10:00Z  │  99.99  │
│  user-001      │  order-002      │  shipped  │  2024-01-16T14:30Z  │  149.50 │
│  user-002      │  order-003      │  pending  │  2024-01-17T09:00Z  │  75.00  │
└────────────────┴─────────────────┴───────────┴─────────────────────┴─────────┘

GSI: status-index (status = PK, created_at = SK)
┌──────────────────────────────────────────────────────────────────────────────┐
│  status (PK)  │  created_at (SK)      │  user_id   │  order_id    │  ...     │
├───────────────┼───────────────────────┼────────────┼──────────────┼──────────┤
│  pending      │  2024-01-15T10:00Z    │  user-001  │  order-001   │  ...     │
│  pending      │  2024-01-17T09:00Z    │  user-002  │  order-003   │  ...     │
│  shipped      │  2024-01-16T14:30Z    │  user-001  │  order-002   │  ...     │
└───────────────┴───────────────────────┴────────────┴──────────────┴──────────┘
```

**Key Structure:**
- `hash_key = "user_id"` (partition key)
- `range_key = "order_id"` (sort key)

**Use Case:** One-to-many relationships with multiple access patterns

**Access Patterns:**
- ✅ Get specific order: `{ user_id: "user-001", order_id: "order-001" }`
- ✅ Get ALL orders for a user: `{ user_id: "user-001" }` (returns all order_ids)
- ✅ Get orders in range: `{ user_id: "user-001", order_id BETWEEN "order-001" AND "order-005" }`
- ✅ Via GSI: Get all pending orders across ALL users (sorted by date)

**Why the GSI?**
Without the GSI, you can only query orders if you know the user_id. The `status-index` GSI lets you query by status across all users - useful for admin dashboards, background jobs, etc.

**When to use this pattern:**
- Parent-child relationships (user → orders, customer → invoices)
- Need to query children by parent AND by some other attribute
- Examples: orders per customer, posts per user, events per device

---

### Table 3: `sessions` - TTL for Auto-Expiration

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  sessions table                                                              │
├─────────────────────────────────────────────────────────────────────────────┤
│  session_id (PK)          │  user_id   │  data        │  expires_at (TTL)   │
├───────────────────────────┼────────────┼──────────────┼─────────────────────┤
│  sess-abc123              │  user-001  │  {...}       │  1705420800         │
│  sess-def456              │  user-002  │  {...}       │  1705507200         │
└───────────────────────────┴────────────┴──────────────┴─────────────────────┘
                                                              ↑
                                                    Unix timestamp (seconds)
                                                    When this time passes,
                                                    DynamoDB deletes the item
```

**Key Structure:** `hash_key = "session_id"` (partition key only)

**Special Feature:** TTL enabled on `expires_at` attribute

**How TTL Works:**
1. You store a Unix timestamp in the `expires_at` attribute
2. DynamoDB automatically deletes items when current time > expires_at
3. Deletion happens within 48 hours of expiry (not instant, but free)

**Use Case:** Temporary data that should auto-cleanup

**Access Patterns:**
- ✅ Get session by ID: `{ session_id: "sess-abc123" }`
- ✅ Automatic cleanup: No need to run batch delete jobs

**When to use this pattern:**
- Session tokens, authentication tokens
- Cache entries
- Temporary locks
- Event logs with retention policy
- Any data with a natural expiration

---

### Table 4: `products` - Provisioned + LSI + GSI

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  products table                                                              │
├─────────────────────────────────────────────────────────────────────────────┤
│  product_id (PK)  │  category (SK)   │  name     │  price   │  description  │
├───────────────────┼──────────────────┼───────────┼──────────┼───────────────┤
│  prod-001         │  Electronics     │  Laptop   │  999.99  │  ...          │
│  prod-001         │  Computers       │  Laptop   │  999.99  │  ...          │
│  prod-002         │  Electronics     │  Phone    │  599.99  │  ...          │
└───────────────────┴──────────────────┴───────────┴──────────┴───────────────┘

LSI: price-index (same PK: product_id, different SK: price)
- Query products sorted by price within same product_id

GSI: category-index (category = PK, price = SK)
- Query all products in a category, sorted by price
```

**Key Structure:**
- `hash_key = "product_id"` (partition key)
- `range_key = "category"` (sort key)
- `billing_mode = "PROVISIONED"` with explicit capacity

**Special Features:**
1. **Provisioned capacity** - You specify read/write units upfront
2. **LSI** - Same partition key, different sort key
3. **GSI** - Completely different partition key

**LSI vs GSI Comparison:**

| Feature | LSI (price-index) | GSI (category-index) |
|---------|-------------------|----------------------|
| Partition key | Same as table (product_id) | Different (category) |
| Created | Must be at table creation | Can add anytime |
| Consistency | Can be strongly consistent | Eventually consistent only |
| Capacity | Shares with table | Has own capacity |
| Use case | Alternate sort within partition | Completely different access pattern |

**Access Patterns:**
- ✅ Get product in category: `{ product_id: "prod-001", category: "Electronics" }`
- ✅ Via LSI: Get product sorted by price: `{ product_id: "prod-001" }` ordered by price
- ✅ Via GSI: Get all Electronics sorted by price (across all product_ids)

**Provisioned vs On-Demand:**

| Aspect | PAY_PER_REQUEST (tables 1-3) | PROVISIONED (table 4) |
|--------|------------------------------|----------------------|
| Capacity | Auto-scales | You specify RCU/WCU |
| Cost | Pay per request | Pay for capacity |
| Throttling | Rare | If you exceed capacity |
| Best for | Variable/unknown traffic | Predictable traffic |

**When to use this pattern:**
- Need multiple ways to query the same data
- Have predictable, steady traffic (provisioned)
- Product catalogs, inventory systems

---

## Summary: Choosing the Right Pattern

| Pattern | Table | When to Use |
|---------|-------|-------------|
| Simple PK | users | Unique items, lookup by ID |
| Composite Key | orders | One-to-many, range queries |
| Composite + GSI | orders | Multiple access patterns |
| TTL | sessions | Auto-expiring data |
| LSI | products | Alternate sort within partition |
| Provisioned | products | Predictable, cost-optimized traffic |

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
