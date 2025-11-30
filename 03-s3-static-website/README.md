# Exercise 03: S3 Static Website

Host a static website on S3 using Terraform and view it in your browser via LocalStack.

## Learning Objectives

- Configure S3 bucket for static website hosting
- Set bucket policies for public access
- Upload files to S3 using Terraform
- Use `templatefile()` for dynamic content
- Understand S3 website endpoints

## Key Concepts

### S3 Static Website Hosting

S3 can serve static files (HTML, CSS, JS, images) as a website. You need:

1. **Bucket** - to store the files
2. **Website configuration** - index document, error document
3. **Public access settings** - allow public reads
4. **Bucket policy** - grant read access to everyone
5. **Files** - your HTML, CSS, etc.

### Resources We'll Create

```
┌─────────────────────────────────────────────────────────────┐
│                     S3 Static Website                        │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  aws_s3_bucket                    The bucket itself          │
│       │                                                      │
│       ├── aws_s3_bucket_website_configuration               │
│       │        Index: index.html                            │
│       │        Error: error.html                            │
│       │                                                      │
│       ├── aws_s3_bucket_public_access_block                 │
│       │        Allow public access                          │
│       │                                                      │
│       ├── aws_s3_bucket_policy                              │
│       │        Grant s3:GetObject to everyone               │
│       │                                                      │
│       └── aws_s3_object (multiple)                          │
│                index.html                                    │
│                error.html                                    │
│                styles.css                                    │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### The `templatefile()` Function

Terraform can inject variables into your HTML files:

```hcl
content = templatefile("website/index.html", {
  site_name   = var.site_name
  environment = var.environment
})
```

In `index.html`:
```html
<h1>Welcome to ${site_name}</h1>
<p>Environment: ${environment}</p>
```

## Instructions

### Step 1: Review the files

```
03-s3-static-website/
├── main.tf              # S3 bucket and configuration
├── variables.tf         # Input variables
├── outputs.tf           # Website URL outputs
└── website/
    ├── index.html       # Home page template
    ├── error.html       # 404 error page
    └── styles.css       # Stylesheet
```

### Step 2: Deploy the website

```bash
cd 03-s3-static-website
terraform init
terraform apply
```

### Step 3: View your website

After apply, Terraform will output the website URL. Open it in your browser:

```bash
# The URL will be shown in outputs, something like:
curl http://localhost:4566/my-website-dev/index.html

# Or open in browser
open "http://localhost:4566/my-website-dev/index.html"
```

### Step 4: Modify and redeploy

Try changing `variables.tf` or the HTML files, then:

```bash
terraform apply
```

Watch how Terraform detects and applies only the changes.

### Step 5: Clean up

```bash
terraform destroy
```

## Code Walkthrough

### Website Configuration

```hcl
resource "aws_s3_bucket_website_configuration" "website" {
  bucket = aws_s3_bucket.website.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "error.html"
  }
}
```

This tells S3:
- When someone visits `/`, serve `index.html`
- When a file is not found, serve `error.html`

### Public Access Block

```hcl
resource "aws_s3_bucket_public_access_block" "website" {
  bucket = aws_s3_bucket.website.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}
```

By default, S3 blocks public access. We disable these blocks for a public website.

### Bucket Policy

```hcl
resource "aws_s3_bucket_policy" "website" {
  bucket = aws_s3_bucket.website.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.website.arn}/*"
      }
    ]
  })
}
```

This IAM policy allows anyone (`Principal = "*"`) to read objects from the bucket.

### Uploading Files

```hcl
resource "aws_s3_object" "index" {
  bucket       = aws_s3_bucket.website.id
  key          = "index.html"
  content      = templatefile("website/index.html", {
    site_name   = var.site_name
    environment = var.environment
  })
  content_type = "text/html"
}
```

- `key` - the file path in S3
- `content` - file contents (can use `templatefile()` for dynamic content)
- `content_type` - MIME type (important for browsers)

## Content Types

| File Extension | Content Type |
|----------------|--------------|
| `.html` | `text/html` |
| `.css` | `text/css` |
| `.js` | `application/javascript` |
| `.json` | `application/json` |
| `.png` | `image/png` |
| `.jpg` | `image/jpeg` |
| `.svg` | `image/svg+xml` |

## Challenges

1. **Add a new page** - Create `about.html` and upload it
2. **Add JavaScript** - Create a `script.js` file that adds interactivity
3. **Dynamic content** - Pass more variables to `templatefile()` and display them
4. **Multiple environments** - Deploy with `-var="environment=prod"` and see the change

## Real AWS vs LocalStack

| Aspect | Real AWS | LocalStack |
|--------|----------|------------|
| URL format | `http://bucket.s3-website-region.amazonaws.com` | `http://localhost:4566/bucket/` |
| Custom domain | Yes, with Route53 + CloudFront | No |
| HTTPS | Yes, with CloudFront | No (HTTP only) |
| Cost | Pay for storage + requests | Free |

## Next Steps

Once comfortable, move to [Exercise 04: DynamoDB](../04-dynamodb/)
