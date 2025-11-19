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
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "security_group_source_cidr" {
  description = "Source CIDR for security group ingress rules"
  type        = string
  default     = "0.0.0.0/0"
}

variable "tags" {
  description = "Tags to apply to AWS resources"
  type        = map(string)
  default     = {}
}
