module "castai_aws_edge_location" {
  source = "../.."

  cluster_id      = var.cluster_id
  organization_id = var.organization_id

  # AWS region (validated against the AWS provider's configured region) and the
  # availability zones to spread the edge location across.
  region = var.region
  zones  = var.zones

  name          = var.name
  description   = var.description
  control_plane = var.control_plane
  liqo          = var.liqo
}
