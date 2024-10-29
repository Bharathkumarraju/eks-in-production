resource "aws_kms_key" "loki" {
  description             = "Used to encrypt Loki S3"
  deletion_window_in_days = 10
  enable_key_rotation     = true
}

resource "aws_kms_alias" "loki" {
  name          = format("alias/%s-eks-loki", local.name)
  target_key_id = aws_kms_key.loki.key_id
}

resource "aws_s3_bucket" "loki" {
  #checkov:skip=CKV_AWS_18:Ensure the S3 bucket has access logging enabled
  #checkov:skip=CKV_AWS_21:Ensure all data stored in the S3 bucket have versioning enabled
  #checkov:skip=CKV_AWS_144:Ensure that S3 bucket has cross-region replication enabled
  #checkov:skip=CKV2_AWS_61:Ensure that an S3 bucket has a lifecycle configuration
  #checkov:skip=CKV2_AWS_62:Ensure S3 buckets should have event notifications enabled
  bucket = format("%s-loki", local.name)
}

resource "aws_s3_bucket_ownership_controls" "loki" {
  bucket = aws_s3_bucket.loki.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "loki" {
  bucket = aws_s3_bucket.loki.id
  acl    = "private"

  depends_on = [aws_s3_bucket_ownership_controls.loki]
}

resource "aws_s3_bucket_server_side_encryption_configuration" "loki" {
  bucket = aws_s3_bucket.loki.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.loki.arn
      sse_algorithm     = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "loki" {
  bucket                  = aws_s3_bucket.loki.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

data "aws_iam_policy_document" "loki_iam_policy_document" {
  statement {
    sid       = "AllowListObjects"
    effect    = "Allow"
    resources = [aws_s3_bucket.loki.arn]
    actions = [
      "s3:ListBucket"
    ]
  }

  statement {
    sid       = "AllowObjects"
    effect    = "Allow"
    resources = [format("%s/*", aws_s3_bucket.loki.arn)]
    actions = [
      "s3:DeleteObject",
      "s3:GetObject",
      "s3:PutObject"
    ]
  }

  statement {
    sid       = "AllowUseKey"
    effect    = "Allow"
    resources = [aws_kms_key.loki.arn]
    actions = [
      "kms:Decrypt",
      "kms:GenerateDataKey"
    ]
  }

}

resource "aws_iam_policy" "loki" {
  description = "Loki IAM policy."
  name        = format("%s-loki-irsa", module.eks.cluster_name)
  policy      = data.aws_iam_policy_document.loki_iam_policy_document.json
}

module "loki_irsa" {
  source = "../../modules/irsa"

  eks_cluster_id        = module.eks.cluster_id
  eks_oidc_provider_arn = format("arn:%s:iam::%s:oidc-provider/%s", data.aws_partition.current.partition, data.aws_caller_identity.current.account_id, replace(module.eks.cluster_oidc_issuer_url, "https://", ""))

  kubernetes_namespace       = "monitoring"
  kubernetes_service_account = "loki-sa"
  irsa_iam_policies          = [aws_iam_policy.loki.arn]
}

module "loki" {
  source = "../../modules/helm-addon"

  helm_config = {
    name        = "loki-distributed"
    chart       = "loki-distributed"
    repository  = "https://grafana.github.io/helm-charts"
    version     = "0.69.16"
    namespace   = kubernetes_namespace_v1.monitoring.metadata[0].name
    description = "Helm chart for Grafana Loki in microservices mode"
    values = [
      file("config/loki.yaml")
    ]

    set = [
      {
        name  = "serviceAccount.name"
        value = module.loki_irsa.service_account
      },
      {
        name  = "serviceAccount.create"
        value = false
      },
      {
        name  = "compactor.serviceAccount.name"
        value = module.loki_irsa.service_account
      },
      {
        name  = "compactor.serviceAccount.create"
        value = false
      },
      {
        name  = "loki.storageConfig.aws.s3"
        value = format("s3://%s/%s", local.region, aws_s3_bucket.loki.id)
      },
      {
        name  = "loki.storageConfig.aws.sse_encryption"
        value = true
      },
      {
        name  = "loki.storageConfig.aws.sse.type"
        value = "SSE-KMS"
      },
      {
        name  = "loki.storageConfig.aws.sse.kms_key_id"
        value = aws_kms_key.loki.key_id
      }
    ]
  }
  depends_on = [
    module.prometheus
  ]
}
