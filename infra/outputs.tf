output "aws_account_id" {
  description = "AWS account used by this Terraform root."
  value       = data.aws_caller_identity.current.account_id
}

output "aws_region" {
  description = "AWS region used by this Terraform root."
  value       = var.aws_region
}

output "name_prefix" {
  description = "Naming prefix reserved for this environment."
  value       = local.name_prefix
}

output "environment" {
  description = "Deployment environment."
  value       = var.environment
}

output "project_name" {
  description = "Stable project name used for tagging and resource naming."
  value       = var.project_name
}

output "common_tags" {
  description = "Common tags for all resources."
  value       = local.common_tags
}
