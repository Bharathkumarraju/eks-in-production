terraform {
  required_version = "~> 1.6.0"

  required_providers {
    aws = {
      version = ">= 5.61.0"
      source  = "hashicorp/aws"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.6.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.13.1"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.4.3"
    }
    time = {
      source  = "hashicorp/time"
      version = ">= 0.8.0"
    }
    kubectl = {
      source  = "alekc/kubectl"
      version = ">= 2.0.0"
    }
  }
}
