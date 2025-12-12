variable "region" {
  description = "AWS Region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (e.g., prod, dev, staging)"
  type        = string
  default     = "prod"
}

variable "vpc_cidrs" {
  description = "CIDR blocks for the VPCs"
  type        = map(string)
  default = {
    transit = "10.0.0.0/16"
    app     = "10.1.0.0/16"
    mgmt    = "10.2.0.0/16"
  }
}

variable "availability_zones" {
  description = "List of Availability Zones"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "cluster_name" {
  description = "Name of the EKS Cluster"
  type        = string
  default     = "prod-eks-cluster"
}

variable "db_password" {
  description = "Master password for databases (RDS, DocDB). Should be passed via secrets or env vars in real prod."
  type        = string
  sensitive   = true
}
