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
}

variable "docdb_password" {
  description = "Master password for DocumentDB (MongoDB)"
  type        = string
  sensitive   = true
}
