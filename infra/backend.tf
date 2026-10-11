terraform {
  backend "s3" {
    bucket       = "content-failures-api-tfstate-123456789012"
    key          = "content-failures-api/staging/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
    encrypt      = true
  }
}