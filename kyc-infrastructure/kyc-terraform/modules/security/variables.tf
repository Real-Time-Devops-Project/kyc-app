variable "vpc_id_app" {
  description = "ID of the Application VPC"
  type        = string
}

variable "vpc_id_mgmt" {
  description = "ID of the Management VPC"
  type        = string
}

variable "environment" {
  description = "Environment name for resource naming"
  type        = string
}
