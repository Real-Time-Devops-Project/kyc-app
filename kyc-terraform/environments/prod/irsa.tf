data "aws_caller_identity" "current" {}

data "tls_certificate" "eks_oidc" {
  url = module.eks.cluster_oidc_issuer_url
}

locals {
  eks_oidc_issuer_host = replace(module.eks.cluster_oidc_issuer_url, "https://", "")
}

resource "aws_iam_openid_connect_provider" "eks" {
  url             = module.eks.cluster_oidc_issuer_url
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks_oidc.certificates[0].sha1_fingerprint]
}

resource "aws_iam_role" "kyc_app_irsa" {
  name = "${var.environment}-kyc-app-irsa-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "sts:AssumeRoleWithWebIdentity"
        Principal = {
          Federated = aws_iam_openid_connect_provider.eks.arn
        }
        Condition = {
          StringEquals = {
            "${local.eks_oidc_issuer_host}:aud" = "sts.amazonaws.com"
            "${local.eks_oidc_issuer_host}:sub" = "system:serviceaccount:${var.k8s_namespace}:${var.k8s_service_account_name}"
          }
        }
      }
    ]
  })
}

resource "aws_iam_policy" "kyc_app_runtime_access" {
  name = "${var.environment}-kyc-app-runtime-access"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "PostgresIamDatabaseConnect"
        Effect = "Allow"
        Action = [
          "rds-db:connect"
        ]
        Resource = "arn:aws:rds-db:${var.region}:${data.aws_caller_identity.current.account_id}:dbuser:${module.database.rds_resource_id}/${var.app_db_username}"
      },
      {
        Sid    = "ReadApplicationDatabaseSecrets"
        Effect = "Allow"
        Action = [
          "secretsmanager:DescribeSecret",
          "secretsmanager:GetSecretValue"
        ]
        Resource = var.docdb_app_secret_arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "kyc_app_runtime_access" {
  role       = aws_iam_role.kyc_app_irsa.name
  policy_arn = aws_iam_policy.kyc_app_runtime_access.arn
}
