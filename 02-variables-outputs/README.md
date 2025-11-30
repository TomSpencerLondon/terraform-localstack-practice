# Exercise 02: Variables & Outputs

Deep dive into Terraform variables, outputs, and creating multiple resources.

## Learning Objectives

- Master all variable types: `string`, `number`, `bool`, `list`, `map`, `object`
- Use `locals` for computed values
- Create multiple resources using `count` and `for_each`
- Chain resources together using references
- Use `terraform.tfvars` files for environment-specific configuration

## Key Concepts

### Variable Types

| Type | Example | Use Case |
|------|---------|----------|
| `string` | `"hello"` | Names, IDs, single values |
| `number` | `42` | Counts, sizes, ports |
| `bool` | `true` | Feature flags, toggles |
| `list(T)` | `["a", "b", "c"]` | Multiple values of same type |
| `map(T)` | `{key = "value"}` | Key-value lookups |
| `object({})` | `{name = "x", size = 10}` | Structured configuration |

### Locals vs Variables

```hcl
# Variables - INPUT from outside
variable "environment" {
  default = "dev"
}

# Locals - COMPUTED inside your config
locals {
  bucket_prefix = "myapp-${var.environment}"
}
```

**Rule of thumb:**
- Use **variables** for things users should configure
- Use **locals** for things computed from other values

### count vs for_each

```hcl
# count - create N identical resources
resource "aws_s3_bucket" "buckets" {
  count  = 3
  bucket = "bucket-${count.index}"
}

# for_each - create resources from a map/set
resource "aws_s3_bucket" "named_buckets" {
  for_each = toset(["logs", "data", "backup"])
  bucket   = "myapp-${each.key}"
}
```

**When to use which:**
- `count` - when resources are numbered/identical
- `for_each` - when resources have unique names/configurations

## Instructions

### Step 1: Review the code structure

```
02-variables-outputs/
├── main.tf           # Provider and resources
├── variables.tf      # All input variables
├── outputs.tf        # All outputs
├── locals.tf         # Computed local values
└── terraform.tfvars  # Your variable values
```

### Step 2: Initialize and apply

```bash
cd 02-variables-outputs
terraform init
terraform plan
terraform apply
```

### Step 3: Experiment with variables

```bash
# Override via command line
terraform apply -var="environment=prod"

# Override via environment variable
export TF_VAR_environment="staging"
terraform apply
```

### Step 4: Query outputs

```bash
# Show all outputs
terraform output

# Show specific output
terraform output bucket_names

# Get output as JSON (useful for scripts)
terraform output -json
```

### Step 5: Clean up

```bash
terraform destroy
```

## Code Walkthrough

### Variable Types in Detail

#### String with validation
```hcl
variable "environment" {
  type        = string
  description = "Deployment environment"
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}
```

#### List of strings
```hcl
variable "bucket_names" {
  type        = list(string)
  description = "List of bucket names to create"
  default     = ["logs", "data", "backup"]
}
```

#### Map for tags
```hcl
variable "common_tags" {
  type = map(string)
  default = {
    Project   = "terraform-learning"
    ManagedBy = "terraform"
  }
}
```

#### Object for complex config
```hcl
variable "bucket_config" {
  type = object({
    name       = string
    versioning = bool
    tags       = map(string)
  })
  default = {
    name       = "my-bucket"
    versioning = true
    tags       = { Environment = "dev" }
  }
}
```

### Using for_each with a map

```hcl
variable "buckets" {
  type = map(object({
    versioning = bool
  }))
  default = {
    logs   = { versioning = false }
    data   = { versioning = true }
    backup = { versioning = true }
  }
}

resource "aws_s3_bucket" "buckets" {
  for_each = var.buckets
  bucket   = "${local.prefix}-${each.key}"
}

resource "aws_s3_bucket_versioning" "buckets" {
  for_each = { for k, v in var.buckets : k => v if v.versioning }
  bucket   = aws_s3_bucket.buckets[each.key].id

  versioning_configuration {
    status = "Enabled"
  }
}
```

### Output Expressions

```hcl
# Simple value
output "bucket_count" {
  value = length(aws_s3_bucket.buckets)
}

# List of values
output "bucket_names" {
  value = [for b in aws_s3_bucket.buckets : b.id]
}

# Map of values
output "bucket_arns" {
  value = { for k, b in aws_s3_bucket.buckets : k => b.arn }
}
```

## Challenges

1. **Add a new bucket type** - Add "archive" to the buckets map with versioning disabled
2. **Conditional resource** - Only create a "prod-backup" bucket when environment is "prod"
3. **Dynamic tags** - Add the environment name to all bucket tags automatically
4. **Output filtering** - Create an output that only shows buckets with versioning enabled

## Common Patterns

### Environment-specific configuration

```hcl
# terraform.tfvars (for dev)
environment = "dev"
bucket_names = ["logs", "data"]

# prod.tfvars (for production)
environment = "prod"
bucket_names = ["logs", "data", "backup", "archive"]

# Usage:
terraform apply -var-file="prod.tfvars"
```

### Merging tags

```hcl
locals {
  default_tags = {
    ManagedBy   = "terraform"
    Environment = var.environment
  }
}

resource "aws_s3_bucket" "example" {
  bucket = "example"
  tags   = merge(local.default_tags, var.extra_tags)
}
```

## Shell Gotcha: Quoting in zsh

When using `terraform state show` with `for_each` resources, you need to quote properly in zsh:

```bash
# This FAILS in zsh (brackets are interpreted as glob patterns)
terraform state show aws_s3_bucket.buckets["logs"]
# zsh: no matches found: aws_s3_bucket.buckets[logs]

# This WORKS - wrap entire address in single quotes
terraform state show 'aws_s3_bucket.buckets["logs"]'

# Alternative - escape everything
terraform state show aws_s3_bucket.buckets\[\"logs\"\]
```

**Why?** zsh treats `[` and `]` as glob pattern characters. Single quotes prevent all interpretation.

This applies to any Terraform command with bracketed resource addresses:
```bash
terraform state show 'aws_s3_bucket.counted_buckets[0]'
terraform taint 'aws_s3_bucket.buckets["data"]'
terraform import 'aws_s3_bucket.buckets["logs"]' my-bucket
```

## Next Steps

Once comfortable, move to [Exercise 03: S3 Static Website](../03-s3-static-website/)
