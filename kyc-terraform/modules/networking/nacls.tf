# --- App VPC NACL ---
resource "aws_network_acl" "app" {
  vpc_id     = aws_vpc.app.id
  subnet_ids = aws_subnet.app_private[*].id

  # Ingress: Allow all internal traffic (simplified for demo, restrict in prod)
  ingress {
    protocol   = "-1"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  # Egress: Allow all outbound
  egress {
    protocol   = "-1"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  tags = {
    Name = "${var.environment}-app-nacl"
  }
}

# --- Mgmt VPC NACL ---
resource "aws_network_acl" "mgmt" {
  vpc_id     = aws_vpc.mgmt.id
  subnet_ids = aws_subnet.mgmt_private[*].id

  ingress {
    protocol   = "-1"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  egress {
    protocol   = "-1"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  tags = {
    Name = "${var.environment}-mgmt-nacl"
  }
}
