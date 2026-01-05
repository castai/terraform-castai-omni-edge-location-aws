# AWS Edge Location for CAST AI

locals {
  # Extract VPC name from existing VPC tags or use vpc-id as fallback
  existing_vpc_name = var.existing_vpc_id != null ? (
    try(data.aws_vpc.existing[0].tags["Name"], null) != null ?
      data.aws_vpc.existing[0].tags["Name"] :
      var.existing_vpc_id
  ) : null

  base_name = (
    var.name != null ? var.name :
    var.existing_vpc_id != null ? "${local.existing_vpc_name}-${var.region}" :
    "aws-${var.region}"
  )


  # Final edge location name
  generated_name = (
    var.name != null ? substr(local.base_name, 0, 30) :
    var.existing_vpc_id != null ? "${substr(local.base_name, 0, 21)}-${random_id.suffix.hex}" :
    "${local.base_name}-${random_id.suffix.hex}"
  )

  # For AWS resources (IAM, security groups)
  sanitized_name = (
    var.name != null ? substr(local.base_name, 0, 35) :
    var.existing_vpc_id != null ? "${substr(local.base_name, 0, 26)}-${random_id.suffix.hex}" :
    "${local.base_name}-${random_id.suffix.hex}"
  )

  # Full resource name with prefix
  resource_name = "castai-omni-${local.sanitized_name}"

  # Common tags merged once and reused across all resources
  common_tags = merge(
    var.tags,
    {
      Name                   = local.resource_name
      "cast-omni:cluster-id" = var.cluster_id
    }
  )

  vpc_id            = var.existing_vpc_id != null ? var.existing_vpc_id : aws_vpc.main[0].id
  security_group_id = aws_security_group.main.id

  default_description = var.existing_vpc_id != null ? (
    try(data.aws_vpc.existing[0].tags["Name"], null) != null ?
      "AWS edge location onboarded by Terraform using existing VPC ${data.aws_vpc.existing[0].tags["Name"]} (${var.existing_vpc_id})" :
      "AWS edge location onboarded by Terraform using existing VPC ${var.existing_vpc_id}"
  ) : "AWS edge location onboarded by Terraform"
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
  count = var.existing_vpc_id == null ? 1 : 0
  state = "available"
}

# Data sources for existing VPC resources (when provided)
data "aws_vpc" "existing" {
  count = var.existing_vpc_id != null ? 1 : 0
  id    = var.existing_vpc_id
}

# Get all subnet IDs in the existing VPC (when VPC is provided but subnet_ids are not)
data "aws_subnets" "existing" {
  count = var.existing_vpc_id != null && var.existing_subnet_ids == null ? 1 : 0

  filter {
    name   = "vpc-id"
    values = [var.existing_vpc_id]
  }
}

locals {
  subnet_ids_to_lookup = (
    var.existing_subnet_ids != null ? var.existing_subnet_ids :
    var.existing_vpc_id != null ? data.aws_subnets.existing[0].ids :
    []
  )
}

data "aws_subnet" "existing" {
  for_each = toset(local.subnet_ids_to_lookup)
  id       = each.value
}

locals {
  # Get available zones based on scenario:
  # - New VPC: use all available zones in region
  # - Existing VPC: derive directly from subnet data sources
  available_zones = (
    var.existing_vpc_id == null ? data.aws_availability_zones.available[0].names :
    distinct([for subnet in data.aws_subnet.existing : subnet.availability_zone])
  )

  # Create subnet CIDR blocks
  subnet_cidrs = var.existing_vpc_id == null ? [
    for idx, zone in data.aws_availability_zones.available[0].names :
    cidrsubnet(var.vpc_cidr, 8, idx)
  ] : []
}

locals {
  subnet_ids = (
    length(local.subnet_ids_to_lookup) > 0 ? {
      for subnet_id, subnet in data.aws_subnet.existing :
      subnet.availability_zone => subnet.id
    } : {
      for idx, subnet in aws_subnet.main :
      data.aws_availability_zones.available[0].names[idx] => subnet.id
    }
  )
}

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
          "ec2:DescribeInternetGateways",
          "ec2:DescribeRouteTables",
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

resource "aws_vpc" "main" {
  count = var.existing_vpc_id == null ? 1 : 0

  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = local.common_tags
}

resource "aws_internet_gateway" "main" {
  count = var.existing_vpc_id == null ? 1 : 0

  vpc_id = aws_vpc.main[0].id

  tags = local.common_tags
}

resource "aws_subnet" "main" {
  count = var.existing_vpc_id == null ? length(local.available_zones) : 0

  vpc_id                  = aws_vpc.main[0].id
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

resource "aws_route_table" "main" {
  count = var.existing_vpc_id == null ? 1 : 0

  vpc_id = aws_vpc.main[0].id

  tags = local.common_tags
}

resource "aws_route" "internet" {
  count = var.existing_vpc_id == null ? 1 : 0

  route_table_id         = aws_route_table.main[0].id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main[0].id
}

resource "aws_route_table_association" "main" {
  count = length(aws_subnet.main)

  subnet_id      = aws_subnet.main[count.index].id
  route_table_id = aws_route_table.main[0].id
}

# =============================================================================
# Security Group
# =============================================================================

resource "aws_security_group" "main" {
  name        = local.resource_name
  description = "Custom Security Group with specific ports"
  vpc_id      = local.vpc_id

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
  description     = var.description != null ? var.description : local.default_description
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
    vpc_id               = local.vpc_id
    security_group_id    = local.security_group_id
    subnet_ids           = local.subnet_ids
    name_tag             = local.resource_name
  }
}
