
# General Variables
variable "aws_region" {
  description = "AWS region for this environment."
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Deployment environment."
  type        = string

  validation {
    condition     = contains(["test", "staging", "production"], var.environment)
    error_message = "environment must be either staging or production."
  }
}

variable "project_name" {
  description = "Stable project name used for tagging and resource naming."
  type        = string
  default     = "content-failures-api"
}


variable "managing_tool" {
  description = "Tool managing these resources."
  type        = string
  default     = "Terraform"
}

variable "owner" {
  description = "Team responsible for operating these resources."
  type        = string
}

variable "cost_center" {
  description = "Organizational cost center charged for these resources."
  type        = string
}

# logs
variable "log_retention_days" {
  default = 1
}


#dynamodb
variable "dynamodb_billing_mode" {
  type    = string
  default = "PAY_PER_REQUEST"
}

variable "enable_point_in_time_recovery" {
  description = "Enable point-in-time recovery for DynamoDB tables."
  type        = bool
  default     = true
}

######## # Cost Control variables

variable "enable_cost_ontrol" {
  description = "Enable services that may incur into costs."
  type        = bool
  default     = false
}

variable "enable_sns" {
  description = "Enable SNS services that may incur into costs."
  type        = bool
  default     = false
}
variable "enable_eventbridge" {
  description = "Enable EventBridge services that may incur into costs."
  type        = bool
  default     = false
}
variable "enable_cloudwatch_dashboards" {
  description = "Enable CloudWatch Dashboards services that may incur into costs."
  type        = bool
  default     = false
}
variable "enable_dynamodb_streams" {
  description = "Enable DynamoDB Streams  services that may incur into costs."
  type        = bool
  default     = false
}
variable "enable_xray" {
  description = "Enable X-Ray services that may incur into costs."
  type        = bool
  default     = false
}
variable "enable_s3_replication" {
  description = "Enable S3 Replication services that may incur into costs."
  type        = bool
  default     = false
}




