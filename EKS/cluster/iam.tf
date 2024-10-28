# Terraform to create minimal role for SSM access as per:
# https://aws.github.io/aws-eks-best-practices/security/docs/hosts/

data "aws_iam_policy_document" "ssm-policy-doc" {
  statement {
    sid = "EnableAccessViaSSMSessionManager"
    actions = [
      "ssmmessages:OpenDataChannel",
      "ssmmessages:OpenControlChannel",
      "ssmmessages:CreateDataChannel",
      "ssmmessages:CreateControlChannel",
      "ssm:UpdateInstanceInformation"
    ]
    resources = ["*"]
    effect    = "Allow"
  }

  statement {
    sid = "EnableSSMRunCommand"
    actions = [
      "ssm:UpdateInstanceInformation",
      "ec2messages:SendReply",
      "ec2messages:GetMessages",
      "ec2messages:GetEndpoint",
      "ec2messages:FailMessage",
      "ec2messages:DeleteMessage",
      "ec2messages:AcknowledgeMessage"
    ]
    resources = ["*"]
    effect    = "Allow"
  }
}

resource "random_id" "random" {
  byte_length = 5
}

resource "aws_iam_policy" "eks-ssm-policy" {
  name        = "${var.env}-eks-ssm-policy-${random_id.random.hex}"
  path        = "/"
  description = "SSM access policy for EKS cluster env ${var.env}"
  policy      = data.aws_iam_policy_document.ssm-policy-doc.json
}


