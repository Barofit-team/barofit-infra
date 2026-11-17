variable "eks_public_access_cidrs" {
  description = "EKS Public API 접근 허용 CIDR"
  type        = list(string)
  nullable    = false

  validation {
    condition = (
      length(var.eks_public_access_cidrs) > 0 &&
      alltrue([
        for cidr in var.eks_public_access_cidrs :
        can(cidrnetmask(cidr)) && cidr != "0.0.0.0/0"
      ])
    )
    error_message = "허용된 IPv4 CIDR을 입력해야 하며 0.0.0.0/0은 금지합니다."
  }
}
