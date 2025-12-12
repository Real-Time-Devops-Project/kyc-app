variable "vpc_id" {
  description = "VPC ID where databases will be deployed"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for the databases"
  type        = list(string)
}

variable "security_group_ids" {
  description = "List of security group IDs"
  type        = list(string)
}

# --- RDS PostgreSQL ---
resource "aws_db_subnet_group" "rds" {
  name       = "rds-subnet-group"
  subnet_ids = var.subnet_ids

  tags = {
    Name = "rds-subnet-group"
  }
}

resource "aws_db_instance" "postgres" {
  identifier             = "app-postgres-db"
  allocated_storage      = 20
  engine                 = "postgres"
  engine_version         = "14"
  instance_class         = "db.t3.micro"
  db_name                = "appdb"
  username               = "adminuser"
  password               = "securepassword123" # In prod, use Secrets Manager
  db_subnet_group_name   = aws_db_subnet_group.rds.name
  vpc_security_group_ids = var.security_group_ids
  skip_final_snapshot    = true
}

# --- DocumentDB ---
resource "aws_docdb_subnet_group" "docdb" {
  name       = "docdb-subnet-group"
  subnet_ids = var.subnet_ids
}

resource "aws_docdb_cluster" "docdb" {
  cluster_identifier     = "app-docdb-cluster"
  engine                 = "docdb"
  master_username        = "adminuser"
  master_password        = "securepassword123" # In prod, use Secrets Manager
  db_subnet_group_name   = aws_docdb_subnet_group.docdb.name
  vpc_security_group_ids = var.security_group_ids
  skip_final_snapshot    = true
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
  replication_group_id   = "app-redis-cluster"
  description            = "Redis cluster for caching"
  node_type              = "cache.t3.micro"
  num_cache_clusters     = 1
  port                   = 6379
  subnet_group_name      = aws_elasticache_subnet_group.redis.name
  security_group_ids     = var.security_group_ids
  at_rest_encryption_enabled = true
  transit_encryption_enabled = true
}
