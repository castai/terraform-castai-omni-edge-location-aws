# terraform-castai-omni-edge-location-aws

Terraform module for creating CAST AI edge locations on AWS.

## Usage

> **Warning**
> This module expects the cluster to be onboarded to CAST AI with OMNI enabled.

```hcl
module "castai_aws_edge_location" {
  source  = "castai/omni-edge-location-aws/castai"
  version = "~> 1.0"

  cluster_id      = var.cluster_id
  organization_id = var.organization_id
  region          = "us-east-1"

  tags = {
    ManagedBy = "terraform"
  }
}
```


<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 4.0 |
| <a name="requirement_castai"></a> [castai](#requirement\_castai) | >= 8.1.1 |
| <a name="requirement_null"></a> [null](#requirement\_null) | >= 3.0 |
| <a name="requirement_random"></a> [random](#requirement\_random) | >= 3.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.22.1 |
| <a name="provider_castai"></a> [castai](#provider\_castai) | 8.3.0 |
| <a name="provider_null"></a> [null](#provider\_null) | 3.2.4 |
| <a name="provider_random"></a> [random](#provider\_random) | 3.7.2 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_iam_access_key.castai](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_access_key) | resource |
| [aws_iam_policy.castai](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_user.castai](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_user) | resource |
| [aws_iam_user_policy_attachment.castai](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_user_policy_attachment) | resource |
| [aws_internet_gateway.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/internet_gateway) | resource |
| [aws_route.internet](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route) | resource |
| [aws_route_table.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table) | resource |
| [aws_route_table_association.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association) | resource |
| [aws_security_group.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_subnet.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet) | resource |
| [aws_vpc.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc) | resource |
| [castai_edge_location.this](https://registry.terraform.io/providers/castai/castai/latest/docs/resources/edge_location) | resource |
| [null_resource.validate_region](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [random_id.suffix](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/id) | resource |
| [aws_availability_zone.zones](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/availability_zone) | data source |
| [aws_availability_zones.available](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/availability_zones) | data source |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_cluster_id"></a> [cluster\_id](#input\_cluster\_id) | CAST AI cluster ID | `string` | n/a | yes |
| <a name="input_description"></a> [description](#input\_description) | Description of the edge location | `string` | `null` | no |
| <a name="input_name"></a> [name](#input\_name) | Name for the edge location. If not provided, will be auto-generated | `string` | `null` | no |
| <a name="input_organization_id"></a> [organization\_id](#input\_organization\_id) | CAST AI organization ID | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | AWS region (must match AWS provider configuration) | `string` | n/a | yes |
| <a name="input_security_group_source_cidr"></a> [security\_group\_source\_cidr](#input\_security\_group\_source\_cidr) | Source CIDR for security group ingress rules | `string` | `"0.0.0.0/0"` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to apply to AWS resources | `map(string)` | `{}` | no |
| <a name="input_vpc_cidr"></a> [vpc\_cidr](#input\_vpc\_cidr) | CIDR block for the VPC | `string` | `"10.0.0.0/16"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_aws_resources"></a> [aws\_resources](#output\_aws\_resources) | AWS resources created for the edge location |
| <a name="output_edge_location_id"></a> [edge\_location\_id](#output\_edge\_location\_id) | CAST AI edge location ID |
| <a name="output_edge_location_name"></a> [edge\_location\_name](#output\_edge\_location\_name) | CAST AI edge location name |
<!-- END_TF_DOCS -->

## License

MIT