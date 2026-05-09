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

variable "db_name" {
  description = "Name of the Postgres database"
  type        = string
  default     = "appdb"
}

variable "db_username" {
  description = "Master username for both databases"
  type        = string
  default     = "adminuser"
}

variable "postgres_password" {
  description = "Master password for RDS PostgreSQL"
  type        = string
  sensitive   = true
  default     = null
  nullable    = true
}

variable "docdb_password" {
  description = "Master password for DocumentDB (MongoDB)"
  type        = string
  sensitive   = true
  default     = null
  nullable    = true
}

variable "manage_master_user_password" {
  description = "Let AWS manage database master passwords in Secrets Manager"
  type        = bool
  default     = false
}

variable "enable_postgres_iam_auth" {
  description = "Enable IAM database authentication for RDS PostgreSQL"
  type        = bool
  default     = false
}

variable "redis_auth_token" {
  description = "Auth token for ElastiCache Redis (must be 16-128 chars)"
  type        = string
  sensitive   = true
  default     = null
  nullable    = true
}
