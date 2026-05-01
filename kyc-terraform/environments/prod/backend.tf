terraform {
  backend "s3" {
    # Terraform state bucket.
    # Keep this as your real S3 bucket name unless you create a different bucket per environment.
    bucket         = "my-terraform-trinath"

    # State file path inside the bucket.
    # Change only the environment folder if you copy this backend for dev or qa.
    # Examples:
    #   dev/terraform.tfstate
    #   qa/terraform.tfstate
    #   prod/terraform.tfstate
    key            = "prod/terraform.tfstate"

    # AWS region where the S3 state bucket and DynamoDB lock table exist.
    region         = "us-east-1"

    # DynamoDB table used by Terraform for state locking.
    # This table must have partition key LockID of type String.
    dynamodb_table = "terraform-locks"

    # Keep state encrypted at rest in S3.
    encrypt        = true
  }
}
