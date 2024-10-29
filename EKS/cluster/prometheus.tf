locals {
  thanos_config = yamlencode(
    {
      type = "s3"
      config = {
        bucket   = aws_s3_bucket.thanos.id
        endpoint = format("s3.%s.amazonaws.com", local.region)
        sse_config = {
          type       = "SSE-KMS"
          kms_key_id = aws_kms_key.thanos.key_id
        }
      }
    }
  )
}

resource "aws_kms_key" "thanos" {
  description             = "Used to encrypt Thanos S3"
  deletion_window_in_days = 10
  enable_key_rotation     = true
}

resource "aws_kms_alias" "thanos" {
  name          = format("alias/%s-eks-thanos", local.name)
  target_key_id = aws_kms_key.thanos.key_id
}

resource "aws_s3_bucket" "thanos" {
  #checkov:skip=CKV_AWS_18:Ensure the S3 bucket has access logging enabled
  #checkov:skip=CKV_AWS_21:Ensure all data stored in the S3 bucket have versioning enabled
  #checkov:skip=CKV_AWS_144:Ensure that S3 bucket has cross-region replication enabled
  #checkov:skip=CKV2_AWS_61:Ensure that an S3 bucket has a lifecycle configuration
  #checkov:skip=CKV2_AWS_62:Ensure S3 buckets should have event notifications enabled
  bucket = format("%s-thanos", local.name)
}

resource "aws_s3_bucket_ownership_controls" "thanos" {
  bucket = aws_s3_bucket.thanos.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "thanos" {
  bucket = aws_s3_bucket.thanos.id
  acl    = "private"

  depends_on = [aws_s3_bucket_ownership_controls.thanos]
}

resource "aws_s3_bucket_server_side_encryption_configuration" "thanos" {
  bucket = aws_s3_bucket.thanos.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.thanos.arn
      sse_algorithm     = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "thanos" {
  bucket                  = aws_s3_bucket.thanos.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

data "aws_iam_policy_document" "thanos_iam_policy_document" {
  statement {
    sid    = "AllowListObjects"
    effect = "Allow"
    resources = [
      aws_s3_bucket.thanos.arn,
      format("%s/*", aws_s3_bucket.thanos.arn)
    ]
    actions = [
      "s3:ListBucket",
      "s3:GetObject",
      "s3:DeleteObject",
      "s3:PutObject"
    ]
  }

  statement {
    sid       = "AllowUseKey"
    effect    = "Allow"
    resources = [aws_kms_key.thanos.arn]
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:GenerateDataKey"
    ]
  }
}

resource "aws_iam_policy" "thanos" {
  description = "Thanos IAM policy."
  name        = format("%s-thanos-irsa", module.eks.cluster_name)
  policy      = data.aws_iam_policy_document.thanos_iam_policy_document.json
}

module "prometheus_irsa" {
  source = "../../modules/irsa"

  eks_cluster_id        = module.eks.cluster_id
  eks_oidc_provider_arn = format("arn:%s:iam::%s:oidc-provider/%s", data.aws_partition.current.partition, data.aws_caller_identity.current.account_id, replace(module.eks.cluster_oidc_issuer_url, "https://", ""))

  kubernetes_namespace       = "monitoring"
  kubernetes_service_account = "prometheus-sa"
  irsa_iam_policies          = [aws_iam_policy.thanos.arn]
}

resource "kubernetes_secret_v1" "thanos_config" {
  metadata {
    name      = "thanos-objstore-config"
    namespace = kubernetes_namespace_v1.monitoring.metadata[0].name
  }
  data = {
    "thanos-storage-config.yaml" = local.thanos_config
  }
}

module "prometheus" {
  source = "../../modules/helm-addon"

  helm_config = {
    name        = "kube-prometheus-stack"
    chart       = "kube-prometheus-stack"
    repository  = "https://prometheus-community.github.io/helm-charts"
    version     = "48.1.0"
    namespace   = kubernetes_namespace_v1.monitoring.metadata[0].name
    description = "kube-prometheus-stack collects Kubernetes manifests, Grafana dashboards, and Prometheus rules combined with documentation and scripts to provide easy to operate end-to-end Kubernetes cluster monitoring with Prometheus using the Prometheus Operator."
    values = [
      file("config/prometheus.yaml")
    ]

    set = [
      {
        name  = "prometheus.serviceAccount.name"
        value = module.prometheus_irsa.service_account
      },
      {
        name  = "prometheus.serviceAccount.create"
        value = false
      }
    ]
  }
  depends_on = [ 
    module.aws_ebs
  ]
}
