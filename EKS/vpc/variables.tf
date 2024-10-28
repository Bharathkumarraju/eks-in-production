variable "region" {
  type        = string
  description = "Target region"
  default = "ap-south-1"
}

variable "env" {
  type        = string
  description = "Target environment"
  default = "prd"
}


variable "num_azs" {
  default = 3
}


variable "prefix" {
  description = "Naming scheme prefix"
  type        = string
  default     = "bkr"
}

variable "region_prefix" {
  description = "Region prefix using for naming"
  type        = string
}


variable "vpc_cidr" {
  description = "CIDR block for Clara RDS VPC"
  type        = string
}

variable "num_of_availability_zones" {
  description = "Number of availability zones to place subnets over"
  default     = 3
}

