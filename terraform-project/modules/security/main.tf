variable "vpc_id_app" {
  description = "ID of the Application VPC"
  type        = string
}

variable "vpc_id_mgmt" {
  description = "ID of the Management VPC"
  type        = string
}

# --- EKS Cluster Security Group ---
resource "aws_security_group" "eks_cluster" {
  name        = "eks-cluster-sg"
  description = "Security group for EKS Cluster Control Plane"
  vpc_id      = var.vpc_id_app

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "eks-cluster-sg"
  }
}

# --- EKS Worker Nodes Security Group ---
resource "aws_security_group" "eks_nodes" {
  name        = "eks-node-sg"
  description = "Security group for EKS Worker Nodes"
  vpc_id      = var.vpc_id_app

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow communication between nodes
  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = true
  }

  # Allow control plane to communicate with nodes
  ingress {
    from_port       = 1025
    to_port         = 65535
    protocol        = "tcp"
    security_groups = [aws_security_group.eks_cluster.id]
  }

  tags = {
    Name = "eks-node-sg"
  }
}

# --- Database Security Group ---
resource "aws_security_group" "database" {
  name        = "database-sg"
  description = "Security group for RDS, DocumentDB, and Redis"
  vpc_id      = var.vpc_id_app

  # Allow access from EKS nodes
  ingress {
    from_port       = 5432 # PostgreSQL
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.eks_nodes.id]
  }

  ingress {
    from_port       = 27017 # DocumentDB
    to_port         = 27017
    protocol        = "tcp"
    security_groups = [aws_security_group.eks_nodes.id]
  }

  ingress {
    from_port       = 6379 # Redis
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_security_group.eks_nodes.id]
  }

  tags = {
    Name = "database-sg"
  }
}

# --- Management/Bastion Security Group ---
resource "aws_security_group" "mgmt" {
  name        = "mgmt-sg"
  description = "Security group for Management Tools"
  vpc_id      = var.vpc_id_mgmt

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"] # Internal network only
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "mgmt-sg"
  }
}

# --- Outputs ---
output "eks_cluster_sg_id" {
  value = aws_security_group.eks_cluster.id
}

output "eks_nodes_sg_id" {
  value = aws_security_group.eks_nodes.id
}

# --- Proxy Server Security Group ---
resource "aws_security_group" "proxy" {
  name        = "proxy-sg"
  description = "Security group for Proxy Servers (Zscaler/Squid)"
  vpc_id      = var.vpc_id_mgmt # Or Transit VPC if deployed there

  ingress {
    from_port   = 3128 # Standard Proxy Port
    to_port     = 3128
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"] # Allow internal traffic
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "proxy-sg"
  }
}

output "proxy_sg_id" {
  description = "Security Group ID for Proxy Server"
  value       = aws_security_group.proxy.id
}
