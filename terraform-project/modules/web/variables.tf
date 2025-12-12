variable "environment" {
  description = "Environment name"
  type        = string
}

variable "waf_acl_arn" {
  description = "ARN of the WAF Web ACL to associate with CloudFront"
  type        = string
}
