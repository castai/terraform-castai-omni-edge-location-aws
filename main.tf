# AWS Edge Location for CAST AI

locals {
  # Generate name if not provided (with random suffix)
  generated_name = var.name != null ? var.name : "aws-${var.region}-${random_id.suffix.hex}"

  # Sanitize name for AWS resource naming (max 35 chars for parts of names)
  sanitized_name = substr(replace(local.generated_name, "/[^a-zA-Z0-9_-]/", ""), 0, 35)

  # Full resource name with prefix
  resource_name = "castai-omni-${local.sanitized_name}"

  # Get all available zones in the region
  available_zones = data.aws_availability_zones.available.names

  # Create subnet CIDR blocks (/24 subnets from VPC /16)
  # Simple sequential allocation: 10.0.0.0/24, 10.0.1.0/24, 10.0.2.0/24, etc.
  subnet_cidrs = [
    for idx, zone in local.available_zones :
    cidrsubnet(var.vpc_cidr, 8, idx)
  ]

  # Common tags merged once and reused across all resources
  common_tags = merge(
    var.tags,
    {
      Name                   = local.resource_name
      "cast-omni:cluster-id" = var.cluster_id
    }
  )
}

# Generate random suffix for edge location name
resource "random_id" "suffix" {
  byte_length = 4
}

# Data source to get AWS account ID
data "aws_caller_identity" "current" {}

# Data source to get current AWS region from provider
data "aws_region" "current" {}

# Data source to get all available zones in the region
data "aws_availability_zones" "available" {
  state = "available"
}

# Data source to get zone details including zone IDs
data "aws_availability_zone" "zones" {
  for_each = toset(local.available_zones)
  name     = each.value
}

# Validation: Ensure the input region matches the AWS provider's configured region
resource "null_resource" "validate_region" {
  lifecycle {
    precondition {
      condition     = var.region == data.aws_region.current.region
      error_message = "The input region '${var.region}' does not match the AWS provider's configured region '${data.aws_region.current.region}'. Ensure the AWS provider region matches the input region parameter."
    }
  }
}

# =============================================================================
# IAM User and Policies
# =============================================================================

# IAM User for CAST AI
resource "aws_iam_user" "castai" {
  name = local.resource_name

  tags = local.common_tags
}

# IAM Policy for CAST AI Edge Location
resource "aws_iam_policy" "castai" {
  name        = "CastaiOmniEdgeLocation-${local.sanitized_name}-Policy"
  description = "Policy for CAST AI Omni Edge Location with read and VM management permissions"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CastAIReadPermissions"
        Effect = "Allow"
        Action = [
          "ec2:DescribeAccountAttributes",
          "ec2:DescribeAddresses",
          "ec2:DescribeAvailabilityZones",
          "ec2:DescribeImages",
          "ec2:DescribeInstanceStatus",
          "ec2:DescribeInstances",
          "ec2:DescribeInstanceTypes",
          "ec2:DescribeKeyPairs",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DescribeRegions",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeSubnets",
          "ec2:DescribeTags",
          "ec2:DescribeVolumes",
          "ec2:DescribeVpcs",
          "iam:ListInstanceProfiles",
          "iam:ListRoles"
        ]
        Resource = "*"
      },
      {
        Sid    = "CastAIVMManagement"
        Effect = "Allow"
        Action = [
          "ec2:RunInstances",
          "ec2:TerminateInstances",
          "ec2:StopInstances",
          "ec2:StartInstances",
          "ec2:RebootInstances",
          "ec2:CreateTags",
          "ec2:DeleteTags"
        ]
        Resource = "*"
      },
      {
        Sid    = "CastAIVolumeManagement"
        Effect = "Allow"
        Action = [
          "ec2:CreateVolume",
          "ec2:DeleteVolume",
          "ec2:AttachVolume",
          "ec2:DetachVolume"
        ]
        Resource = "*"
      },
      {
        Sid      = "CastAIPassRole"
        Effect   = "Allow"
        Action   = ["iam:PassRole"]
        Resource = "*"
      }
    ]
  })

  tags = local.common_tags
}

# Attach policy to user
resource "aws_iam_user_policy_attachment" "castai" {
  user       = aws_iam_user.castai.name
  policy_arn = aws_iam_policy.castai.arn
}

# Create access key for the user
resource "aws_iam_access_key" "castai" {
  user = aws_iam_user.castai.name

  depends_on = [aws_iam_user_policy_attachment.castai]
}

# =============================================================================
# VPC and Networking
# =============================================================================

# VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = local.common_tags
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = local.common_tags
}

# Subnets (one per availability zone)
resource "aws_subnet" "main" {
  count = length(local.available_zones)

  vpc_id                  = aws_vpc.main.id
  cidr_block              = local.subnet_cidrs[count.index]
  availability_zone       = local.available_zones[count.index]
  map_public_ip_on_launch = true

  tags = merge(
    local.common_tags,
    {
      Name = "${local.resource_name}-${substr(local.available_zones[count.index], -1, 1)}"
    }
  )
}

# Route Table
resource "aws_route_table" "main" {
  vpc_id = aws_vpc.main.id

  tags = local.common_tags
}

# Route to Internet Gateway
resource "aws_route" "internet" {
  route_table_id         = aws_route_table.main.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main.id
}

# Associate route table with subnets
resource "aws_route_table_association" "main" {
  count = length(aws_subnet.main)

  subnet_id      = aws_subnet.main[count.index].id
  route_table_id = aws_route_table.main.id
}

# =============================================================================
# Security Group
# =============================================================================

resource "aws_security_group" "main" {
  name        = local.resource_name
  description = "Custom Security Group with specific ports"
  vpc_id      = aws_vpc.main.id

  # TCP ports: 443, 6443
  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.security_group_source_cidr]
  }

  ingress {
    description = "Kubernetes API"
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = [var.security_group_source_cidr]
  }

  # UDP port: 51840
  ingress {
    description = "WireGuard"
    from_port   = 51840
    to_port     = 51840
    protocol    = "udp"
    cidr_blocks = [var.security_group_source_cidr]
  }

  # Allow all outbound traffic
  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.common_tags
}

# =============================================================================
# CAST AI Edge Location
# =============================================================================

resource "castai_edge_location" "this" {
  name            = local.generated_name
  region          = var.region
  cluster_id      = var.cluster_id
  organization_id = var.organization_id
  description     = var.description != null ? var.description : "AWS edge location onboarded by Terraform"
  zones = [
    for zone in local.available_zones : {
      id   = data.aws_availability_zone.zones[zone].zone_id
      name = zone
    }
  ]

  # AWS cloud provider configuration
  aws = {
    account_id           = data.aws_caller_identity.current.account_id
    access_key_id_wo     = aws_iam_access_key.castai.id
    secret_access_key_wo = aws_iam_access_key.castai.secret
    vpc_id               = aws_vpc.main.id
    security_group_id    = aws_security_group.main.id
    subnet_ids = {
      for idx, subnet in aws_subnet.main :
      local.available_zones[idx] => subnet.id
    }
    name_tag = local.resource_name
  }
}
