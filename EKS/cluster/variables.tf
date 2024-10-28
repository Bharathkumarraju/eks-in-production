variable "kubernetes_version" {
  description = "EKS version"
  type        = string
  default     = "1.31"
}

variable "eks_admin_role_name" {
  description = "EKS admin role"
  type        = string
  default     = "bharathadmin"
}

variable "addons" {
  description = "EKS addons"
  type        = any
  default = {
    enable_aws_load_balancer_controller = false
    enable_aws_argocd = false
  }
}

variable "authentication_mode" {
  description = "The authentication mode for the cluster. Valid values are CONFIG_MAP, API or API_AND_CONFIG_MAP"
  type        = string
  default     = "API_AND_CONFIG_MAP"
}

variable "env" {
  default = "dev"
}


variable "prefix" {
  description = "Naming scheme prefix"
  type        = string
  default     = "bkr"
}

variable "region" {
  description = "Target AWS region"
  type        = string
  default     = "ap-south-1"
}

variable "region_prefix" {
  description = "Region prefix using for naming"
  type        = string
  default     = "aps1"
}

variable "vpn_access_cidrs" {
  description = "Extra CIDRs to allow all"
  type = list(string)
  default = ["0.0.0.0/0"]
}

variable "ek_config" {
  type = object({
    min_nodes      = number
    max_nodes      = number
    desired_nodes  = number
    instance_types = list(string)
  })
  default = {
    min_nodes      = 1
    max_nodes      = 1
    desired_nodes  = 1
    instance_types = ["t3.small"]
  }
}