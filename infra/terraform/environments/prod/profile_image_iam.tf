# identity 서비스가 프로필 사진을 S3에 올리고 지우기 위한 최소 권한.
# EKS 클러스터/노드그룹 자체는 아직 이 레포 Terraform에 없으므로(PR #11, 미머지) 이름으로만 참조한다.
data "aws_eks_cluster" "barofit_prod" {
  name = "barofit-prod"
}

resource "aws_iam_policy" "profile_image_s3_access" {
  name        = "barofit-prod-profile-image-s3-access"
  description = "identity 서비스의 프로필 사진 업로드/삭제용 S3 권한 (PutObject/DeleteObject만)"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ProfileImagePutDelete"
        Effect   = "Allow"
        Action   = ["s3:PutObject", "s3:DeleteObject"]
        Resource = "${data.aws_s3_bucket.profile_images.arn}/profile-images/*"
      }
    ]
  })
}

resource "aws_iam_role" "profile_image_identity" {
  name = "barofit-prod-identity-profile-image-role"

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
}

resource "aws_iam_role_policy_attachment" "profile_image_identity" {
  role       = aws_iam_role.profile_image_identity.name
  policy_arn = aws_iam_policy.profile_image_s3_access.arn
}

# identity Helm 차트의 전용 ServiceAccount("identity-service", barofit 네임스페이스)에만 연결한다
# (default ServiceAccount에 연결하면 같은 네임스페이스의 다른 서비스도 이 권한을 받게 된다).
resource "aws_eks_pod_identity_association" "profile_image_identity" {
  cluster_name    = data.aws_eks_cluster.barofit_prod.name
  namespace       = "barofit"
  service_account = "identity-service"
  role_arn        = aws_iam_role.profile_image_identity.arn
}
