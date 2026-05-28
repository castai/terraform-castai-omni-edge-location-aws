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
  version = "~> 10"

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

  default_edge_configuration_name = "gpu"

  # Example edge configurations
  edge_configurations = {
    gpu = {
      name = "GPU configuration"
      image_id           = "ami-0gpu1234567890"  # GPU-enabled AMI
      boot_disk_size_gib = 200
      tags = {
        Workload    = "gpu"
        Environment = "production"
      }
      user_data_base64 = "IyEvYmluL2Jhc2gKCmVjaG8gImhlbGxvIHdvcmxkIGZyb20gY3VzdG9tIHNjcmlwdCI="
    }
  }

  depends_on = [module.castai-gke-cluster]
}

# =============================================================================
# Edge location with existing vpc
# =============================================================================
# Note: castai_aws_edge_location module expects that existing vpc has egress traffic setup.

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "existing-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["eu-central-1a", "eu-central-1b"]
  private_subnets = ["10.0.0.0/24", "10.0.1.0/24"]
  public_subnets  = ["10.0.100.0/24", "10.0.101.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true
}

module "castai_aws_edge_location_existing_vpc" {
  source = "../.."

  cluster_id      = module.castai-gke-cluster.cluster_id
  organization_id = module.castai-gke-cluster.organization_id

  region     = data.aws_region.current.region
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets
  zones      = module.vpc.azs

  tags = {
    ManagedBy = "terraform"
  }

  default_edge_configuration_name = "gpu"

  # Example edge configurations
  edge_configurations = {
    gpu = {
      name = "gpu"
      image_id           = "ami-0gpu1234567890"  # GPU-enabled AMI
      boot_disk_size_gib = 200
      tags = {
        Workload = "gpu"
      }
    }
  }

  depends_on = [module.castai-gke-cluster, module.vpc]
}
