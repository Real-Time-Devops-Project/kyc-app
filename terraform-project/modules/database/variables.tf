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

variable "db_password" {
  description = "Master password for the databases"
  type        = string
  sensitive   = true
}
