locals {
  env      = "dev"
  name     = "bkr-sample-eks"
  region   = "ap-south-1"
  app_name = "sampleapp"
  domain_name = "devops4itengineers.com"

  vpc_cidr = "10.0.0.0/16"
  azs      = slice(data.aws_availability_zones.all.names, 0, 3)

  eks_cluster_name = replace("${var.prefix}-${var.env}-eks", ".", "-")

  tags = {
    environement  = local.env
  }
}
