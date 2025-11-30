# ============================================================
# OUTPUTS
# ============================================================

output "users_table" {
  description = "Users table details"
  value = {
    name = aws_dynamodb_table.users.name
    arn  = aws_dynamodb_table.users.arn
    key  = "user_id (partition key only)"
  }
}

output "orders_table" {
  description = "Orders table details"
  value = {
    name      = aws_dynamodb_table.orders.name
    arn       = aws_dynamodb_table.orders.arn
    key       = "user_id (partition) + order_id (sort)"
    gsi       = "status-index"
  }
}

output "sessions_table" {
  description = "Sessions table details"
  value = {
    name     = aws_dynamodb_table.sessions.name
    arn      = aws_dynamodb_table.sessions.arn
    ttl      = "expires_at"
  }
}

output "products_table" {
  description = "Products table details"
  value = {
    name           = aws_dynamodb_table.products.name
    arn            = aws_dynamodb_table.products.arn
    key            = "product_id (PK) + category (SK)"
    billing        = "PROVISIONED (5 RCU / 5 WCU)"
    gsi            = "category-index"
    lsi            = "price-index"
  }
}

output "all_table_names" {
  description = "List of all table names"
  value = [
    aws_dynamodb_table.users.name,
    aws_dynamodb_table.orders.name,
    aws_dynamodb_table.sessions.name,
    aws_dynamodb_table.products.name,
  ]
}
