output "vpc_ids" {
  description = "Map of VPC IDs"
  value = {
    transit = aws_vpc.transit.id
    app     = aws_vpc.app.id
    mgmt    = aws_vpc.mgmt.id
  }
}

output "transit_public_subnet_ids" {
  description = "IDs of public subnets in Transit VPC"
  value       = aws_subnet.transit_public[*].id
}

output "app_subnet_ids" {
  description = "IDs of private subnets in App VPC"
  value       = aws_subnet.app_private[*].id
}

output "mgmt_subnet_ids" {
  description = "IDs of private subnets in Mgmt VPC"
  value       = aws_subnet.mgmt_private[*].id
}

output "transit_gateway_id" {
  description = "ID of the Transit Gateway"
  value       = aws_ec2_transit_gateway.tgw.id
}
