resource "aws_kms_key" "tempo" {
  description             = "Used to encrypt Tempo S3"
  deletion_window_in_days = 10
  enable_key_rotation     = true
}

resource "aws_kms_alias" "tempo" {
  name          = format("alias/%s-eks-tempo", local.name)
  target_key_id = aws_kms_key.tempo.key_id
}

resource "aws_s3_bucket" "tempo" {
  #checkov:skip=CKV_AWS_18:Ensure the S3 bucket has access logging enabled
  #checkov:skip=CKV_AWS_21:Ensure all data stored in the S3 bucket have versioning enabled
  #checkov:skip=CKV_AWS_144:Ensure that S3 bucket has cross-region replication enabled
  #checkov:skip=CKV2_AWS_61:Ensure that an S3 bucket has a lifecycle configuration
  #checkov:skip=CKV2_AWS_62:Ensure S3 buckets should have event notifications enabled
  bucket = format("%s-tempo", local.name)
}

resource "aws_s3_bucket_ownership_controls" "tempo" {
  bucket = aws_s3_bucket.tempo.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "tempo" {
  bucket = aws_s3_bucket.tempo.id
  acl    = "private"

  depends_on = [aws_s3_bucket_ownership_controls.tempo]
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tempo" {
  bucket = aws_s3_bucket.tempo.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.tempo.arn
      sse_algorithm     = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "tempo" {
  bucket                  = aws_s3_bucket.tempo.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

data "aws_iam_policy_document" "tempo_iam_policy_document" {
  statement {
    sid    = "TempoPermissions"
    effect = "Allow"
    resources = [
      aws_s3_bucket.tempo.arn,
      format("%s/*", aws_s3_bucket.tempo.arn)
    ]
    actions = [
      "s3:DeleteObject",
      "s3:GetObject",
      "s3:GetObjectTagging",
      "s3:ListBucket",
      "s3:PutObject",
      "s3:PutObjectTagging"
    ]
  }

  statement {
    sid       = "AllowUseKey"
    effect    = "Allow"
    resources = [aws_kms_key.tempo.arn]
    actions = [
      "kms:Decrypt",
      "kms:GenerateDataKey"
    ]
  }
}

resource "aws_iam_policy" "tempo" {
  description = "Tempo IAM policy."
  name        = format("%s-tempo-irsa", module.eks.cluster_name)
  policy      = data.aws_iam_policy_document.tempo_iam_policy_document.json
}

module "tempo_irsa" {
  source = "../../modules/irsa"

  eks_cluster_id        = module.eks.cluster_id
  eks_oidc_provider_arn = format("arn:%s:iam::%s:oidc-provider/%s", data.aws_partition.current.partition, data.aws_caller_identity.current.account_id, replace(module.eks.cluster_oidc_issuer_url, "https://", ""))

  kubernetes_namespace       = "monitoring"
  kubernetes_service_account = "tempo-sa"
  irsa_iam_policies          = [aws_iam_policy.tempo.arn]
}

module "tempo" {
  source = "../../modules/helm-addon"

  helm_config = {
    name        = "tempo-distributed"
    chart       = "tempo-distributed"
    repository  = "https://grafana.github.io/helm-charts"
    version     = "1.4.2"
    namespace   = kubernetes_namespace_v1.monitoring.metadata[0].name
    description = "Grafana Tempo in MicroService mode"
    values = [
      templatefile("config/tempo.yaml", {
        bucket   = aws_s3_bucket.tempo.id
        endpoint = format("s3.%s.amazonaws.com", local.region)
      })
    ]

    set = [
      {
        name  = "serviceAccount.name"
        value = module.tempo_irsa.service_account
      },
      {
        name  = "serviceAccount.create"
        value = false
      }
    ]
  }
}
