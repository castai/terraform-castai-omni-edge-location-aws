variable "castai_api_token" {
  type        = string
  sensitive   = true
  description = "CAST AI API token"
}

variable "castai_api_url" {
  type        = string
  description = "CAST AI API URL"
  default     = "https://api.cast.ai"
}

variable "cluster_id" {
  type        = string
  description = "Existing CAST AI cluster ID"
}

variable "organization_id" {
  type        = string
  description = "CAST AI organization ID"
}

variable "region" {
  type        = string
  description = "AWS region (must match the AWS provider configuration)."
}

variable "zones" {
  type        = list(string)
  description = "List of availability zones to spread the edge location across."
}

variable "name" {
  type        = string
  description = "Name for the edge location. If not provided, will be auto-generated"
  default     = null
}

variable "description" {
  type        = string
  description = "Description of the edge location"
  default     = null
}

variable "control_plane" {
  description = <<-EOT
    Edge location control plane configuration.
    - ha (bool): enable high availability mode for the Edge location control plane (default: true)
    - external_address (string, optional): the IP address or hostname used to reach the API server from outside the cluster, if in-cluster LoadBalancer services are not reachable (e.g. cluster is hidden behind an external LoadBalancer).
    - api_server_port (number, optional): the port used for the API server. Defaults to the system value when unset.
    - konnectivity_port (number, optional): the port used for the konnectivity server. Defaults to the system value when unset.
    - service_annotations (map(string), optional): custom annotations to apply to the control plane service.
  EOT
  type = object({
    ha                  = optional(bool, true)
    external_address    = optional(string)
    api_server_port     = optional(number)
    konnectivity_port   = optional(number)
    service_annotations = optional(map(string))
  })
  default = {}
}

variable "liqo" {
  description = <<-EOT
    Liqo configuration for the edge cluster.
    - gateway_replicas (number, optional): number of active replicas for the Liqo gateway servers and clients. Defaults to 1 when unset.
    - gateway_server (object, optional): configuration overrides for the Liqo gateway server:
      - service_labels (map(string), optional): custom labels to apply to the Liqo gateway service.
      - service_annotations (map(string), optional): custom annotations to apply to the Liqo gateway service.
      - external_address (string, optional): the IP address or hostname used to reach the Liqo gateway server from outside the cluster, if in-cluster LoadBalancer services are not reachable (e.g. cluster is hidden behind an external LoadBalancer).
      - external_port (number, optional): the port used for the Liqo gateway server. Defaults to the system value when unset.
  EOT
  type = object({
    gateway_replicas = optional(number)
    gateway_server = optional(object({
      service_labels      = optional(map(string))
      service_annotations = optional(map(string))
      external_address    = optional(string)
      external_port       = optional(number)
    }))
  })
  default = null
}
