output "acm_certificate_arn" {
  description = "ACM certificate ARN for ALB HTTPS"
  value       = aws_acm_certificate.main.arn
}
