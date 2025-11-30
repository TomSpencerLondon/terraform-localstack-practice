# =============================================================================
# Exercise 09: VPC & Networking
# =============================================================================
# This creates a production-ready VPC architecture with:
# - Public and private subnets across 2 AZs
# - Internet Gateway for public internet access
# - NAT Gateways for private subnet outbound access
# - Route tables for traffic control
# - Security groups for instance-level security
# - Network ACLs for subnet-level security
# =============================================================================

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region                      = "eu-west-2"
  access_key                  = "test"
  secret_key                  = "test"
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true

  endpoints {
    ec2 = "http://localhost:4566"
    s3  = "http://localhost:4566"
  }
}

# =============================================================================
# VPC
# =============================================================================
# The VPC is your isolated network in AWS. Think of it as your own private
# data center in the cloud.
#
# CIDR: 10.0.0.0/16 gives us 65,536 IP addresses (10.0.0.0 - 10.0.255.255)
# =============================================================================

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true  # Allows instances to get public DNS names
  enable_dns_support   = true  # Enables DNS resolution in the VPC

  tags = {
    Name        = "${var.project_name}-vpc"
    Environment = var.environment
  }
}

# =============================================================================
# INTERNET GATEWAY
# =============================================================================
# The Internet Gateway allows resources in public subnets to access the internet
# and be accessed FROM the internet (if they have a public IP).
#
# Key points:
# - One IGW per VPC
# - Horizontally scaled, redundant, and highly available
# - No bandwidth constraints
# =============================================================================

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name        = "${var.project_name}-igw"
    Environment = var.environment
  }
}

# =============================================================================
# SUBNETS
# =============================================================================
# Subnets segment your VPC. Each subnet exists in ONE Availability Zone.
#
# Public Subnets:  Have a route to the Internet Gateway
# Private Subnets: Route to NAT Gateway (outbound only) or no internet access
#
# Best Practice: Create subnets in multiple AZs for high availability
# =============================================================================

# --- Public Subnets ---
# Resources here CAN have public IPs and direct internet access

resource "aws_subnet" "public" {
  count                   = length(var.availability_zones)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true  # Instances get public IP by default

  tags = {
    Name        = "${var.project_name}-public-${var.availability_zones[count.index]}"
    Environment = var.environment
    Type        = "public"
  }
}

# --- Private Subnets ---
# Resources here have NO direct internet access (outbound via NAT only)

resource "aws_subnet" "private" {
  count                   = length(var.availability_zones)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.private_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = false  # No public IPs

  tags = {
    Name        = "${var.project_name}-private-${var.availability_zones[count.index]}"
    Environment = var.environment
    Type        = "private"
  }
}

# =============================================================================
# ELASTIC IPs for NAT Gateways
# =============================================================================
# NAT Gateways need a static public IP (Elastic IP)
# =============================================================================

resource "aws_eip" "nat" {
  count  = length(var.availability_zones)
  domain = "vpc"

  tags = {
    Name        = "${var.project_name}-nat-eip-${var.availability_zones[count.index]}"
    Environment = var.environment
  }

  depends_on = [aws_internet_gateway.main]
}

# =============================================================================
# NAT GATEWAYS
# =============================================================================
# NAT Gateway allows private subnets to access the internet (outbound only).
# The internet CANNOT initiate connections to private resources.
#
# Key points:
# - Must be in a PUBLIC subnet
# - Needs an Elastic IP
# - One per AZ for high availability
# - AWS managed, scales automatically up to 45 Gbps
# =============================================================================

resource "aws_nat_gateway" "main" {
  count         = length(var.availability_zones)
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id  # NAT goes in PUBLIC subnet!

  tags = {
    Name        = "${var.project_name}-nat-${var.availability_zones[count.index]}"
    Environment = var.environment
  }

  depends_on = [aws_internet_gateway.main]
}

# =============================================================================
# ROUTE TABLES
# =============================================================================
# Route tables control where network traffic is directed.
#
# Each route has:
# - Destination (CIDR block, e.g., 0.0.0.0/0 = all traffic)
# - Target (where to send it, e.g., IGW, NAT, local)
# =============================================================================

# --- Public Route Table ---
# Routes traffic to the Internet Gateway

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  # Route to the internet via Internet Gateway
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  # Local route (10.0.0.0/16 -> local) is implicit

  tags = {
    Name        = "${var.project_name}-public-rt"
    Environment = var.environment
  }
}

# Associate public subnets with public route table
resource "aws_route_table_association" "public" {
  count          = length(var.availability_zones)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# --- Private Route Tables ---
# Routes traffic to NAT Gateway (one per AZ for HA)

resource "aws_route_table" "private" {
  count  = length(var.availability_zones)
  vpc_id = aws_vpc.main.id

  # Route to internet via NAT Gateway
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[count.index].id
  }

  tags = {
    Name        = "${var.project_name}-private-rt-${var.availability_zones[count.index]}"
    Environment = var.environment
  }
}

