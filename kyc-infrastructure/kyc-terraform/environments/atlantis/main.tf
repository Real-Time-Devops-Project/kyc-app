module "atlantis" {
  source  = "terraform-aws-modules/atlantis/aws"
  version = "~> 3.0"

  name = "kyc-atlantis"

  # VPC Config
  vpc_id             = data.aws_vpc.default.id
  private_subnet_ids = data.aws_subnets.private.ids
  public_subnet_ids  = data.aws_subnets.public.ids

  # Route53 / ACM / ALB
  route53_zone_name = "kyc-app.internal"
  certificate_arn   = data.aws_acm_certificate.domain.arn
  create_alb        = true

  # GitHub Config
  github_user       = "kyc-bot"
  github_token      = var.github_token
  github_webhook_secret = var.github_webhook_secret

  # Allow Atlantis to run terraform against the AWS environment
  custom_environment_variables = [
    {
      name  = "ATLANTIS_WEBHOOK_URL"
      value = "https://atlantis.kyc-app.internal/events"
    }
  ]

  # ECS Fargate
  ecs_fargate_assign_public_ip = false
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

data "aws_subnets" "public" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

data "aws_acm_certificate" "domain" {
  domain   = "*.kyc-app.internal"
  statuses = ["ISSUED"]
}
