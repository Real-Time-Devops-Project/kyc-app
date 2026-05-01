output "vpc_ids" {
  description = "IDs of the created VPCs"
  value       = module.networking.vpc_ids
}

output "eks_cluster_endpoint" {
  description = "Endpoint for the EKS cluster"
  value       = module.eks.cluster_endpoint
}

output "eks_cluster_name" {
  description = "Name of the EKS cluster"
  value       = module.eks.cluster_name
}

output "rds_endpoint" {
  description = "Endpoint for the RDS instance"
  value       = module.database.rds_endpoint
}

output "rds_resource_id" {
  description = "RDS resource ID required for IAM DB auth policy resources"
  value       = module.database.rds_resource_id
}

output "rds_master_user_secret_arn" {
  description = "Secrets Manager ARN for the AWS-managed RDS master password"
  value       = module.database.rds_master_user_secret_arn
}

output "docdb_master_user_secret_arn" {
  description = "Secrets Manager ARN for the AWS-managed DocumentDB master password"
  value       = module.database.docdb_master_user_secret_arn
}

output "kyc_app_irsa_role_arn" {
  description = "IAM role ARN to annotate on the KYC Kubernetes service account"
  value       = aws_iam_role.kyc_app_irsa.arn
}

output "jenkins_ip" {
  description = "Public IP of the Jenkins server"
  value       = module.management.jenkins_public_ip
}

output "bastion_ip" {
  description = "Public IP of the Bastion host"
  value       = module.management.bastion_public_ip
}

output "cloudfront_domain" {
  description = "Domain name of the CloudFront distribution"
  value       = module.web.cloudfront_domain_name
}
