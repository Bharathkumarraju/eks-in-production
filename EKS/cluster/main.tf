# Deploy eks


data "aws_iam_role" "eks_admin_role_name" {
  name = var.eks_admin_role_name
}

data "aws_iam_session_context" "current" {
  # This data source provides information on the IAM source role of an STS assumed role
  # For non-role ARNs, this data source simply passes the ARN through issuer ARN
  # Ref https://github.com/terraform-aws-modules/terraform-aws-eks/issues/2327#issuecomment-1355581682
  # Ref https://github.com/hashicorp/terraform-provider-aws/issues/28381
  arn = data.aws_caller_identity.current.arn
}

resource "aws_security_group" "eks_node" {

  name_prefix = replace("${var.prefix}-${var.env}-eks-node", ".", "-")
  vpc_id      = module.vpc.default_vpc_id // var.eks_vpc_id

  ingress {

    /* Allow ssh access from public to private nodes */
    from_port = 22
    to_port   = 22
    protocol  = "tcp"

    cidr_blocks = module.vpc.public_subnets_cidr_blocks
  }
}

# The EKS pods directly log to cloudwatch.
resource "aws_iam_policy" "node_cloudwatch_access" {
  name = replace("${var.prefix}-${var.region_prefix}-${var.env}-node-cloudwatch-access", ".", "-")

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:CreateLogGroup",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams",
          "logs:PutRetentionPolicy",
        ]
        Effect   = "Allow"
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

data "aws_eks_cluster_auth" "cluster_auth" {
  name = module.eks.cluster_name
}


provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.cluster_auth.token
}

provider "kubectl" {
  apply_retry_count      = 5
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  load_config_file       = false
  token                  = data.aws_eks_cluster_auth.cluster_auth.token
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    token                  = data.aws_eks_cluster_auth.cluster_auth.token
  }
}

module "eks" {

  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.8"

  cluster_name                    = local.eks_cluster_name
  cluster_version                 = "1.31"
  vpc_id                          = module.vpc.vpc_id
  subnet_ids                      = module.vpc.private_subnets
  create_cluster_security_group   = true
  enable_irsa                     = true
  cluster_endpoint_public_access  = true

  /*
  manage_aws_auth_configmap = true
  aws_auth_roles = [
    # We need to add in the Karpenter node IAM role for nodes launched by Karpenter
    {
      rolearn  = module.karpenter.role_arn
      username = "system:node:{{EC2PrivateDNSName}}"
      groups = [
        "system:bootstrappers",
        "system:nodes",
      ]
    },
  ]
*/

  kms_key_administrators = distinct(concat([
    "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"],
    [data.aws_iam_session_context.current.issuer_arn]
  ))

  enable_cluster_creator_admin_permissions = true
  access_entries = {
    eks_admin = {
      principal_arn = data.aws_iam_role.eks_admin_role_name.arn
      policy_associations = {
        argocd = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
    karpenter_full_access = {
      principal_arn     = module.karpenter.iam_role_arn
      kubernetes_groups = []
      policy_associations = {
        admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            namespaces = []
            type = "cluster"
          }
        }
      }
    }
  }

  cluster_addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
  }

  cluster_security_group_additional_rules = {
    ingress_vpn_https = {
      description = "Allow VPN/bastion https access to EKS"
      protocol    = "tcp"
      from_port   = 443
      to_port     = 443
      type        = "ingress"
      cidr_blocks = var.vpn_access_cidrs
    }
  }

  eks_managed_node_group_defaults = {
    #ami_type                              = "AL2_x86_64"
    attach_cluster_primary_security_group = true
    create_security_group                 = false

    iam_role_additional_policies = {
      # enable aws system manager for these nodes
      ssm        = aws_iam_policy.eks-ssm-policy.arn
      cloudwatch = aws_iam_policy.node_cloudwatch_access.arn
    }
  }

  eks_managed_node_groups = {

    main = {
      ami_type = "BOTTLEROCKET_x86_64"
      platform = "bottlerocket"

      name = replace("bkr-${var.env}", ".", "-")

      instance_types  = var.ek_config.instance_types
      min_size        = var.ek_config.min_nodes
      max_size        = var.ek_config.max_nodes
      desired_size    = var.ek_config.desired_nodes

      # vpc_security_group_ids = [
      #   aws_security_group.eks_node.id
      # ]

      # Use module user data template to bootstrap
      enable_bootstrap_user_data = true
      # This will get added to the templatels

      bootstrap_extra_args = <<-EOT
        # The admin host container provides SSH access and runs with "superpowers".
        # It is disabled by default, but can be disabled explicitly.
        [settings.host-containers.admin]
        enabled = false

        # The control host container provides out-of-band access via SSM.
        # It is enabled by default, and can be disabled if you do not expect to use SSM.
        # This could leave you with no way to access the API and change settings on an existing node!
        [settings.host-containers.control]
        enabled = true

        # extra args added
        [settings.kernel]
        lockdown = "integrity"
      EOT

    }
  }

  node_security_group_tags = {
    // NOTE: This makes sure the node tagging doesn't get confused with the subnet tagging
    "kubernetes.io/cluster/${local.eks_cluster_name}" = null
  }
  tags = merge(local.tags, {
    # NOTE - if creating multiple security groups with this module, only tag the
    # security group that Karpenter should utilize with the following tag
    # (i.e. - at most, only one security group should have this tag in your account)
    "karpenter.sh/discovery" = local.eks_cluster_name
  })
}




