# IAM Permissions - Visual Guide

## Policy Simulator Results

We tested what each user can actually do:

| User | Action | Resource | Result | Why |
|------|--------|----------|--------|-----|
| alice | `s3:GetObject` | my-bucket/file.txt | ✅ **allowed** | developer-access grants `s3:*` |
| alice | `s3:DeleteBucket` | my-bucket | ❌ **explicitDeny** | deny-dangerous-actions blocks it |
| charlie | `s3:PutObject` | my-bucket/file.txt | ❌ **implicitDeny** | read-only-access doesn't include Put |
| charlie | `s3:GetObject` | my-bucket/file.txt | ✅ **allowed** | read-only-access grants `s3:Get*` |

### The Three Types of Decisions:

| Decision | Meaning |
|----------|---------|
| `allowed` | A policy explicitly allows this action |
| `explicitDeny` | A policy explicitly DENIES this (overrides any Allow) |
| `implicitDeny` | No policy allows it (default is deny) |

**Key insight:** `Deny` always wins over `Allow`. That's why alice can't delete buckets even though she has `s3:*`.

---

## Complete Permissions Map

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         WHO CAN DO WHAT                                     │
└─────────────────────────────────────────────────────────────────────────────┘

                              S3 PERMISSIONS
┌─────────────────────────────────────────────────────────────────────────────┐
│                                                                             │
│  Action              │ alice      │ bob        │ charlie                   │
│  ────────────────────┼────────────┼────────────┼─────────────────────────  │
│  s3:GetObject        │ ✅ allowed │ ✅ allowed │ ✅ allowed                │
│  s3:ListBucket       │ ✅ allowed │ ✅ allowed │ ✅ allowed                │
│  s3:PutObject        │ ✅ allowed │ ✅ allowed │ ❌ implicitDeny           │
│  s3:DeleteObject     │ ✅ allowed │ ✅ allowed │ ❌ implicitDeny           │
│  s3:CreateBucket     │ ✅ allowed │ ✅ allowed │ ❌ implicitDeny           │
│  s3:DeleteBucket     │ ❌ DENIED  │ ❌ DENIED  │ ❌ implicitDeny           │
│                      │ (explicit) │ (explicit) │                           │
└─────────────────────────────────────────────────────────────────────────────┘

                            DYNAMODB PERMISSIONS
┌─────────────────────────────────────────────────────────────────────────────┐
│                                                                             │
│  Action              │ alice      │ bob        │ charlie                   │
│  ────────────────────┼────────────┼────────────┼─────────────────────────  │
│  dynamodb:GetItem    │ ✅ allowed │ ✅ allowed │ ✅ allowed                │
│  dynamodb:Query      │ ✅ allowed │ ✅ allowed │ ✅ allowed                │
│  dynamodb:Scan       │ ✅ allowed │ ✅ allowed │ ✅ allowed                │
│  dynamodb:PutItem    │ ✅ allowed │ ✅ allowed │ ❌ implicitDeny           │
│  dynamodb:UpdateItem │ ✅ allowed │ ✅ allowed │ ❌ implicitDeny           │
│  dynamodb:DeleteItem │ ✅ allowed │ ✅ allowed │ ❌ implicitDeny           │
│  dynamodb:DeleteTable│ ❌ DENIED  │ ❌ DENIED  │ ❌ implicitDeny           │
│                      │ (explicit) │ (explicit) │                           │
└─────────────────────────────────────────────────────────────────────────────┘

                             LAMBDA PERMISSIONS
┌─────────────────────────────────────────────────────────────────────────────┐
│                                                                             │
│  Action                  │ alice      │ bob        │ charlie               │
│  ────────────────────────┼────────────┼────────────┼─────────────────────  │
│  lambda:GetFunction      │ ✅ allowed │ ✅ allowed │ ✅ allowed            │
│  lambda:ListFunctions    │ ✅ allowed │ ✅ allowed │ ✅ allowed            │
│  lambda:InvokeFunction   │ ✅ allowed │ ✅ allowed │ ❌ implicitDeny       │
│  lambda:CreateFunction   │ ✅ allowed │ ✅ allowed │ ❌ implicitDeny       │
│  lambda:DeleteFunction   │ ✅ allowed │ ✅ allowed │ ❌ implicitDeny       │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## How Policies Stack Up

```
                              ALICE & BOB
                              ───────────

  ┌─────────────────────────────────────────────────────────────┐
  │                    developer-access                          │
  │                                                              │
  │   ✅ s3:*           (all S3 actions)                        │
  │   ✅ lambda:*       (all Lambda actions)                    │
  │   ✅ dynamodb:*     (all DynamoDB actions)                  │
  │   ✅ logs:*         (CloudWatch Logs)                       │
  └─────────────────────────────────────────────────────────────┘
                              +
  ┌─────────────────────────────────────────────────────────────┐
  │                deny-dangerous-actions                        │
  │                                                              │
  │   ❌ s3:DeleteBucket        (DENIED - overrides Allow)      │
  │   ❌ dynamodb:DeleteTable   (DENIED - overrides Allow)      │
  │   ❌ iam:CreateUser         (DENIED - no privilege escalation)│
  │   ❌ iam:DeleteUser         (DENIED)                        ��
  │   ❌ iam:AttachUserPolicy   (DENIED)                        │
  └─────────────────────────────────────────────────────────────┘

  Result: Can do almost everything EXCEPT delete buckets/tables
          or modify IAM (safety guardrails)


                              CHARLIE
                              ───────

  ┌─────────────────────────────────────────────────────────────┐
  │                    read-only-access                          │
  │                                                              │
  │   ✅ s3:Get*        (GetObject, GetBucketPolicy, etc.)      │
  │   ✅ s3:List*       (ListBuckets, ListObjects, etc.)        │
  │   ✅ dynamodb:GetItem, Query, Scan, DescribeTable           │
  │   ✅ lambda:GetFunction, ListFunctions                      │
  │                                                              │
  │   Everything else: ❌ implicitDeny (not granted)            │
  └─────────────────────────────────────────────────────────────┘

  Result: Can only VIEW resources, never modify them
```

