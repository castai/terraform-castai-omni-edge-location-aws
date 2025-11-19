variable "castai_api_token" {
  type      = string
  sensitive = true
}

variable "castai_api_url" {
  type    = string
  default = "https://api.cast.ai"
}

variable "gke_cluster_name" {
  type = string
}

variable "gke_cluster_region" {
  type = string
}

variable "google_project_id" {
  type = string
}

variable "aws_profile" {
  type    = string
  default = null
}
