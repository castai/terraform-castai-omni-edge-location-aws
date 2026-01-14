# AWS Edge Location for CAST AI

locals {
  base_name = (
    var.name != null ? var.name :
    var.vpc_id != null ? "vpc-${substr(var.vpc_id, -8, 8)}-${var.region}" :
    "aws-${var.region}"
  )

  # Final edge location name
  generated_name = (
    var.name != null ? substr(local.base_name, 0, 30) :
    var.vpc_id != null ? "${substr(local.base_name, 0, 21)}-${random_id.suffix.hex}" :
    "${local.base_name}-${random_id.suffix.hex}"
  )

  # For AWS resources (IAM, security groups)
  sanitized_name = (
    var.name != null ? substr(local.base_name, 0, 35) :
    var.vpc_id != null ? "${substr(local.base_name, 0, 26)}-${random_id.suffix.hex}" :
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

  vpc_id            = var.subnet_ids != null ? var.vpc_id : aws_vpc.main[0].id
  security_group_id = aws_security_group.main.id

  default_description = var.subnet_ids != null ? (
    "AWS edge location onboarded by Terraform using existing VPC ${var.vpc_id}"
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

locals {
  # Create subnet CIDR blocks (only used when creating new VPC)
  subnet_cidrs = var.subnet_ids == null ? [
    for idx in range(length(var.zones)) :
    cidrsubnet(var.vpc_cidr, 8, idx)
  ] : []

  # Map zones to subnet IDs
  new_vpc_subnet_ids = var.subnet_ids == null ? {
    for idx in range(length(aws_subnet.main)) :
    var.zones[idx] => aws_subnet.main[idx].id
  } : {}

  existing_vpc_subnet_ids = var.subnet_ids != null ? {
    for idx in range(length(var.zones)) :
    var.zones[idx] => var.subnet_ids[idx]
  } : {}

  subnet_ids_map = var.subnet_ids == null ? local.new_vpc_subnet_ids : local.existing_vpc_subnet_ids
}

data "aws_availability_zone" "zones" {
  for_each = toset(var.zones)
  name     = each.value
}

# Validations
resource "null_resource" "validate" {
  lifecycle {
    precondition {
      condition     = var.region == data.aws_region.current.region
      error_message = "The input region '${var.region}' does not match the AWS provider's configured region '${data.aws_region.current.region}'. Ensure the AWS provider region matches the input region parameter."
    }

    precondition {
      condition     = var.vpc_id == null || var.subnet_ids != null
      error_message = "subnet_ids must be provided when vpc_id is specified."
    }

    precondition {
      condition     = var.subnet_ids == null || var.vpc_id != null
      error_message = "vpc_id must be provided when subnet_ids is specified."
    }

    precondition {
      condition = (
        var.vpc_id == null || toset(var.zones) == toset(coalesce(var.subnet_ids, []))
      )
      error_message = "The number of zones must match the number of subnet_ids when using an existing VPC."
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
  count = var.subnet_ids == null ? 1 : 0

  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = local.common_tags
}

resource "aws_internet_gateway" "main" {
  count = var.subnet_ids == null ? 1 : 0

  vpc_id = aws_vpc.main[0].id

  tags = local.common_tags
}

resource "aws_subnet" "main" {
  count = var.subnet_ids == null ? length(var.zones) : 0

  vpc_id                  = aws_vpc.main[0].id
  cidr_block              = local.subnet_cidrs[count.index]
  availability_zone       = var.zones[count.index]
  map_public_ip_on_launch = true

  tags = merge(
    local.common_tags,
    {
      Name = "${local.resource_name}-${substr(var.zones[count.index], -1, 1)}"
    }
  )
}

resource "aws_route_table" "main" {
  count = var.subnet_ids == null ? 1 : 0

  vpc_id = aws_vpc.main[0].id

  tags = local.common_tags
}

resource "aws_route" "internet" {
  count = var.subnet_ids == null ? 1 : 0

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

  # TCP ports: 6443
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
    for zone in var.zones : {
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
    subnet_ids           = local.subnet_ids_map
    name_tag             = local.resource_name
  }
}
