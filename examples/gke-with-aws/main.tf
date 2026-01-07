data "google_project" "current" {}

data "google_client_config" "default" {}

data "google_container_cluster" "gke" {
  name     = var.gke_cluster_name
  location = var.gke_cluster_region
  project  = data.google_project.current.project_id
}

data "aws_region" "current" {}

data "aws_availability_zones" "available" {
  state = "available"
}

# =============================================================================
# Onboard cluster to CAST AI
# =============================================================================

module "castai-gke-iam" {
  source  = "castai/gke-iam/castai"
  version = "~> 0.5"

  project_id       = data.google_project.current.project_id
  gke_cluster_name = data.google_container_cluster.gke.name
}

module "castai-gke-cluster" {
  source  = "castai/gke-cluster/castai"
  version = "~> 9"

  api_url          = var.castai_api_url
  castai_api_token = var.castai_api_token

  project_id           = data.google_project.current.project_id
  gke_cluster_name     = data.google_container_cluster.gke.name
  gke_cluster_location = data.google_container_cluster.gke.location
  gke_credentials      = module.castai-gke-iam.private_key

  wait_for_cluster_ready          = true
  default_node_configuration_name = "default"

  node_configurations = {
    default = {
      subnets = [data.google_container_cluster.gke.subnetwork]
    }
  }

  install_omni = true
}

# =============================================================================
# Create edge locations
# =============================================================================

module "castai_aws_edge_location" {
  source = "../.."

  cluster_id      = module.castai-gke-cluster.cluster_id
  organization_id = module.castai-gke-cluster.organization_id

  region = data.aws_region.current.region
  zones  = data.aws_availability_zones.available.names

  tags = {
    ManagedBy = "terraform"
  }

  depends_on = [module.castai-gke-cluster]
}

# =============================================================================
# Edge location with existing vpc
# =============================================================================

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "existing-vpc"
  cidr = "10.0.0.0/16"

  azs            = ["eu-central-1a", "eu-central-1b"]
  public_subnets = ["10.0.0.0/24", "10.0.1.0/24"]
}

module "castai_aws_edge_location_existing_vpc" {
  source = "../.."

  cluster_id      = module.castai-gke-cluster.cluster_id
  organization_id = module.castai-gke-cluster.organization_id

  region     = data.aws_region.current.region
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.public_subnets
  zones      = module.vpc.azs

  tags = {
    ManagedBy = "terraform"
  }
  depends_on = [module.castai-gke-cluster]
}
