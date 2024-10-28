data "aws_partition" "current" {}


data "aws_iam_policy_document" "app_iam_policy_document" {
  #checkov:skip=CKV_AWS_356:Ensure IAM policies limit resource access
  statement {
    effect    = "Allow"
    resources = ["*"]
    actions = [
      "secretsmanager:GetResourcePolicy",
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
      "secretsmanager:ListSecretVersionIds"
    ]
  }

  statement {
    effect    = "Allow"
    resources = ["*"]
    actions   = ["secretsmanager:ListSecrets"]
  }
}

resource "aws_iam_policy" "app" {
  description = "app IAM policy."
  name        = format("%s-app-irsa", module.eks.cluster_name)
  policy      = data.aws_iam_policy_document.app_iam_policy_document.json
}

module "app_irsa" {
  source = "../../modules/irsa"

  eks_cluster_id        = module.eks.cluster_id
  eks_oidc_provider_arn = format("arn:%s:iam::%s:oidc-provider/%s", data.aws_partition.current.partition, data.aws_caller_identity.current.account_id, replace(module.eks.cluster_oidc_issuer_url, "https://", ""))

  kubernetes_namespace       = "sampleapp"
  kubernetes_service_account = "app-sa"
  irsa_iam_policies          = [aws_iam_policy.app.arn]
}