# 프로필 사진 버킷. 버킷 자체는 Terraform 바깥에서 먼저 만들어졌으므로(EKS 클러스터와 같은 패턴)
# 여기서는 기존 버킷을 참조만 하고, 정책/퍼블릭 접근 설정만 이 코드로 관리한다.
data "aws_s3_bucket" "profile_images" {
  bucket = "barofit-profile-images"
}

resource "aws_cloudfront_origin_access_control" "profile_images" {
  name                              = "barofit-prod-profile-images-oac"
  description                       = "CloudFront OAC for barofit-profile-images"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# 기존 "Principal: *" 공개 정책을 CloudFront(OAC) 전용으로 교체한다.
# 버킷이 아직 비어 있어(오브젝트 0개) 지금이 마이그레이션 없이 바꿀 수 있는 시점이다.
resource "aws_s3_bucket_policy" "profile_images" {
  bucket = data.aws_s3_bucket.profile_images.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowCloudFrontReadViaOAC"
        Effect    = "Allow"
        Principal = { Service = "cloudfront.amazonaws.com" }
        Action    = "s3:GetObject"
        Resource  = "${data.aws_s3_bucket.profile_images.arn}/profile-images/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.profile_images.arn
          }
        }
      }
    ]
  })
}

# CloudFront(OAC)는 "퍼블릭" 경로가 아니라 특정 AWS 서비스 주체로 평가되므로 아래 차단과 무관하게
# 동작한다. 공개 버킷 정책 경로 자체를 완전히 막아 둔다.
resource "aws_s3_bucket_public_access_block" "profile_images" {
  bucket = data.aws_s3_bucket.profile_images.id

  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}
