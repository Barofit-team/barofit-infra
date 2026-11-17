resource "aws_route53_zone" "main" {
  name = "barofit.cloud"

  tags = {
    Name = "barofit-prod-route53"
  }
}
