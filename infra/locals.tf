
locals {
  name_prefix = "${var.project_name}-${var.environment}"

  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
    Owner       = var.owner
    CostCenter  = var.cost_center
  }

  enabled_features = {
    sns              = var.enable_sns
    eventbridge      = var.enable_eventbridge
    dynamodb_streams = var.enable_dynamodb_streams
    dashboards       = var.enable_cloudwatch_dashboards
    xray             = var.enable_xray
    s3_replication   = var.enable_s3_replication
  }

  effective_sns_enabled = var.environment == "production" ? true : var.enable_sns

  resource_suffix = "${var.environment}-${var.aws_region}"

  dynamodb_config = {
    billing_mode           = var.dynamodb_billing_mode
    point_in_time_recovery = var.enable_point_in_time_recovery
    deletion_protection    = var.environment == "production"
    observation_ttl_days   = 90
  }

}