terraform {
  required_version = ">= 1.5.0"

  backend "s3" {
    bucket         = "my-company-terraform-state-prod" # Replace with your actual bucket name
    key            = "infrastructure/prod/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock" # Replace with your actual DynamoDB table
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Environment = var.environment
      Project     = "Enterprise-Hub-Spoke"
      ManagedBy   = "Terraform"
    }
  }
}
