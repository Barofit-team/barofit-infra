# External Secrets Operator(ESO) 컨트롤러가 AWS Secrets Manager의 barofit/prod/* 시크릿을
# 읽기 위한 최소 권한. ESO 자체는 Helm으로 별도 설치(이 레포 코드 아님, infra/README.md 참고).
resource "aws_iam_policy" "eso_secrets_access" {
  name        = "barofit-prod-eso-secrets-access"
  description = "External Secrets Operator가 barofit/prod/* 시크릿을 읽기 위한 권한"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "EsoReadBarofitSecrets"
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
        Resource = "arn:aws:secretsmanager:ap-northeast-2:373514675861:secret:barofit/prod/*"
      }
    ]
  })
}

resource "aws_iam_role" "eso_controller" {
  name = "barofit-prod-eso-controller-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "pods.eks.amazonaws.com" }
        Action    = ["sts:AssumeRole", "sts:TagSession"]
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "eso_controller" {
  role       = aws_iam_role.eso_controller.name
  policy_arn = aws_iam_policy.eso_secrets_access.arn
}

resource "aws_eks_pod_identity_association" "eso_controller" {
  cluster_name    = aws_eks_cluster.main.name
  namespace       = "external-secrets"
  service_account = "external-secrets"
  role_arn        = aws_iam_role.eso_controller.arn

  tags = local.common_tags
}
