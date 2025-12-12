output "rds_endpoint" {
  description = "Connection endpoint for the RDS instance"
  value       = aws_db_instance.postgres.endpoint
}

output "docdb_endpoint" {
  description = "Connection endpoint for the DocumentDB cluster"
  value       = aws_docdb_cluster.docdb.endpoint
}

output "redis_endpoint" {
  description = "Primary endpoint for the Redis replication group"
  value       = aws_elasticache_replication_group.redis.primary_endpoint_address
}
