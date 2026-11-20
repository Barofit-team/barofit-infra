############################################
# EKS Managed Node Group - IAM Role
############################################

data "aws_iam_policy_document" "eks_node_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "eks_node" {
  name               = "barofit-prod-eks-node-role"
  assume_role_policy = data.aws_iam_policy_document.eks_node_assume.json

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "eks_node_worker" {
  role       = aws_iam_role.eks_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "eks_node_ecr" {
  role       = aws_iam_role.eks_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPullOnly"
}

# 초기 VPC CNI 구동 권한
# 19번 Add-on 구성 시 별도 Pod Identity로 분리 검토
resource "aws_iam_role_policy_attachment" "eks_node_cni" {
  role       = aws_iam_role.eks_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

############################################
# EKS Managed Node Group
############################################

resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "barofit-prod-ng"
  node_role_arn   = aws_iam_role.eks_node.arn

  subnet_ids = [
    aws_subnet.private_app["a"].id
  ]

  instance_types = ["t3.large"]
  ami_type       = "AL2023_x86_64_STANDARD"
  capacity_type  = "ON_DEMAND"
  disk_size      = 30

  scaling_config {
    min_size     = 1
    desired_size = 1
    max_size     = 2
  }

  lifecycle {
    # EventBridge Scheduler owns daily start/stop capacity; retain the maximum here.
    ignore_changes = [scaling_config[0].min_size, scaling_config[0].desired_size]
  }

  update_config {
    max_unavailable = 1
  }

  labels = {
    environment = "prod"
    project     = "barofit"
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_node_worker,
    aws_iam_role_policy_attachment.eks_node_ecr,
    aws_iam_role_policy_attachment.eks_node_cni,
    aws_route.private_app_default
  ]

  tags = merge(local.common_tags, {
    Name = "barofit-prod-ng"
  })
}
