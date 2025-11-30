# Exercise 08: IAM Deep Dive

Learn AWS Identity and Access Management (IAM) - the foundation of AWS security.

## Concepts Covered

- `aws_iam_user` - Human users
- `aws_iam_group` - Group users together
- `aws_iam_role` - For services/applications to assume
- `aws_iam_policy` - JSON permission documents
- `aws_iam_policy_document` (data source) - Build policies in Terraform
- `aws_iam_role_policy_attachment` - Attach policies to roles
- `aws_iam_user_policy_attachment` - Attach policies to users
- Trust policies (who can assume a role)
- Permission policies (what they can do)

## The IAM Mental Model

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           IAM HIERARCHY                                     │
└─────────────────────────────────────────────────────────────────────────────┘

  WHO (Principals)                    WHAT (Policies)
  ─────────────────                   ─────────────────

  ┌─────────────┐                     ┌─────────────────────────────────┐
  │    User     │ ◄── Human           │  Policy = JSON document         │
  │  (alice)    │                     │                                 │
  └──────┬──────┘                     │  {                              │
         │                            │    "Effect": "Allow",           │
         ▼                            │    "Action": "s3:GetObject",    │
  ┌─────────────┐                     │    "Resource": "arn:aws:s3:::*" │
  │   Group     │ ◄── Collection      │  }                              │
  │ (developers)│     of users        │                                 │
  └─────────────┘                     └─────────────────────────────────┘

  ┌─────────────┐                     Policies can be attached to:
  │    Role     │ ◄── For services    • Users (directly)
  │  (lambda)   │     to assume       • Groups (all members inherit)
  └─────────────┘                     • Roles (assumed by services)
```

## Users vs Roles

| | User | Role |
|---|---|---|
| **Who uses it** | Humans (with passwords/keys) | Services (Lambda, EC2, etc.) |
| **Authentication** | Password or Access Keys | Assumed via trust policy |
| **Lifespan** | Permanent until deleted | Temporary credentials |
| **Example** | Developer logging into console | Lambda accessing DynamoDB |

## The Two Types of Policies

### 1. Trust Policy (Who can assume this role?)

```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {
      "Service": "lambda.amazonaws.com"
    },
    "Action": "sts:AssumeRole"
  }]
}
```

This says: "Lambda service can assume this role"

### 2. Permission Policy (What can they do?)

```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": [
      "dynamodb:GetItem",
      "dynamodb:PutItem"
    ],
    "Resource": "arn:aws:dynamodb:*:*:table/orders"
  }]
}
```

This says: "Can read/write to the orders DynamoDB table"

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        WHAT WE'LL BUILD                                     │
└─────────────────────────────────────────────────────────────────────────────┘

  USERS & GROUPS                      ROLES FOR SERVICES
  ──────────────                      ──────────────────

  ┌─────────────┐                     ┌─────────────────────────────────┐
  │ Group:      │                     │ Role: lambda-execution          │
  │ developers  │                     │                                 │
  │             │                     │ Trust: lambda.amazonaws.com     │
  │ ┌─────────┐ │                     │ Permissions:                    │
  │ │  alice  │ │                     │   - logs:CreateLogGroup         │
  │ └─────────┘ │                     │   - logs:PutLogEvents           │
  │ ┌─────────┐ │                     │   - dynamodb:GetItem            │
  │ │   bob   │ │                     │   - dynamodb:PutItem            │
  │ └─────────┘ │                     └─────────────────────────────────┘
  └──────┬──────┘
         │                            ┌─────────────────────────────────┐
         ▼                            │ Role: api-gateway               │
  ┌─────────────────┐                 │                                 │
  │ Policy:         │                 │ Trust: apigateway.amazonaws.com │
  │ developer-access│                 │ Permissions:                    │
  │                 │                 │   - lambda:InvokeFunction       │
  │ - s3:*          │                 └─────────────────────────────────┘
  │ - lambda:*      │
  │ - dynamodb:*    │                 ┌─────────────────────────────────┐
  └─────────────────┘                 │ Role: ec2-instance              │
                                      │                                 │
  ┌─────────────┐                     │ Trust: ec2.amazonaws.com        │
  │ Group:      │                     │ Permissions:                    │
  │ read-only   │                     │   - s3:GetObject                │
  │             │                     │   - s3:ListBucket               │
  │ ┌─────────┐ │                     └─────────────────────────────────┘
  │ │ charlie │ │
  │ └─────────┘ │
  └──────┬──────┘
         │
         ▼
  ┌─────────────────┐
  │ Policy:         │
  │ read-only-access│
  │                 │
  │ - s3:Get*       │
  │ - s3:List*      │
  │ - dynamodb:Get* │
  │ - dynamodb:Scan │
  └─────────────────┘
```

