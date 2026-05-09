terraform {
  backend "s3" {
    bucket         = "kyc-app-terraform-state-prod"
    key            = "atlantis/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "kyc-app-terraform-locks"
    encrypt        = true
  }
}
