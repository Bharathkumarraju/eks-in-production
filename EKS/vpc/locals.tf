locals {
  env  = var.env
  region = var.region
  region_parts  = split("-", var.region)
  region_prefix = join("", [local.region_parts[0], substr(local.region_parts[1], 0, 1), local.region_parts[2]])

  vpc_cidr = "10.0.0.0/16"

  availability_zones = slice(sort(data.aws_availability_zones.all.names), 0, var.num_of_availability_zones)
  log_format         = "$${version} $${account-id} $${interface-id} $${srcaddr} $${dstaddr} $${srcport} $${dstport} $${protocol} $${packets} $${bytes} $${start} $${end} $${action} $${log-status} $${vpc-id} $${subnet-id} $${instance-id} $${tcp-flags} $${type} $${pkt-srcaddr} $${pkt-dstaddr} $${region} $${az-id} $${sublocation-type} $${sublocation-id}"

  tags = {
    Environment = var.env
    Prefix      = var.prefix
  }

  vpc_name     = "${var.prefix}.${var.region_prefix}.${var.env}"
  subnets         = cidrsubnets(var.vpc_cidr, [for v in range(9) : 4]...)
  private_subnets = slice(local.subnets, 0, 3)
  db_subnets      = slice(local.subnets, 3, 6)
  public_subnets  = slice(local.subnets, 6, 9)
}



