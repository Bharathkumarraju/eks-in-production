module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = local.vpc_name
  cidr = var.vpc_cidr

  azs              = local.availability_zones
  public_subnets   = local.public_subnets
  private_subnets  = local.private_subnets
  database_subnets = local.db_subnets

  create_database_subnet_group = true
  enable_nat_gateway   = true
  single_nat_gateway   = true

  manage_default_security_group  = true
  default_security_group_ingress = []
  default_security_group_egress  = []

  enable_flow_log                      = true
  flow_log_destination_type            = "cloud-watch-logs"
  create_flow_log_cloudwatch_log_group = true
  create_flow_log_cloudwatch_iam_role  = true
  flow_log_max_aggregation_interval    = 60
  flow_log_log_format                  = local.log_format

  tags = local.tags

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }

}
