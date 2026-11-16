output "github_oidc_provider_arn" {
  description = "GitHub Actions OIDC provider ARN"
  value       = aws_iam_openid_connect_provider.github.arn
}

output "ecr_push_role_arn" {
  description = "Role ARN for GitHub Actions AWS_ECR_ROLE_ARN"
  value       = aws_iam_role.github_ecr_push.arn
}

output "allowed_github_subjects" {
  description = "Allowed GitHub repository and branch identities"
  value       = local.github_subjects
}