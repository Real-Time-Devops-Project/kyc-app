terraform {
  backend "s3" {
    # Terraform state bucket.
    bucket = "my-terraform-trinath"

    # State file key is NOT set here on purpose.
    # It is injected automatically by scripts/tf-init.sh based on the current
    # git branch:
    #   main  → prod/terraform.tfstate
    #   qa    → qa/terraform.tfstate
    #   dev   → dev/terraform.tfstate
    # Run: bash ../../scripts/tf-init.sh   (from this directory)

    # AWS region where the S3 state bucket and DynamoDB lock table exist.
    region = "us-east-1"

    # DynamoDB table used by Terraform for state locking.
    # This table must have partition key LockID of type String.
    dynamodb_table = "terraform-locks"

    # Keep state encrypted at rest in S3.
    encrypt = true
  }
}
