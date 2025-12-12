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
