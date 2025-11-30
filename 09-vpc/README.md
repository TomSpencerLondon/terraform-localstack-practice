# Exercise 09: VPC & Networking

Learn how to build a complete VPC with public/private subnets, internet access, and security controls.

## What You'll Learn

1. **VPC** - Your isolated network in AWS
2. **Subnets** - Public vs Private, across Availability Zones
3. **Internet Gateway** - Connects VPC to the internet
4. **NAT Gateway** - Allows private subnets outbound internet access
5. **Route Tables** - Control traffic flow
6. **Security Groups** - Instance-level firewall (stateful)
7. **Network ACLs** - Subnet-level firewall (stateless)

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│  VPC: 10.0.0.0/16                                                   │
│                                                                     │
│  ┌─────────────────────────────┐  ┌─────────────────────────────┐  │
│  │  Availability Zone A        │  │  Availability Zone B        │  │
│  │                             │  │                             │  │
│  │  ┌───────────────────────┐  │  │  ┌───────────────────────┐  │  │
│  │  │ Public Subnet         │  │  │  │ Public Subnet         │  │  │
│  │  │ 10.0.1.0/24           │  │  │  │ 10.0.2.0/24           │  │  │
│  │  │                       │  │  │  │                       │  │  │
│  │  │  [NAT Gateway]        │  │  │  │  [NAT Gateway]        │  │  │
│  │  └───────────────────────┘  │  │  └───────────────────────┘  │  │
│  │                             │  │                             │  │
│  │  ┌───────────────────────┐  │  │  ┌───────────────────────┐  │  │
│  │  │ Private Subnet        │  │  │  │ Private Subnet        │  │  │
│  │  │ 10.0.10.0/24          │  │  │  │ 10.0.20.0/24          │  │  │
│  │  │                       │  │  │  │                       │  │  │
│  │  │  [Lambda/RDS/etc]     │  │  │  │  [Lambda/RDS/etc]     │  │  │
│  │  └───────────────────────┘  │  │  └───────────────────────┘  │  │
│  └─────────────────────────────┘  └─────────────────────────────┘  │
│                                                                     │
│                        [Internet Gateway]                           │
└─────────────────────────────────────────────────────────────────────┘
                                │
                           [INTERNET]
```

## Key Concepts

### 1. CIDR Blocks (IP Addressing)
- `10.0.0.0/16` = 65,536 IP addresses (10.0.0.0 - 10.0.255.255)
- `10.0.1.0/24` = 256 IP addresses (10.0.1.0 - 10.0.1.255)
- `/16` = first 16 bits fixed, `/24` = first 24 bits fixed

### 2. Reserved IPs (AWS takes 5 per subnet)
| IP | Purpose |
|----|---------|
| .0 | Network address |
| .1 | VPC Router |
| .2 | DNS Server |
| .3 | Reserved |
| .255 | Broadcast |

So a /24 subnet has 251 usable IPs, not 256!

### 3. Public vs Private Subnets
| | Public | Private |
|---|--------|---------|
| Internet access | Direct via IGW | Outbound only via NAT |
| Route to 0.0.0.0/0 | → Internet Gateway | → NAT Gateway |
| Public IP | Yes (optional) | No |
| Use for | Bastion, ALB, NAT | Lambda, RDS, Apps |

### 4. Security Groups vs NACLs
| | Security Group | NACL |
|---|----------------|------|
| Level | Instance (ENI) | Subnet |
| Stateful? | Yes | No |
| Rules | Allow only | Allow + Deny |
| Default | Deny in, Allow out | Allow all |

## Steps

### Step 1: Initialize and Apply

```bash
cd 09-vpc
terraform init
terraform plan
terraform apply
```

### Step 2: Explore the VPC

```bash
# List VPCs
awslocal ec2 describe-vpcs --query 'Vpcs[*].[VpcId,CidrBlock,Tags[?Key==`Name`].Value|[0]]' --output table

# List Subnets
awslocal ec2 describe-subnets --query 'Subnets[*].[SubnetId,CidrBlock,AvailabilityZone,Tags[?Key==`Name`].Value|[0]]' --output table

# List Route Tables
awslocal ec2 describe-route-tables --query 'RouteTables[*].[RouteTableId,Tags[?Key==`Name`].Value|[0]]' --output table

# List Security Groups
awslocal ec2 describe-security-groups --query 'SecurityGroups[*].[GroupId,GroupName,Description]' --output table

# List Internet Gateways
awslocal ec2 describe-internet-gateways --output table
```

### Step 3: Understand Route Tables

```bash
# Show routes in a route table
awslocal ec2 describe-route-tables --query 'RouteTables[*].{Name:Tags[?Key==`Name`].Value|[0],Routes:Routes}' --output json
```

Public route table should have:
- `10.0.0.0/16` → local (within VPC)
- `0.0.0.0/0` → igw-xxx (Internet Gateway)

Private route table should have:
- `10.0.0.0/16` → local
- `0.0.0.0/0` → nat-xxx (NAT Gateway)

### Step 4: Test Security Groups

```bash
# View security group rules
awslocal ec2 describe-security-groups --group-names "web-sg" --query 'SecurityGroups[*].{Ingress:IpPermissions,Egress:IpPermissionsEgress}'
```

## Challenges

### Challenge 1: Add a Database Subnet
Create a third tier of subnets for databases (10.0.100.0/24 and 10.0.200.0/24)

### Challenge 2: Create a Bastion Security Group
Create a security group that only allows SSH (port 22) from your IP

### Challenge 3: Add VPC Flow Logs
Enable flow logs to capture network traffic (requires S3 bucket or CloudWatch)

## Common Exam Questions

1. **Q: How many IPs are available in a /24 subnet?**
   A: 251 (256 - 5 reserved by AWS)

2. **Q: Can a Security Group span multiple VPCs?**
   A: No, Security Groups are VPC-specific

3. **Q: What's the difference between stateful and stateless?**
   A: Stateful (SG) = return traffic auto-allowed. Stateless (NACL) = must explicitly allow both directions

4. **Q: How do private subnets access the internet?**
   A: Through a NAT Gateway in a public subnet

## Clean Up

```bash
terraform destroy
```

## Related Concepts
- **VPC Peering** - Connect two VPCs
- **Transit Gateway** - Hub-and-spoke for multiple VPCs
- **VPC Endpoints** - Private access to AWS services (S3, DynamoDB)
- **Direct Connect** - Dedicated connection from on-prem to AWS
