data "aws_iam_policy_document" "grafana" {
  #checkov:skip=CKV_AWS_356:Ensure IAM policies limit resource access
  statement {
    sid       = "AllowReadingMetricsFromCloudWatch"
    effect    = "Allow"
    resources = ["*"]

    actions = [
      "cloudwatch:DescribeAlarmsForMetric",
      "cloudwatch:ListMetrics",
      "cloudwatch:GetMetricData",
      "cloudwatch:GetMetricStatistics"
    ]
  }

  statement {
    sid       = "AllowGetInsightsCloudWatch"
    effect    = "Allow"
    resources = ["arn:${data.aws_partition.current.partition}:cloudwatch:${local.region}:${data.aws_caller_identity.current.account_id}:insight-rule/*"]

    actions = [
      "cloudwatch:GetInsightRuleReport",
    ]
  }

  statement {
    sid       = "AllowReadingAlarmHistoryFromCloudWatch"
    effect    = "Allow"
    resources = ["arn:${data.aws_partition.current.partition}:cloudwatch:${local.region}:${data.aws_caller_identity.current.account_id}:alarm:*"]

    actions = [
      "cloudwatch:DescribeAlarmHistory",
      "cloudwatch:DescribeAlarms",
    ]
  }

  statement {
    sid       = "AllowReadingLogsFromCloudWatch"
    effect    = "Allow"
    resources = ["arn:${data.aws_partition.current.partition}:logs:${local.region}:${data.aws_caller_identity.current.account_id}:log-group:*:log-stream:*"]

    actions = [
      "logs:DescribeLogGroups",
      "logs:GetLogGroupFields",
      "logs:StartQuery",
      "logs:StopQuery",
      "logs:GetQueryResults",
      "logs:GetLogEvents",
    ]
  }

  statement {
    sid       = "AllowReadingTagsInstancesRegionsFromEC2"
    effect    = "Allow"
    resources = ["*"]

    actions = [
      "ec2:DescribeTags",
      "ec2:DescribeInstances",
      "ec2:DescribeRegions",
    ]
  }

  statement {
    sid       = "AllowReadingResourcesForTags"
    effect    = "Allow"
    resources = ["*"]
    actions   = ["tag:GetResources"]
  }

  statement {
    sid    = "AllowListApsWorkspaces"
    effect = "Allow"
    resources = [
      "arn:${data.aws_partition.current.partition}:aps:${local.region}:${data.aws_caller_identity.current.account_id}:/*",
      "arn:${data.aws_partition.current.partition}:aps:${local.region}:${data.aws_caller_identity.current.account_id}:workspace/*",
      "arn:${data.aws_partition.current.partition}:aps:${local.region}:${data.aws_caller_identity.current.account_id}:workspace/*/*",
    ]
    actions = [
      "aps:ListWorkspaces",
      "aps:DescribeWorkspace",
      "aps:GetMetricMetadata",
      "aps:GetSeries",
      "aps:QueryMetrics",
    ]
  }
}

resource "aws_iam_policy" "grafana" {
  name        = format("%s-grafana-irsa", module.eks.cluster_name)
  description = "IAM policy for Grafana Pod"
  policy      = data.aws_iam_policy_document.grafana.json
}

resource "kubernetes_namespace_v1" "monitoring" {
  metadata {
    name = "monitoring"
  }
}

module "grafana_irsa" {
  source = "../../modules/irsa"

  eks_cluster_id        = module.eks.cluster_id
  eks_oidc_provider_arn = format("arn:%s:iam::%s:oidc-provider/%s", data.aws_partition.current.partition, data.aws_caller_identity.current.account_id, replace(module.eks.cluster_oidc_issuer_url, "https://", ""))

  kubernetes_namespace       = kubernetes_namespace_v1.monitoring.metadata[0].name
  kubernetes_service_account = "grafana-sa"
  irsa_iam_policies          = [aws_iam_policy.grafana.arn]
}

module "grafana" {
  source = "../../modules/helm-addon"

  helm_config = {
    name        = "grafana"
    chart       = "grafana"
    repository  = "https://grafana.github.io/helm-charts"
    version     = "6.56.6"
    namespace   = kubernetes_namespace_v1.monitoring.metadata[0].name
    description = "The leading tool for querying and visualizing time series and metrics"
    values = [
      templatefile("config/grafana.yaml", {
        region      = local.region
        domain_name = local.domain_name
      })
    ]

    set = [
      {
        name  = "serviceAccount.name"
        value = module.grafana_irsa.service_account
      },
      {
        name  = "serviceAccount.create"
        value = false
      }
    ]
  }
  depends_on = [ 
    module.ingress-nginx 
  ]
}
