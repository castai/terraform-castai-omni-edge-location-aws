# terraform-castai-omni-edge-location-aws

Terraform module for creating CAST AI edge locations on AWS.

## Breaking changes in v2

v2 is not backwards compatible with v1. Upgrading requires destroying the v1 edge location and creating a new one with v2.

Both versions can run simultaneously. During migration, create counterpart v2 edge locations first, then remove v1 once they are no longer in use.

**Note: creating new v1 edge locations will no longer be supported.**

### Running v1 and v2 simultaneously

Pin existing edge locations to v1 while creating new ones with v2:

```hcl
# Keep existing edge location on v1
module "castai_aws_edge_location_existing" {
  source  = "castai/omni-edge-location-aws/castai"
  version = "~> 1.0"

  cluster_id      = var.cluster_id
  organization_id = var.organization_id
  region          = "us-east-1"
  zones           = data.aws_availability_zones.available.names
}

# New edge location on v2
module "castai_aws_edge_location_new" {
  source  = "castai/omni-edge-location-aws/castai"
  version = "~> 2.0"

  cluster_id      = var.cluster_id
  organization_id = var.organization_id
  region          = "eu-west-1"
  zones           = data.aws_availability_zones.eu_west.names
}
```

## Usage

> **Warning**
> This module expects the cluster to be onboarded to CAST AI with OMNI enabled.

```hcl
data "aws_availability_zones" "available" {
  state = "available"
}

module "castai_aws_edge_location" {
  source  = "castai/omni-edge-location-aws/castai"
  version = "~> 2.0"

  cluster_id      = var.cluster_id
  organization_id = var.organization_id
  region          = "us-east-1"
  zones           = data.aws_availability_zones.available.names

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
| <a name="requirement_castai"></a> [castai](#requirement\_castai) | >= 8.28.0 |
| <a name="requirement_null"></a> [null](#requirement\_null) | >= 3.0 |
| <a name="requirement_random"></a> [random](#requirement\_random) | >= 3.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_iam_policy.castai](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_role.castai](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.castai](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_internet_gateway.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/internet_gateway) | resource |
| [aws_nat_gateway.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/nat_gateway) | resource |
| [aws_route.nat](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route) | resource |
| [aws_route_table.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table) | resource |
| [aws_route_table_association.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association) | resource |
| [aws_security_group.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_subnet.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet) | resource |
| [aws_vpc.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc) | resource |
| [castai_edge_location.this](https://registry.terraform.io/providers/castai/castai/latest/docs/resources/edge_location) | resource |
| [null_resource.validate](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [random_id.suffix](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/id) | resource |
| [aws_availability_zone.zones](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/availability_zone) | data source |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |
| [castai_omni_cluster.this](https://registry.terraform.io/providers/castai/castai/latest/docs/data-sources/omni_cluster) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_cluster_id"></a> [cluster\_id](#input\_cluster\_id) | CAST AI cluster ID | `string` | n/a | yes |
| <a name="input_control_plane"></a> [control\_plane](#input\_control\_plane) | Edge location control plane configuration.<br/>- ha (bool): enable high availability mode for the Edge location control plane (default: true) | <pre>object({<br/>    ha = optional(bool, true)<br/>  })</pre> | `{}` | no |
| <a name="input_description"></a> [description](#input\_description) | Description of the edge location | `string` | `null` | no |
| <a name="input_instance_profile"></a> [instance\_profile](#input\_instance\_profile) | AWS IAM instance profile ARN to be attached to edge instances. It can be used to grant permissions to access other AWS resources such as ECR. | `string` | `null` | no |
| <a name="input_name"></a> [name](#input\_name) | Name for the edge location. If not provided, will be auto-generated | `string` | `null` | no |
| <a name="input_organization_id"></a> [organization\_id](#input\_organization\_id) | CAST AI organization ID | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | AWS region (must match AWS provider configuration) | `string` | n/a | yes |
| <a name="input_subnet_ids"></a> [subnet\_ids](#input\_subnet\_ids) | List of subnet IDs from the existing VPC. Required when vpc\_id is provided. Example: ["subnet-xxx", "subnet-yyy"] | `list(string)` | `null` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to apply to AWS resources | `map(string)` | `{}` | no |
| <a name="input_vpc_cidr"></a> [vpc\_cidr](#input\_vpc\_cidr) | CIDR block for the VPC (only used when creating a new VPC) | `string` | `"10.0.0.0/16"` | no |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | ID of existing VPC to use. If not provided, a new VPC will be created. | `string` | `null` | no |
| <a name="input_vpc_peered"></a> [vpc\_peered](#input\_vpc\_peered) | Whether existing VPC is peered with main cluster's VPC. Field is ignored if vpc\_id is not provided or main cluster is not EKS | `bool` | `false` | no |
| <a name="input_zones"></a> [zones](#input\_zones) | List of availability zones. When creating a new VPC, subnets will be created in these zones. When using existing VPC, must match the zones of the provided subnet\_ids (in the same order). | `list(string)` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_aws_resources"></a> [aws\_resources](#output\_aws\_resources) | AWS resources used for the edge location |
| <a name="output_edge_location_id"></a> [edge\_location\_id](#output\_edge\_location\_id) | CAST AI edge location ID |
| <a name="output_edge_location_name"></a> [edge\_location\_name](#output\_edge\_location\_name) | CAST AI edge location name |
| <a name="output_role_arn"></a> [role\_arn](#output\_role\_arn) | IAM role ARN used for CAST AI OIDC federation |
<!-- END_TF_DOCS -->

## License

MIT
