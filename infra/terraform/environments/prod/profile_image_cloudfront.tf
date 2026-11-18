# 프로필 사진 CDN. 오리진 코드가 이미 Cache-Control: public, max-age=31536000, immutable을
# 보내므로 AWS 관리형 "CachingOptimized" 정책으로 오리진 헤더를 그대로 존중한다.
locals {
  cloudfront_caching_optimized_policy_id = "658327ea-f89d-4fab-a63d-7e88639e58f6"
  # CloudFront 배포(Route53 alias record)에 쓰는 고정 호스팅존 ID
  cloudfront_hosted_zone_id = "Z2FDTNDATAQYW2"
}

resource "aws_cloudfront_distribution" "profile_images" {
  enabled         = true
  comment         = "barofit-prod profile image CDN"
  aliases         = ["img.barofit.cloud"]
  price_class     = "PriceClass_200" # 한국 포함 아시아 엣지까지, 남미 제외(비용 절감)
  is_ipv6_enabled = true

  origin {
    domain_name              = data.aws_s3_bucket.profile_images.bucket_regional_domain_name
    origin_id                = "profile-images-s3"
    origin_access_control_id = aws_cloudfront_origin_access_control.profile_images.id
  }

  default_cache_behavior {
    target_origin_id       = "profile-images-s3"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    cache_policy_id        = local.cloudfront_caching_optimized_policy_id
    compress               = true
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate_validation.profile_image.certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  tags = {
    Name = "barofit-prod-profile-images-cdn"
  }
}

resource "aws_route53_record" "profile_image_cdn" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "img.barofit.cloud"
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.profile_images.domain_name
    zone_id                = local.cloudfront_hosted_zone_id
    evaluate_target_health = false
  }
}
