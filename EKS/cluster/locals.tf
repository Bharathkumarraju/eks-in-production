locals {
  env      = "dev"
  name     = "sample-eks"
  region   = "ap-south-1"
  app_name = "sampleapp"

  vpc_cidr = "10.0.0.0/16"
  azs      = slice(data.aws_availability_zones.all.names, 0, 3)

  eks_cluster_name = replace("${var.prefix}-${var.env}-eks", ".", "-")

  tags = {
    environement  = local.env
  }
}