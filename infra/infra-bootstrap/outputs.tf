output "state_bucket_name" {
  description = "S3 bucket storing Terraform state."
  value       = aws_s3_bucket.terraform_state.bucket
}

output "state_bucket_arn" {
  description = "ARN of the Terraform state bucket."
  value       = aws_s3_bucket.terraform_state.arn
}

output "state_bucket_region" {
  description = "AWS region containing the Terraform state bucket."
  value       = var.aws_region
}

output "state_kms_key_arn" {
  description = "KMS key used to encrypt Terraform state."
  value       = aws_kms_key.terraform_state.arn
}