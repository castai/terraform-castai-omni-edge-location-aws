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
  description = "List of availability zones to use when creating a new VPC. Required when existing_vpc_id is not provided. When using existing VPC, zones are automatically discovered from existing_subnet_ids."
  type        = list(string)
  default     = null
}

variable "security_group_source_cidr" {
  description = "Source CIDR for security group ingress rules"
  type        = string
  default     = "0.0.0.0/0"
}

variable "existing_vpc_id" {
  description = "ID of existing VPC to use. If not provided, a new VPC will be created."
  type        = string
  default     = null
}

variable "existing_subnet_ids" {
  description = "List of subnet IDs from the existing VPC. Required when existing_vpc_id is provided. Example: [\"subnet-xxx\", \"subnet-yyy\"]"
  type        = list(string)
  default     = null
}

variable "tags" {
  description = "Tags to apply to AWS resources"
  type        = map(string)
  default     = {}
}
