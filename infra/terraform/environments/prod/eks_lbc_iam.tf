############################################
# AWS Load Balancer Controller - IAM Policy
############################################

resource "aws_iam_policy" "lbc" {
  name        = "barofit-prod-lbc-policy"
  description = "IAM policy for Barofit AWS Load Balancer Controller"

  policy = file("${path.module}/policies/aws-load-balancer-controller-iam-policy-v3.6.3.json")

  tags = local.common_tags
}

############################################
# AWS Load Balancer Controller - IAM Role
############################################

data "aws_iam_policy_document" "lbc_assume" {
  statement {
    actions = [
      "sts:AssumeRole",
      "sts:TagSession"
    ]

    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/eks-cluster-arn"
      values   = [aws_eks_cluster.main.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/kubernetes-namespace"
      values   = ["kube-system"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/kubernetes-service-account"
      values   = ["aws-load-balancer-controller"]
    }
  }
}

resource "aws_iam_role" "lbc" {
  name               = "barofit-prod-lbc-role"
  assume_role_policy = data.aws_iam_policy_document.lbc_assume.json

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "lbc" {
  role       = aws_iam_role.lbc.name
  policy_arn = aws_iam_policy.lbc.arn
}

############################################
# AWS Load Balancer Controller - Pod Identity
############################################

resource "aws_eks_pod_identity_association" "lbc" {
  cluster_name    = aws_eks_cluster.main.name
  namespace       = "kube-system"
  service_account = "aws-load-balancer-controller"
  role_arn        = aws_iam_role.lbc.arn

  depends_on = [
    aws_eks_addon.pod_identity_agent,
    aws_iam_role_policy_attachment.lbc
  ]

  tags = local.common_tags
}