# Associate private subnets with their respective private route tables
resource "aws_route_table_association" "private" {
  count          = length(var.availability_zones)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

# =============================================================================
# SECURITY GROUPS
# =============================================================================
# Security Groups are STATEFUL firewalls at the instance (ENI) level.
#
# Stateful means: If you allow inbound traffic, the response is automatically
# allowed out (and vice versa).
#
# Key points:
# - Can only ALLOW rules (no deny)
# - All rules evaluated before deciding
# - Default: Deny all inbound, Allow all outbound
# =============================================================================

# --- Web Security Group ---
# Allows HTTP/HTTPS from anywhere

resource "aws_security_group" "web" {
  name        = "web-sg"
  description = "Allow HTTP and HTTPS traffic"
  vpc_id      = aws_vpc.main.id

  # Inbound: HTTP
  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Inbound: HTTPS
  ingress {
    description = "HTTPS from anywhere"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Outbound: Allow all
  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"  # -1 means all protocols
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-web-sg"
    Environment = var.environment
  }
}

# --- Database Security Group ---
# Only allows traffic from the web security group

resource "aws_security_group" "database" {
  name        = "database-sg"
  description = "Allow database traffic from web tier only"
  vpc_id      = aws_vpc.main.id

  # Inbound: PostgreSQL from web tier only
  ingress {
    description     = "PostgreSQL from web tier"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.web.id]  # Reference another SG!
  }

  # Inbound: MySQL from web tier only
  ingress {
    description     = "MySQL from web tier"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.web.id]
  }

  # Outbound: Allow all
  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-database-sg"
    Environment = var.environment
  }
}

# --- Lambda Security Group ---
# For Lambda functions in the VPC

resource "aws_security_group" "lambda" {
  name        = "lambda-sg"
  description = "Security group for Lambda functions"
  vpc_id      = aws_vpc.main.id

  # Outbound: Allow all (Lambda needs to call AWS services)
  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-lambda-sg"
    Environment = var.environment
  }
}

# =============================================================================
# NETWORK ACLs
# =============================================================================
# Network ACLs are STATELESS firewalls at the subnet level.
#
# Stateless means: You must explicitly allow BOTH inbound AND outbound traffic.
#
# Key points:
# - Can ALLOW and DENY rules
# - Rules evaluated in order (lowest number first)
# - Default NACL allows all traffic
# - Custom NACL denies all by default
# =============================================================================

# --- Public Subnet NACL ---
resource "aws_network_acl" "public" {
  vpc_id     = aws_vpc.main.id
  subnet_ids = aws_subnet.public[*].id

  # Inbound: Allow HTTP
  ingress {
    protocol   = "tcp"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 80
    to_port    = 80
  }

  # Inbound: Allow HTTPS
  ingress {
    protocol   = "tcp"
    rule_no    = 110
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 443
    to_port    = 443
  }

  # Inbound: Allow SSH (be more restrictive in production!)
  ingress {
    protocol   = "tcp"
    rule_no    = 120
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 22
    to_port    = 22
  }

  # Inbound: Allow ephemeral ports (for return traffic)
  ingress {
    protocol   = "tcp"
    rule_no    = 130
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }

  # Outbound: Allow HTTP
  egress {
    protocol   = "tcp"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 80
    to_port    = 80
  }

  # Outbound: Allow HTTPS
  egress {
    protocol   = "tcp"
    rule_no    = 110
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 443
    to_port    = 443
  }

  # Outbound: Allow ephemeral ports (for responses)
  egress {
    protocol   = "tcp"
    rule_no    = 120
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }

  tags = {
    Name        = "${var.project_name}-public-nacl"
    Environment = var.environment
  }
}

# --- Private Subnet NACL ---
resource "aws_network_acl" "private" {
  vpc_id     = aws_vpc.main.id
  subnet_ids = aws_subnet.private[*].id

  # Inbound: Allow traffic from VPC (10.0.0.0/16)
  ingress {
    protocol   = -1
    rule_no    = 100
    action     = "allow"
    cidr_block = var.vpc_cidr
    from_port  = 0
    to_port    = 0
  }

  # Inbound: Allow ephemeral ports (for NAT Gateway return traffic)
  ingress {
    protocol   = "tcp"
    rule_no    = 110
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }

  # Outbound: Allow all to VPC
  egress {
    protocol   = -1
    rule_no    = 100
    action     = "allow"
    cidr_block = var.vpc_cidr
    from_port  = 0
    to_port    = 0
  }

  # Outbound: Allow HTTPS (for AWS API calls)
  egress {
    protocol   = "tcp"
    rule_no    = 110
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 443
    to_port    = 443
  }

  # Outbound: Allow HTTP
  egress {
    protocol   = "tcp"
    rule_no    = 120
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 80
    to_port    = 80
  }

  tags = {
    Name        = "${var.project_name}-private-nacl"
    Environment = var.environment
  }
}
