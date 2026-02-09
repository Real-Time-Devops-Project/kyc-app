variable "environment" {
  description = "Environment name"
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID to deploy management tools"
  type        = string
}

variable "security_group_ids" {
  description = "List of Security Group IDs"
  type        = list(string)
}

variable "ami_id" {
  description = "AMI ID for the instances (e.g., Ubuntu or Amazon Linux 2)"
  type        = string
  default     = "ami-0c7217cdde317cfec" # Example Ubuntu 22.04 in us-east-1
}

variable "key_name" {
  description = "SSH Key Pair name"
  type        = string
  default     = "my-key-pair"
}
