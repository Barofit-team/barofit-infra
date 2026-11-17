data "aws_iam_policy_document" "eks_cluster_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "eks_cluster" {
  name               = "barofit-prod-eks-cluster-role"
  assume_role_policy = data.aws_iam_policy_document.eks_cluster_assume.json

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "eks_cluster" {
  role       = aws_iam_role.eks_cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_eks_cluster" "main" {
  name     = "barofit-prod"
  version  = "1.36"
  role_arn = aws_iam_role.eks_cluster.arn

  vpc_config {
    subnet_ids = [
      aws_subnet.private_app["a"].id,
      aws_subnet.private_app["c"].id
    ]

    endpoint_private_access = true
    endpoint_public_access  = true
    public_access_cidrs     = var.eks_public_access_cidrs
  }

  access_config {
    authentication_mode                         = "API"
    bootstrap_cluster_creator_admin_permissions = true
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster
  ]

  tags = merge(local.common_tags, {
    Name = "barofit-prod"
  })
}
