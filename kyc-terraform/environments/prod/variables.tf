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

variable "db_name" {
  description = "Name of the database"
  type        = string
  default     = "appdb"
}

variable "db_username" {
  description = "Master username for the database"
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
  default     = true
}

variable "enable_postgres_iam_auth" {
  description = "Enable IAM database authentication for RDS PostgreSQL"
  type        = bool
  default     = true
}

variable "k8s_namespace" {
  description = "Kubernetes namespace used by KYC workloads"
  type        = string
  default     = "kyc"
}

variable "k8s_service_account_name" {
  description = "Kubernetes service account used by KYC workloads"
  type        = string
  default     = "kyc-app-sa"
}

variable "app_db_username" {
  description = "PostgreSQL application user used with IAM database authentication"
  type        = string
  default     = "kyc_app"
}

variable "docdb_app_secret_arn" {
  description = "Secrets Manager ARN containing application MongoDB URI for pods to read through IRSA"
  type        = string
  default     = "*"
}
