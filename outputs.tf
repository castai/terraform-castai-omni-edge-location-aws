output "edge_location_id" {
  description = "CAST AI edge location ID"
  value       = castai_edge_location.this.id
}

output "edge_location_name" {
  description = "CAST AI edge location name"
  value       = castai_edge_location.this.name
}

output "aws_resources" {
  description = "AWS resources created for the edge location"
  value = {
    account_id        = data.aws_caller_identity.current.account_id
    vpc_id            = aws_vpc.main.id
    security_group_id = aws_security_group.main.id
    subnet_ids        = {
      for idx, subnet in aws_subnet.main :
      local.available_zones[idx] => subnet.id
    }
  }
}