output "vpc_id" {
  value = module.vpc.vpc_id
}

output "azs" {
  value = local.azs
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


output "configure_kubectl" {
  description = "Configure kubectl: make sure you're logged in with the correct AWS profile and run the following command to update your kubeconfig"
  value       = "aws eks --region ${local.region} update-kubeconfig --name ${module.eks.cluster_name}"
}
