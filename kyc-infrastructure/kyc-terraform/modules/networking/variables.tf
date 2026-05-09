variable "region" {
  description = "AWS Region"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "vpc_cidrs" {
  description = "CIDR blocks for VPCs"
  type        = map(string)
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
}

variable "cluster_name" {
  description = "Name of the EKS cluster for Kubernetes subnet tagging"
  type        = string
}
