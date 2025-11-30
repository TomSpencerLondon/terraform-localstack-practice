# =============================================================================
# Variables for VPC Configuration
# =============================================================================

variable "project_name" {
  description = "Name prefix for all resources"
  type        = string
  default     = "learn-vpc"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"

  # /16 = 65,536 IP addresses
  # This gives us room for many subnets
}

variable "availability_zones" {
  description = "List of availability zones to use"
  type        = list(string)
  default     = ["eu-west-2a", "eu-west-2b"]

  # Best practice: Use at least 2 AZs for high availability
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets (one per AZ)"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]

  # /24 = 256 IPs per subnet (251 usable after AWS reservations)
  # 10.0.1.0/24 = 10.0.1.0 - 10.0.1.255
  # 10.0.2.0/24 = 10.0.2.0 - 10.0.2.255
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets (one per AZ)"
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.20.0/24"]

  # Using 10.0.10.x and 10.0.20.x to leave room for expansion
  # You could add 10.0.11.x, 10.0.12.x etc later
}