# install Karpenter helm chart

module "karpenter" {
  source  = "terraform-aws-modules/eks/aws//modules/karpenter"
  version = "20.24.0"

  cluster_name = module.eks.cluster_name

  enable_v1_permissions = true

  enable_pod_identity             = true
  create_pod_identity_association = true

  # Used to attach additional IAM policies to the Karpenter node IAM role
  node_iam_role_additional_policies = {
    AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }

  tags = local.tags
}

resource "helm_release" "karpenter_crd" {
  namespace           = "kube-system"
  name                = "karpenter-crd"
  repository          = "oci://public.ecr.aws/karpenter"
  chart               = "karpenter-crd"
  version             = "1.0.1"
  wait                = false
}

resource "helm_release" "karpenter" {
  namespace           = "kube-system"
  name                = "karpenter"
  repository          = "oci://public.ecr.aws/karpenter"
  chart               = "karpenter"
  version             = "1.0.1"
  wait                = false

  values = [
    <<-EOT
    settings:
      clusterName: ${module.eks.cluster_name}
      clusterEndpoint: ${module.eks.cluster_endpoint}
      interruptionQueue: ${module.karpenter.queue_name}
      featureGates:
        spotToSpotConsolidation: true
    EOT
  ]
}


resource "kubectl_manifest" "karpenter_node_class" {
  yaml_body = <<-YAML
    apiVersion: karpenter.k8s.aws/v1
    kind: EC2NodeClass
    metadata:
      name: default
    spec:
      amiFamily: Bottlerocket
      role: ${module.karpenter.node_iam_role_name}
      subnetSelectorTerms:
        - tags:
            karpenter.sh/discovery: ${module.eks.cluster_name}
      securityGroupSelectorTerms:
        - tags:
            karpenter.sh/discovery: ${module.eks.cluster_name}
      tags:
        karpenter.sh/discovery: ${module.eks.cluster_name}
      amiSelectorTerms:
        - alias: bottlerocket@latest
  YAML

  depends_on = [
    helm_release.karpenter
  ]
}

resource "kubectl_manifest" "karpenter_node_pool" {
  yaml_body = <<-YAML
    apiVersion: karpenter.sh/v1
    kind: NodePool
    metadata:
      name: default
    spec:
      template:
        spec:
          nodeClassRef:
            group: karpenter.k8s.aws
            kind: EC2NodeClass
            name: default
          requirements:
            - key: karpenter.sh/capacity-type
              operator: In
              values: ["om-demand"]
      limits:
        cpu: 1000
      disruption:
        consolidationPolicy: WhenEmptyOrUnderutilized
        consolidateAfter: 1m
        budgets:
          - nodes: 10%
  YAML

  depends_on = [
    kubectl_manifest.karpenter_node_class
  ]
}


# create sample app namespace
resource "kubernetes_namespace_v1" "this" {
  metadata {
    name = local.app_name
  }
}

# Sample deployment

resource "kubectl_manifest" "karpenter_example_deployment" {
  yaml_body = <<-YAML
    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: inflate
    spec:
      replicas: 0
      selector:
        matchLabels:
          app: inflate
      template:
        metadata:
          labels:
            app: inflate
        spec:
          terminationGracePeriodSeconds: 0
          containers:
            - name: inflate
              image: public.ecr.aws/eks-distro/kubernetes/pause:3.7
              resources:
                requests:
                  cpu: 1
  YAML

  depends_on = [
    helm_release.karpenter, kubernetes_namespace_v1.this
  ]
}


# Create VPC

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = local.name
  cidr = local.vpc_cidr

  azs             = local.azs
  private_subnets = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 4, k)]
  public_subnets  = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k + 48)]

  enable_nat_gateway = true
  single_nat_gateway = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
    "karpenter.sh/discovery" = local.eks_cluster_name
  }

  tags = local.tags
}