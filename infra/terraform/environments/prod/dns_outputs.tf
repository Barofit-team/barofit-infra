output "route53_zone_id" {
  description = "Route 53 public hosted zone ID"
  value       = aws_route53_zone.main.zone_id
}

output "route53_name_servers" {
  description = "Route 53 authoritative name servers"
  value       = aws_route53_zone.main.name_servers
}
