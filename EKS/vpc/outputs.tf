output "vpc_id" {
  value = module.vpc.vpc_id
}

output "azs" {
  value = local.availability_zones
}

output "database_subnet_group_name" {
  value = module.vpc.database_subnet_group_name
}

output "database_subnets_cidr_blocks" {
  value = module.vpc.database_subnets_cidr_blocks
}

output "private_subnets" {
  value = module.vpc.private_subnets
}

output "public_subnets" {
  value = module.vpc.public_subnets
}

output "public_subnets_cidr_blocks" {
  value = module.vpc.public_subnets_cidr_blocks
}

output "private_subnets_cidr_blocks" {
  value = module.vpc.private_subnets_cidr_blocks
}

output "database_subnets" {
  value = module.vpc.database_subnets
}


