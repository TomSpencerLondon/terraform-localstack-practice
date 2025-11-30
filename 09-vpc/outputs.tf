# =============================================================================
# Outputs - Useful values to reference or display
# =============================================================================

# --- VPC ---
output "vpc_id" {
  description = "The ID of the VPC"
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "The CIDR block of the VPC"
  value       = aws_vpc.main.cidr_block
}

# --- Subnets ---
output "public_subnet_ids" {
  description = "List of public subnet IDs"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "List of private subnet IDs"
  value       = aws_subnet.private[*].id
}

output "public_subnet_cidrs" {
  description = "List of public subnet CIDR blocks"
  value       = aws_subnet.public[*].cidr_block
}

output "private_subnet_cidrs" {
  description = "List of private subnet CIDR blocks"
  value       = aws_subnet.private[*].cidr_block
}

# --- Gateways ---
output "internet_gateway_id" {
  description = "The ID of the Internet Gateway"
  value       = aws_internet_gateway.main.id
}

output "nat_gateway_ids" {
  description = "List of NAT Gateway IDs"
  value       = aws_nat_gateway.main[*].id
}

output "nat_gateway_public_ips" {
  description = "List of NAT Gateway public IPs"
  value       = aws_eip.nat[*].public_ip
}

# --- Route Tables ---
output "public_route_table_id" {
  description = "The ID of the public route table"
  value       = aws_route_table.public.id
}

output "private_route_table_ids" {
  description = "List of private route table IDs"
  value       = aws_route_table.private[*].id
}

# --- Security Groups ---
output "web_security_group_id" {
  description = "The ID of the web security group"
  value       = aws_security_group.web.id
}

output "database_security_group_id" {
  description = "The ID of the database security group"
  value       = aws_security_group.database.id
}

output "lambda_security_group_id" {
  description = "The ID of the Lambda security group"
  value       = aws_security_group.lambda.id
}

# --- Summary ---
output "summary" {
  description = "Summary of the VPC configuration"
  value = <<-EOT

    ==============================================
    VPC CONFIGURATION SUMMARY
    ==============================================

    VPC ID:     ${aws_vpc.main.id}
    VPC CIDR:   ${aws_vpc.main.cidr_block}

    PUBLIC SUBNETS:
    %{for i, subnet in aws_subnet.public~}
      - ${subnet.availability_zone}: ${subnet.cidr_block} (${subnet.id})
    %{endfor~}

    PRIVATE SUBNETS:
    %{for i, subnet in aws_subnet.private~}
      - ${subnet.availability_zone}: ${subnet.cidr_block} (${subnet.id})
    %{endfor~}

    INTERNET GATEWAY: ${aws_internet_gateway.main.id}

    NAT GATEWAYS:
    %{for i, nat in aws_nat_gateway.main~}
      - ${var.availability_zones[i]}: ${nat.id}
    %{endfor~}

    SECURITY GROUPS:
      - Web:      ${aws_security_group.web.id}
      - Database: ${aws_security_group.database.id}
      - Lambda:   ${aws_security_group.lambda.id}

    ==============================================
  EOT
}
