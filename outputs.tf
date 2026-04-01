output "edge_location_id" {
  description = "CAST AI edge location ID"
  value       = castai_edge_location.this.id
}

output "edge_location_name" {
  description = "CAST AI edge location name"
  value       = castai_edge_location.this.name
}

output "role_arn" {
  description = "IAM role ARN used for CAST AI OIDC federation"
  value       = aws_iam_role.castai.arn
}

output "aws_resources" {
  description = "AWS resources used for the edge location"
  value = {
    account_id        = data.aws_caller_identity.current.account_id
    vpc_id            = local.vpc_id
    security_group_id = local.security_group_id
    subnet_ids        = local.subnet_ids_map
  }
}