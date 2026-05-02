# --- App VPC NACL ---
resource "aws_network_acl" "app" {
  vpc_id     = aws_vpc.app.id
  subnet_ids = aws_subnet.app_private[*].id

  # Ingress: Allow traffic from internal VPC CIDRs only
  ingress {
    protocol   = "-1"
    rule_no    = 100
    action     = "allow"
    cidr_block = "10.0.0.0/8"
    from_port  = 0
    to_port    = 0
  }

  # Ingress: Allow return traffic for ephemeral ports (for NAT/TGW responses)
  ingress {
    protocol   = "tcp"
    rule_no    = 200
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 32768
    to_port    = 65535
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

  # Ingress: Allow traffic from internal VPC CIDRs only
  ingress {
    protocol   = "-1"
    rule_no    = 100
    action     = "allow"
    cidr_block = "10.0.0.0/8"
    from_port  = 0
    to_port    = 0
  }

  # Ingress: Allow return traffic for ephemeral ports
  ingress {
    protocol   = "tcp"
    rule_no    = 200
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 32768
    to_port    = 65535
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
    Name = "${var.environment}-mgmt-nacl"
  }
}
