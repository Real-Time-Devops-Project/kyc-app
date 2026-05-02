# --- KMS Keys ---
resource "aws_kms_key" "database" {
  description             = "KMS key for database encryption (DocDB, ElastiCache)"
  deletion_window_in_days = 14
  enable_key_rotation     = true
}

# --- RDS PostgreSQL ---
resource "aws_db_subnet_group" "rds" {
  name       = "rds-subnet-group"
  subnet_ids = var.subnet_ids

  tags = {
    Name = "rds-subnet-group"
  }
}

resource "aws_iam_role" "rds_enhanced_monitoring" {
  name = "rds-enhanced-monitoring-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = "sts:AssumeRole"
      Principal = {
        Service = "monitoring.rds.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "rds_enhanced_monitoring" {
  role       = aws_iam_role.rds_enhanced_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

resource "aws_db_instance" "postgres" {
  identifier                          = "app-postgres-db"
  allocated_storage                   = 20
  max_allocated_storage               = 100
  engine                              = "postgres"
  engine_version                      = "16"
  instance_class                      = "db.t3.micro"
  db_name                             = var.db_name
  username                            = var.db_username
  password                            = var.manage_master_user_password ? null : var.postgres_password
  manage_master_user_password         = var.manage_master_user_password
  iam_database_authentication_enabled = var.enable_postgres_iam_auth
  db_subnet_group_name                = aws_db_subnet_group.rds.name
  vpc_security_group_ids              = var.security_group_ids
  storage_encrypted                   = true
  multi_az                            = true
  backup_retention_period             = 7
  backup_window                       = "03:00-04:00"
  maintenance_window                  = "mon:04:30-mon:05:30"
  deletion_protection                 = true
  skip_final_snapshot                 = false
  final_snapshot_identifier           = "app-postgres-db-final-snapshot"

  # CKV_AWS_118: Enhanced Monitoring
  monitoring_interval = 60
  monitoring_role_arn = aws_iam_role.rds_enhanced_monitoring.arn

  # CKV_AWS_353 + CKV_AWS_354: Performance Insights with CMK encryption
  performance_insights_enabled    = true
  performance_insights_kms_key_id = aws_kms_key.database.arn

  # CKV_AWS_226: Auto minor version upgrade
  auto_minor_version_upgrade = true

  # CKV_AWS_129: Enable PostgreSQL logging
  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]

  tags = {
    Name = "app-postgres-db"
  }
}

# --- DocumentDB ---
resource "aws_docdb_subnet_group" "docdb" {
  name       = "docdb-subnet-group"
  subnet_ids = var.subnet_ids
}

resource "aws_docdb_cluster" "docdb" {
  cluster_identifier          = "app-docdb-cluster"
  engine                      = "docdb"
  master_username             = var.db_username
  master_password             = var.manage_master_user_password ? null : var.docdb_password
  manage_master_user_password = var.manage_master_user_password
  db_subnet_group_name        = aws_docdb_subnet_group.docdb.name
  vpc_security_group_ids      = var.security_group_ids
  storage_encrypted           = true
  kms_key_id                  = aws_kms_key.database.arn # CKV_AWS_182: CMK encryption
  backup_retention_period     = 7
  preferred_backup_window     = "03:00-04:00"
  deletion_protection         = true
  skip_final_snapshot         = false
  final_snapshot_identifier   = "app-docdb-cluster-final-snapshot"

  # CKV_AWS_85: Enable DocumentDB logging
  enabled_cloudwatch_logs_exports = ["audit", "profiler"]

  tags = {
    Name = "app-docdb-cluster"
  }
}

resource "aws_docdb_cluster_instance" "cluster_instances" {
  count              = 1
  identifier         = "docdb-cluster-demo-${count.index}"
  cluster_identifier = aws_docdb_cluster.docdb.id
  instance_class     = "db.t3.medium"
}

# --- ElastiCache Redis ---
resource "aws_elasticache_subnet_group" "redis" {
  name       = "redis-subnet-group"
  subnet_ids = var.subnet_ids
}

resource "aws_elasticache_replication_group" "redis" {
  replication_group_id       = "app-redis-cluster"
  description                = "Redis cluster for caching"
  node_type                  = "cache.t3.micro"
  num_cache_clusters         = 1
  port                       = 6379
  subnet_group_name          = aws_elasticache_subnet_group.redis.name
  security_group_ids         = var.security_group_ids
  at_rest_encryption_enabled = true
  kms_key_id                 = aws_kms_key.database.arn # CKV_AWS_191: CMK encryption
  transit_encryption_enabled = true                     # CKV_AWS_31: Encrypt in transit
  auth_token                 = var.redis_auth_token     # CKV_AWS_31: Auth token
}
