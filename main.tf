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

data "castai_omni_cluster" "this" {
  organization_id = var.organization_id
  cluster_id      = var.cluster_id
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
        var.vpc_id == null || length(coalesce(var.zones, [])) == length(coalesce(var.subnet_ids, []))
      )
      error_message = "The number of zones must match the number of subnet_ids when using an existing VPC."
    }
  }
}

# =============================================================================
# IAM Role and Policies
# =============================================================================

# IAM Role with Google OIDC federation trust policy
resource "aws_iam_role" "castai" {
  name = local.resource_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = "accounts.google.com"
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "accounts.google.com:sub"  = data.castai_omni_cluster.this.castai_oidc_config.gcp_service_account_unique_id
            "accounts.google.com:oaud" = "sts.amazonaws.com/${var.cluster_id}"
          }
        }
      }
    ]
  })

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
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeImages",
          "ec2:DescribeVolumes",
          "ec2:DescribeSnapshots",
          "ec2:DescribeKeyPairs",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeSubnets",
          "ec2:DescribeVpcs",
          "ec2:DescribeNatGateways",
          "ec2:DescribeRouteTables",
          "ec2:DescribeAvailabilityZones",
          "ec2:DescribeInstanceTypes",
          "ec2:DescribeInstanceTypeOfferings",
          "ec2:DescribeTags",
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:RunInstances",
          "ec2:TerminateInstances",
          "ec2:StartInstances",
          "ec2:StopInstances",
          "ec2:RebootInstances",
          "ec2:ModifyNetworkInterfaceAttribute",
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateVolume",
          "ec2:DeleteVolume",
          "ec2:AttachVolume",
          "ec2:DetachVolume",
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateTags",
          "ec2:DeleteTags",
        ]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["iam:PassRole"]
        Resource = "*"
      },
    ]
  })

  tags = local.common_tags
}

# Attach policy to role
resource "aws_iam_role_policy_attachment" "castai" {
  role       = aws_iam_role.castai.name
  policy_arn = aws_iam_policy.castai.arn
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

  vpc_id            = aws_vpc.main[0].id
  cidr_block        = local.subnet_cidrs[count.index]
  availability_zone = var.zones[count.index]

  tags = merge(
    local.common_tags,
    {
      Name = "${local.resource_name}-private-${var.zones[count.index]}"
    }
  )
}

resource "aws_nat_gateway" "main" {
  count = var.subnet_ids == null ? 1 : 0

  vpc_id            = aws_vpc.main[0].id
  availability_mode = "regional"

  tags = local.common_tags

  depends_on = [aws_internet_gateway.main]
}

resource "aws_route_table" "main" {
  count = var.subnet_ids == null ? 1 : 0

  vpc_id = aws_vpc.main[0].id

  tags = merge(
    local.common_tags,
    {
      Name = "${local.resource_name}-private"
    }
  )
}

resource "aws_route" "nat" {
  count = var.subnet_ids == null ? 1 : 0

  route_table_id         = aws_route_table.main[0].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.main[0].id
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
  description = "CAST AI security group for edge location ${local.resource_name}"
  vpc_id      = local.vpc_id

  # Allow all traffic within the security group
  ingress {
    description = "Allow all traffic within security group"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
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
  name               = local.generated_name
  region             = var.region
  cluster_id         = var.cluster_id
  organization_id    = var.organization_id
  control_plane_mode = "SHARED"
  description        = var.description != null ? var.description : local.default_description
  zones = [
    for zone in var.zones : {
      id   = data.aws_availability_zone.zones[zone].zone_id
      name = zone
    }
  ]

  # AWS cloud provider configuration
  aws = {
    account_id        = data.aws_caller_identity.current.account_id
    role_arn          = aws_iam_role.castai.arn
    instance_profile  = var.instance_profile
    vpc_id            = local.vpc_id
    vpc_cidr          = var.vpc_cidr
    vpc_peered        = var.vpc_peered
    security_group_id = local.security_group_id
    subnet_ids        = local.subnet_ids_map
  }
}
