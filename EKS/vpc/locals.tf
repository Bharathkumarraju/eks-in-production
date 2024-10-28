locals {
  name     = "sample-eks-prod"
  region   = "ap-south-1"
  app_name = "sampleapp"

  vpc_cidr = "10.0.0.0/16"
  azs      = slice(data.aws_availability_zones.available.names, 0, 3)

  tags = {
    Blueprint  = local.name
    environment = "production"
  }
}
