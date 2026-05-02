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
  count                   = length(var.availability_zones)
  vpc_id                  = aws_vpc.transit.id
  cidr_block              = cidrsubnet(var.vpc_cidrs["transit"], 8, count.index)
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = false
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
# In production, replace this with an AWS Network Firewall Endpoint or Gateway Load Balancer Endpoint.
resource "aws_network_interface" "firewall_eni" {
  subnet_id = aws_subnet.transit_untrusted[0].id
  tags = {
    Name = "${var.environment}-firewall-interface"
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
  auto_accept_shared_attachments  = "disable"
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
    Name                                        = "${var.environment}-app-private-${count.index + 1}"
    "kubernetes.io/role/internal-elb"           = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
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

# --- VPC Flow Logs ---
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

resource "aws_kms_key" "vpc_flow_logs" {
  description             = "KMS key for VPC Flow Logs encryption"
  deletion_window_in_days = 14
  enable_key_rotation     = true
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Effect = "Allow"
        Principal = {
          Service = "logs.${data.aws_region.current.name}.amazonaws.com"
        }
        Action = [
          "kms:Encrypt*",
          "kms:Decrypt*",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:Describe*"
        ]
        Resource = "*"
        Condition = {
          ArnEquals = {
            "kms:EncryptionContext:aws:logs:arn" : "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/vpc/*"
          }
        }
      }
    ]
  })
}

resource "aws_cloudwatch_log_group" "vpc_flow_logs" {
  for_each          = toset(["app", "mgmt", "transit"])
  name              = "/aws/vpc/${var.environment}-${each.key}-flow-logs"
  retention_in_days = 365
  kms_key_id        = aws_kms_key.vpc_flow_logs.arn
}

resource "aws_iam_role" "vpc_flow_logs" {
  name = "${var.environment}-vpc-flow-logs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = "sts:AssumeRole"
      Principal = {
        Service = "vpc-flow-logs.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy" "vpc_flow_logs" {
  name = "${var.environment}-vpc-flow-logs-policy"
  role = aws_iam_role.vpc_flow_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams"
      ]
      Resource = [for k in ["app", "mgmt", "transit"] : "${aws_cloudwatch_log_group.vpc_flow_logs[k].arn}:*"]
    }]
  })
}

resource "aws_flow_log" "app" {
  vpc_id               = aws_vpc.app.id
  traffic_type         = "ALL"
  iam_role_arn         = aws_iam_role.vpc_flow_logs.arn
  log_destination      = aws_cloudwatch_log_group.vpc_flow_logs["app"].arn
  log_destination_type = "cloud-watch-logs"

  tags = {
    Name = "${var.environment}-app-vpc-flow-log"
  }
}

resource "aws_flow_log" "mgmt" {
  vpc_id               = aws_vpc.mgmt.id
  traffic_type         = "ALL"
  iam_role_arn         = aws_iam_role.vpc_flow_logs.arn
  log_destination      = aws_cloudwatch_log_group.vpc_flow_logs["mgmt"].arn
  log_destination_type = "cloud-watch-logs"

  tags = {
    Name = "${var.environment}-mgmt-vpc-flow-log"
  }
}

resource "aws_flow_log" "transit" {
  vpc_id               = aws_vpc.transit.id
  traffic_type         = "ALL"
  iam_role_arn         = aws_iam_role.vpc_flow_logs.arn
  log_destination      = aws_cloudwatch_log_group.vpc_flow_logs["transit"].arn
  log_destination_type = "cloud-watch-logs"

  tags = {
    Name = "${var.environment}-transit-vpc-flow-log"
  }
}
