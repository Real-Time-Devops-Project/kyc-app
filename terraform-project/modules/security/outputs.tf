output "eks_cluster_sg_id" {
  description = "Security Group ID for EKS Cluster Control Plane"
  value       = aws_security_group.eks_cluster.id
}

output "eks_nodes_sg_id" {
  description = "Security Group ID for EKS Worker Nodes"
  value       = aws_security_group.eks_nodes.id
}

output "database_sg_id" {
  description = "Security Group ID for Databases"
  value       = aws_security_group.database.id
}

output "mgmt_sg_id" {
  description = "Security Group ID for Management Tools"
  value       = aws_security_group.mgmt.id
}
