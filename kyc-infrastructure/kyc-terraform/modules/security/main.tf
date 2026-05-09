# --- EKS Cluster Security Group ---
resource "aws_security_group" "eks_cluster" {
  #checkov:skip=CKV2_AWS_5: Attached in EKS module
  #checkov:skip=CKV_AWS_382: Egress to all ports is required for outbound internet access
  name        = "${var.environment}-eks-cluster-sg"
  description = "Security group for EKS Cluster Control Plane"
  vpc_id      = var.vpc_id_app

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.environment}-eks-cluster-sg"
  }
}

# --- EKS Worker Nodes Security Group ---
resource "aws_security_group" "eks_nodes" {
  #checkov:skip=CKV2_AWS_5: Attached in EKS module
  #checkov:skip=CKV_AWS_382: Egress to all ports is required for outbound internet access
  name        = "${var.environment}-eks-node-sg"
  description = "Security group for EKS Worker Nodes"
  vpc_id      = var.vpc_id_app

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow communication between nodes
  ingress {
    description = "Node-to-node communication"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }

  tags = {
    Name = "${var.environment}-eks-node-sg"
  }
}

# --- Cross-references as standalone rules to avoid cycle ---
# Cluster SG: allow inbound 443 from nodes
resource "aws_security_group_rule" "cluster_ingress_from_nodes" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  description              = "Allow worker nodes to reach the API server"
  security_group_id        = aws_security_group.eks_cluster.id
  source_security_group_id = aws_security_group.eks_nodes.id
}

# Node SG: allow inbound from control plane
resource "aws_security_group_rule" "nodes_ingress_from_cluster" {
  type                     = "ingress"
  from_port                = 1025
  to_port                  = 65535
  protocol                 = "tcp"
  description              = "Control plane to worker nodes"
  security_group_id        = aws_security_group.eks_nodes.id
  source_security_group_id = aws_security_group.eks_cluster.id
}

# --- Database Security Group ---
resource "aws_security_group" "database" {
  #checkov:skip=CKV2_AWS_5: Attached in database module
  name        = "${var.environment}-database-sg"
  description = "Security group for RDS, DocumentDB, and Redis"
  vpc_id      = var.vpc_id_app

  # Allow access from EKS nodes
  ingress {
    description     = "PostgreSQL from EKS nodes"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.eks_nodes.id]
  }

  ingress {
    description     = "DocumentDB from EKS nodes"
    from_port       = 27017
    to_port         = 27017
    protocol        = "tcp"
    security_groups = [aws_security_group.eks_nodes.id]
  }

  ingress {
    description     = "Redis from EKS nodes"
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_security_group.eks_nodes.id]
  }

  tags = {
    Name = "${var.environment}-database-sg"
  }
}

# --- Management/Bastion Security Group ---
resource "aws_security_group" "mgmt" {
  #checkov:skip=CKV2_AWS_5: Attached in management module
  #checkov:skip=CKV_AWS_382: Egress to all ports is required for outbound internet access
  name        = "${var.environment}-mgmt-sg"
  description = "Security group for Management Tools"
  vpc_id      = var.vpc_id_mgmt

  ingress {
    description = "SSH from internal network"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.environment}-mgmt-sg"
  }
}

# --- Proxy Server Security Group ---
resource "aws_security_group" "proxy" {
  #checkov:skip=CKV2_AWS_5: Attached in management module
  #checkov:skip=CKV_AWS_382: Egress to all ports is required for outbound internet access
  name        = "${var.environment}-proxy-sg"
  description = "Security group for Proxy Servers (Zscaler/Squid)"
  vpc_id      = var.vpc_id_mgmt

  ingress {
    description = "Proxy port from internal network"
    from_port   = 3128
    to_port     = 3128
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.environment}-proxy-sg"
  }
}
