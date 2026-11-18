############################################
# EKS Managed Add-ons - 기본 3개
############################################

locals {
  eks_core_addons = {
    vpc-cni    = "v1.22.4-eksbuild.14"
    coredns    = "v1.14.7-eksbuild.35"
    kube-proxy = "v1.36.0-eksbuild.65"
  }
}

resource "aws_eks_addon" "core" {
  for_each = local.eks_core_addons

  cluster_name  = aws_eks_cluster.main.name
  addon_name    = each.key
  addon_version = each.value

  resolve_conflicts_on_create = "NONE"
  resolve_conflicts_on_update = "PRESERVE"

  tags = local.common_tags
}
