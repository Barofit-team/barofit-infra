output "aws_account_id" {
  description = "현재 사용 중인 AWS 계정 ID"
  value       = data.aws_caller_identity.current.account_id
}

output "aws_region" {
  description = "배포된 AWS 리전"
  value       = var.aws_region
}

output "ecr_registry" {
  description = "docker login 및 build-and-push.sh의 ECR_REGISTRY로 전달할 기본 레지스트리 주소"
  value       = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com"
}

output "ecr_repository_urls" {
  description = "서비스별 ECR 리포지토리 전체 URL"
  value       = { for svc, repo in aws_ecr_repository.barofit : svc => repo.repository_url }
}

output "docker_login_command" {
  description = "AWS ECR Docker 로그인 명령어"
  value       = "aws ecr get-login-password --region ${var.aws_region} | docker login --username AWS --password-stdin ${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com"
}
