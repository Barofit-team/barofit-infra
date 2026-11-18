output "profile_image_cdn_domain" {
  description = "프로필 사진 CDN 커스텀 도메인 (identity Helm PROFILE_IMAGE_PUBLIC_BASE_URL에 사용)"
  value       = "https://${aws_route53_record.profile_image_cdn.name}"
}

output "profile_image_cloudfront_distribution_id" {
  description = "프로필 사진 CloudFront 배포 ID"
  value       = aws_cloudfront_distribution.profile_images.id
}

output "profile_image_identity_role_arn" {
  description = "identity 서비스 Pod Identity 역할 ARN"
  value       = aws_iam_role.profile_image_identity.arn
}