## Policy Anatomy

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        IAM POLICY STRUCTURE                                 │
└─────────────────────────────────────────────────────────────────────────────┘

{
  "Version": "2012-10-17",        ← Always this value
  "Statement": [
    {
      "Sid": "AllowS3Read",       ← Optional: Statement ID (for humans)
      "Effect": "Allow",          ← Allow or Deny
      "Action": [                 ← What operations
        "s3:GetObject",
        "s3:ListBucket"
      ],
      "Resource": [               ← On what resources
        "arn:aws:s3:::my-bucket",
        "arn:aws:s3:::my-bucket/*"
      ],
      "Condition": {              ← Optional: When this applies
        "StringEquals": {
          "aws:RequestedRegion": "us-east-1"
        }
      }
    }
  ]
}
```

## Common Policy Patterns

### 1. Allow Everything (Admin - DANGEROUS!)
```json
{
  "Effect": "Allow",
  "Action": "*",
  "Resource": "*"
}
```

### 2. Read-Only S3
```json
{
  "Effect": "Allow",
  "Action": ["s3:Get*", "s3:List*"],
  "Resource": "*"
}
```

### 3. Specific Table Access
```json
{
  "Effect": "Allow",
  "Action": ["dynamodb:GetItem", "dynamodb:PutItem"],
  "Resource": "arn:aws:dynamodb:us-east-1:*:table/orders"
}
```

### 4. Deny Specific Actions
```json
{
  "Effect": "Deny",
  "Action": ["s3:DeleteBucket"],
  "Resource": "*"
}
```

## Principle of Least Privilege

**ALWAYS give the minimum permissions needed.**

Bad:
```json
{"Effect": "Allow", "Action": "s3:*", "Resource": "*"}
```

Good:
```json
{
  "Effect": "Allow",
  "Action": ["s3:GetObject"],
  "Resource": "arn:aws:s3:::my-app-bucket/*"
}
```

## Commands

```bash
# Deploy
./run.sh

# Or manually
terraform init
terraform apply

# List users
awslocal iam list-users

# List roles
awslocal iam list-roles

# List policies attached to a role
awslocal iam list-attached-role-policies --role-name <role-name>

# Get policy document
awslocal iam get-policy --policy-arn <policy-arn>
awslocal iam get-policy-version --policy-arn <policy-arn> --version-id v1

# Simulate policy (does this user have permission?)
awslocal iam simulate-principal-policy \
  --policy-source-arn arn:aws:iam::000000000000:user/alice \
  --action-names s3:GetObject \
  --resource-arns arn:aws:s3:::my-bucket/file.txt
```

## Real AWS vs LocalStack

| Feature | Real AWS | LocalStack |
|---------|----------|------------|
| IAM Users | Yes | Yes |
| IAM Roles | Yes | Yes |
| IAM Policies | Yes | Yes |
| Policy simulation | Yes | Partial |
| Access Analyzer | Yes | No |
| Permission boundaries | Yes | No |

## Challenges

1. Add a new group "admins" with full access
2. Create a policy that denies deleting S3 buckets
3. Add a condition to restrict access to a specific region
4. Create an assume-role policy for cross-account access

## Clean Up

```bash
terraform destroy
```
