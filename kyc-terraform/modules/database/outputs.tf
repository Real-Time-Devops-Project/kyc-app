output "rds_endpoint" {
  description = "Connection endpoint for the RDS instance"
  value       = aws_db_instance.postgres.endpoint
}

output "rds_resource_id" {
  description = "RDS resource ID required for IAM database authentication"
  value       = aws_db_instance.postgres.resource_id
}

output "rds_master_user_secret_arn" {
  description = "Secrets Manager ARN for the AWS-managed RDS master password"
  value       = try(aws_db_instance.postgres.master_user_secret[0].secret_arn, null)
}

output "docdb_endpoint" {
  description = "Connection endpoint for the DocumentDB cluster"
  value       = aws_docdb_cluster.docdb.endpoint
}

output "docdb_master_user_secret_arn" {
  description = "Secrets Manager ARN for the AWS-managed DocumentDB master password"
  value       = try(aws_docdb_cluster.docdb.master_user_secret[0].secret_arn, null)
}

output "redis_endpoint" {
  description = "Primary endpoint for the Redis replication group"
  value       = aws_elasticache_replication_group.redis.primary_endpoint_address
}
