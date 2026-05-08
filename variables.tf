variable "name" {
  type        = string
  description = "Name for the edge location. If not provided, will be auto-generated"
  default     = null
}

variable "cluster_id" {
  type        = string
  description = "CAST AI cluster ID"
}

variable "organization_id" {
  type        = string
  description = "CAST AI organization ID"
}

variable "description" {
  type        = string
  description = "Description of the edge location"
  default     = null
}

variable "region" {
  description = "AWS region (must match AWS provider configuration)"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC (only used when creating a new VPC)"
  type        = string
  default     = "10.0.0.0/16"
}

variable "zones" {
  description = "List of availability zones. When creating a new VPC, subnets will be created in these zones. When using existing VPC, must match the zones of the provided subnet_ids (in the same order)."
  type        = list(string)
}

variable "vpc_id" {
  description = "ID of existing VPC to use. If not provided, a new VPC will be created."
  type        = string
  default     = null
}

variable "vpc_peered" {
  description = "Whether existing VPC is peered with main cluster's VPC. Field is ignored if vpc_id is not provided or main cluster is not EKS"
  type        = bool
  default     = false
}

variable "subnet_ids" {
  description = "List of subnet IDs from the existing VPC. Required when vpc_id is provided. Example: [\"subnet-xxx\", \"subnet-yyy\"]"
  type        = list(string)
  default     = null
}

variable "instance_profile" {
  description = "AWS IAM instance profile ARN to be attached to edge instances. It can be used to grant permissions to access other AWS resources such as ECR."
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags to apply to AWS resources"
  type        = map(string)
  default     = {}
}

variable "control_plane" {
  description = <<-EOT
    Edge location control plane configuration.
    - ha (bool): enable high availability mode for the Edge location control plane (default: true)
  EOT
  type = object({
    ha = optional(bool, true)
  })
  default = {}
}

variable "networking" {
  description = <<-EOT
    Edge cluster networking configuration.
    - tunneled_cidrs (list(string)): list of destination CIDR blocks whose traffic should be routed through the main cluster instead of directly from the edge cluster.
  EOT
  type = object({
    tunneled_cidrs = optional(list(string))
  })
  default = null
}