---

## Role Permissions (for AWS Services)

```
                         lambda-execution
┌─────────────────────────────────────────────────────────────────────────────┐
│                                                                             │
│  TRUST: lambda.amazonaws.com can assume this role                          │
│                                                                             │
│  PERMISSIONS:                                                               │
│  ┌────────────────────────────────────────────────────────────────────┐    │
│  │  logs:CreateLogGroup      ✅                                       │    │
│  │  logs:CreateLogStream     ✅                                       │    │
│  │  logs:PutLogEvents        ✅                                       │    │
│  │  dynamodb:GetItem         ✅  (only on iam-demo-dev-* tables)      │    │
│  │  dynamodb:PutItem         ✅  (only on iam-demo-dev-* tables)      │    │
│  │  dynamodb:UpdateItem      ✅  (only on iam-demo-dev-* tables)      │    │
│  │  dynamodb:DeleteItem      ✅  (only on iam-demo-dev-* tables)      │    │
│  │  dynamodb:Query           ✅  (only on iam-demo-dev-* tables)      │    │
│  └────────────────────────────────────────────────────────────────────┘    │
│                                                                             │
│  USE CASE: A Lambda function that processes orders and stores in DynamoDB  │
└─────────────────────────────────────────────────────────────────────────────┘

                           api-gateway
┌─────────────────────────────────────────────────────────────────────────────┐
│                                                                             │
│  TRUST: apigateway.amazonaws.com can assume this role                      │
│                                                                             │
│  PERMISSIONS:                                                               │
│  ┌────────────────────────────────────────────────────────────────────┐    │
│  │  lambda:InvokeFunction    ✅  (only on iam-demo-dev-* functions)   │    │
│  └────────────────────────────────────────────────────────────────────┘    │
│                                                                             │
│  USE CASE: API Gateway needs to invoke Lambda when requests come in        │
└─────────────────────────────────────────────────────────────────────────────┘

                           ec2-instance
┌─────────────────────────────────────────────────────────────────────────────┐
│                                                                             │
│  TRUST: ec2.amazonaws.com can assume this role                             │
│                                                                             │
│  PERMISSIONS:                                                               │
│  ┌────────────────────────────────────────────────────────────────────┐    │
│  │  s3:GetObject             ✅  (only on iam-demo-dev-* buckets)     │    │
│  │  s3:ListBucket            ✅  (only on iam-demo-dev-* buckets)     │    │
│  └────────────────────────────────────────────────────────────────────┘    │
│                                                                             │
│  USE CASE: EC2 instance that reads config files from S3                    │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## The Evaluation Logic

When AWS checks "Can alice do s3:DeleteBucket?":

```
Step 1: Gather all policies attached to alice
        └── via group "developers"
            ├── developer-access (allows s3:*)
            └── deny-dangerous-actions (denies s3:DeleteBucket)

Step 2: Check for explicit DENY
        └── Found! deny-dangerous-actions says DENY

Step 3: DENY wins. Access denied.

┌─────────────────────────────────────────────────────────────────────────────┐
│                     IAM EVALUATION ORDER                                    │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   1. Explicit DENY?  ───► YES ───► ❌ DENIED (stop here)                   │
│          │                                                                  │
│          NO                                                                 │
│          ▼                                                                  │
│   2. Explicit ALLOW? ───► YES ───► ✅ ALLOWED                              │
│          │                                                                  │
│          NO                                                                 │
│          ▼                                                                  │
│   3. Default         ───────────► ❌ DENIED (implicit)                     │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘

DENY always wins. No Allow can override a Deny.
```

---

## Try It Yourself

```bash
# Can alice read from S3?
awslocal iam simulate-principal-policy \
  --policy-source-arn arn:aws:iam::000000000000:user/alice \
  --action-names s3:GetObject \
  --resource-arns arn:aws:s3:::my-bucket/file.txt

# Can alice delete a bucket? (should be denied)
awslocal iam simulate-principal-policy \
  --policy-source-arn arn:aws:iam::000000000000:user/alice \
  --action-names s3:DeleteBucket \
  --resource-arns arn:aws:s3:::my-bucket

# Can charlie write to DynamoDB? (should be implicitDeny)
awslocal iam simulate-principal-policy \
  --policy-source-arn arn:aws:iam::000000000000:user/charlie \
  --action-names dynamodb:PutItem \
  --resource-arns arn:aws:dynamodb:us-east-1:000000000000:table/orders

# Can bob invoke a Lambda function?
awslocal iam simulate-principal-policy \
  --policy-source-arn arn:aws:iam::000000000000:user/bob \
  --action-names lambda:InvokeFunction \
  --resource-arns arn:aws:lambda:us-east-1:000000000000:function:my-function
```
