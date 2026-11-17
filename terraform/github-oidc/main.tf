data "aws_partition" "current" {}

locals {
  oidc_host = "token.actions.githubusercontent.com"

  github_subjects = [
    for service in var.services :
    "repo:${var.github_organization}/barofit-${service}:ref:refs/heads/main"
  ]

  ecr_repository_arns = [
    for service in var.services :
    "arn:${data.aws_partition.current.partition}:ecr:${var.aws_region}:${var.aws_account_id}:repository/barofit-${service}"
  ]
}

resource "aws_iam_openid_connect_provider" "github" {
  url = "https://${local.oidc_host}"

  client_id_list = [
    "sts.amazonaws.com"
  ]
}

data "aws_iam_policy_document" "github_trust" {
  statement {
    sid     = "AllowApprovedGitHubMainBranches"
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type = "Federated"

      identifiers = [
        aws_iam_openid_connect_provider.github.arn
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_host}:aud"

      values = [
        "sts.amazonaws.com"
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_host}:sub"

      values = local.github_subjects
    }
  }
}

resource "aws_iam_role" "github_ecr_push" {
  name = "barofit-github-ecr-push"

  assume_role_policy = data.aws_iam_policy_document.github_trust.json

  description = "GitHub Actions ECR push for approved BaroFit main branches"
}

data "aws_iam_policy_document" "ecr_push" {
  statement {
    sid    = "ECRLogin"
    effect = "Allow"

    actions = [
      "ecr:GetAuthorizationToken"
    ]

    resources = ["*"]
  }

  statement {
    sid    = "PushBaroFitServiceImages"
    effect = "Allow"

    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:CompleteLayerUpload",
      "ecr:InitiateLayerUpload",
      "ecr:PutImage",
      "ecr:UploadLayerPart"
    ]

    resources = local.ecr_repository_arns
  }
}

resource "aws_iam_role_policy" "github_ecr_push" {
  name = "barofit-ecr-push"
  role = aws_iam_role.github_ecr_push.id

  policy = data.aws_iam_policy_document.ecr_push.json
}