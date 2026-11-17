
output "ecr_registry" {
  description = "ECR registry 주소"
  value       = "${aws_ecr_repository.service["identity"].registry_id}.dkr.ecr.${local.region}.amazonaws.com"
}

output "ecr_repository_urls" {
  description = "서비스별 ECR Repository URI"
  value = {
    for service, repo in aws_ecr_repository.service :
    service => repo.repository_url
  }
}

output "ecr_repository_arns" {
  description = "서비스별 ECR Repository ARN"
  value = {
    for service, repo in aws_ecr_repository.service :
    service => repo.arn
  }
}
