variable "aws_region" {
  description = "AWS Region for Atlantis"
  type        = string
  default     = "us-east-1"
}

variable "github_token" {
  description = "GitHub token for Atlantis to comment on PRs"
  type        = string
  sensitive   = true
}

variable "github_webhook_secret" {
  description = "Secret used to validate GitHub webhooks"
  type        = string
  sensitive   = true
}
