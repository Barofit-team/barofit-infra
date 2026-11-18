# CloudFront(프로필 사진 CDN)용 인증서. CloudFront 커스텀 도메인은 us-east-1 인증서만 받아준다
# (acm.tf의 ALB용 인증서와 별개 — 리전이 달라 같은 인증서를 재사용할 수 없다).
resource "aws_acm_certificate" "profile_image" {
  provider = aws.us_east_1

  domain_name       = "img.barofit.cloud"
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "barofit-prod-profile-image-certificate"
  }
}

resource "aws_route53_record" "profile_image_acm_validation" {
  for_each = {
    for dvo in aws_acm_certificate.profile_image.domain_validation_options :
    dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  zone_id = aws_route53_zone.main.zone_id
  name    = each.value.name
  type    = each.value.type
  records = [each.value.record]
  ttl     = 60
}

resource "aws_acm_certificate_validation" "profile_image" {
  provider = aws.us_east_1

  certificate_arn = aws_acm_certificate.profile_image.arn

  validation_record_fqdns = [
    for record in aws_route53_record.profile_image_acm_validation :
    record.fqdn
  ]
}
