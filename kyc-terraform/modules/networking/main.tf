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

# --- Transit VPC ---
resource "aws_vpc" "transit" {
  cidr_block           = var.vpc_cidrs["transit"]
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "${var.environment}-transit-vpc"
  }
}

# --- Transit VPC Subnets ---
resource "aws_subnet" "transit_untrusted" {
  count             = length(var.availability_zones)
  vpc_id            = aws_vpc.transit.id
  cidr_block        = cidrsubnet(var.vpc_cidrs["transit"], 8, count.index)
  availability_zone = var.availability_zones[count.index]
  map_public_ip_on_launch = true
  tags = {
    Name = "${var.environment}-transit-untrusted-${count.index + 1}"
    Tier = "Untrusted"
  }
}

resource "aws_subnet" "transit_trusted" {
  count             = length(var.availability_zones)
  vpc_id            = aws_vpc.transit.id
  cidr_block        = cidrsubnet(var.vpc_cidrs["transit"], 8, count.index + 10) # Offset to avoid overlap
  availability_zone = var.availability_zones[count.index]
  tags = {
    Name = "${var.environment}-transit-trusted-${count.index + 1}"
    Tier = "Trusted"
  }
}

resource "aws_internet_gateway" "transit_igw" {
  vpc_id = aws_vpc.transit.id
  tags = {
    Name = "${var.environment}-transit-igw"
  }
}

# --- Firewall / Proxy Placeholder ---
# In a real scenario, this would be a Network Firewall Endpoint or Gateway Load Balancer Endpoint
resource "aws_network_interface" "firewall_eni" {
  subnet_id       = aws_subnet.transit_untrusted[0].id
  security_groups = [] # Add security groups if needed
  tags = {
    Name = "firewall-interface"
  }
}

# --- Route Tables ---
# Untrusted Subnet Route Table (Traffic -> IGW)
resource "aws_route_table" "transit_untrusted" {
  vpc_id = aws_vpc.transit.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.transit_igw.id
  }
  tags = {
    Name = "${var.environment}-transit-untrusted-rt"
  }
}

resource "aws_route_table_association" "transit_untrusted" {
  count          = length(var.availability_zones)
  subnet_id      = aws_subnet.transit_untrusted[count.index].id
  route_table_id = aws_route_table.transit_untrusted.id
}

# Trusted Subnet Route Table (Traffic -> Firewall ENI)
resource "aws_route_table" "transit_trusted" {
  vpc_id = aws_vpc.transit.id
  route {
    cidr_block           = "0.0.0.0/0"
    network_interface_id = aws_network_interface.firewall_eni.id
  }
  tags = {
    Name = "${var.environment}-transit-trusted-rt"
  }
}

resource "aws_route_table_association" "transit_trusted" {
  count          = length(var.availability_zones)
  subnet_id      = aws_subnet.transit_trusted[count.index].id
  route_table_id = aws_route_table.transit_trusted.id
}

# --- Transit Gateway ---
resource "aws_ec2_transit_gateway" "tgw" {
  description                     = "Transit Gateway for Hub-Spoke Architecture"
  auto_accept_shared_attachments  = "enable"
  default_route_table_association = "enable"
  default_route_table_propagation = "enable"
  tags = {
    Name = "${var.environment}-tgw"
  }
}

resource "aws_ec2_transit_gateway_vpc_attachment" "transit" {
  subnet_ids         = aws_subnet.transit_trusted[*].id # Attach Trusted Subnets to TGW
  transit_gateway_id = aws_ec2_transit_gateway.tgw.id
  vpc_id             = aws_vpc.transit.id
  tags = {
    Name = "${var.environment}-tgw-attach-transit"
  }
}

# --- App VPC ---
resource "aws_vpc" "app" {
  cidr_block           = var.vpc_cidrs["app"]
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "${var.environment}-app-vpc"
  }
}

resource "aws_subnet" "app_private" {
  count             = length(var.availability_zones)
  vpc_id            = aws_vpc.app.id
  cidr_block        = cidrsubnet(var.vpc_cidrs["app"], 8, count.index)
  availability_zone = var.availability_zones[count.index]
  tags = {
    Name                                           = "${var.environment}-app-private-${count.index + 1}"
    "kubernetes.io/role/internal-elb"              = "1"
    "kubernetes.io/cluster/${var.environment}-eks" = "shared"
  }
}

resource "aws_ec2_transit_gateway_vpc_attachment" "app" {
  subnet_ids         = aws_subnet.app_private[*].id
  transit_gateway_id = aws_ec2_transit_gateway.tgw.id
  vpc_id             = aws_vpc.app.id
  tags = {
    Name = "${var.environment}-tgw-attach-app"
  }
}

# --- Management VPC ---
resource "aws_vpc" "mgmt" {
  cidr_block           = var.vpc_cidrs["mgmt"]
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "${var.environment}-mgmt-vpc"
  }
}

resource "aws_subnet" "mgmt_private" {
  count             = length(var.availability_zones)
  vpc_id            = aws_vpc.mgmt.id
  cidr_block        = cidrsubnet(var.vpc_cidrs["mgmt"], 8, count.index)
  availability_zone = var.availability_zones[count.index]
  tags = {
    Name = "${var.environment}-mgmt-private-${count.index + 1}"
  }
}

resource "aws_ec2_transit_gateway_vpc_attachment" "mgmt" {
  subnet_ids         = aws_subnet.mgmt_private[*].id
  transit_gateway_id = aws_ec2_transit_gateway.tgw.id
  vpc_id             = aws_vpc.mgmt.id
  tags = {
    Name = "${var.environment}-tgw-attach-mgmt"
  }
}

# --- Outputs ---
output "vpc_ids" {
  value = {
    transit = aws_vpc.transit.id
    app     = aws_vpc.app.id
    mgmt    = aws_vpc.mgmt.id
  }
}

output "app_subnet_ids" {
  value = aws_subnet.app_private[*].id
}

output "mgmt_subnet_ids" {
  value = aws_subnet.mgmt_private[*].id
}
