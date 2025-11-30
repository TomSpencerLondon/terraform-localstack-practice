# ============================================================
# OUTPUTS
# ============================================================

output "bucket_name" {
  description = "Name of the S3 bucket"
  value       = aws_s3_bucket.website.id
}

output "bucket_arn" {
  description = "ARN of the S3 bucket"
  value       = aws_s3_bucket.website.arn
}

output "website_endpoint" {
  description = "S3 website endpoint (use this for real AWS)"
  value       = aws_s3_bucket_website_configuration.website.website_endpoint
}

output "localstack_website_url" {
  description = "URL to access the website via LocalStack"
  value       = "http://localhost:4566/${aws_s3_bucket.website.id}/index.html"
}

output "website_files" {
  description = "List of files uploaded to the website"
  value = [
    aws_s3_object.index.key,
    aws_s3_object.error.key,
    aws_s3_object.styles.key
  ]
}
