
# 기존 ECR Repository 5개를 Prod Terraform에서 관리
# 기존 Repository 이름과 Lifecycle Policy 유지

provider "aws" {
  alias               = "ecr"
  region              = local.region
  allowed_account_ids = ["373514675861"]
}

locals {
  ecr_services = toset([
    "identity",
    "routine",
    "workout",
    "analytics",
    "report"
  ])

  ecr_max_image_count = 15
}

resource "aws_ecr_repository" "service" {
  provider = aws.ecr
  for_each = local.ecr_services

  name                 = "barofit-${each.key}"
  image_tag_mutability = "MUTABLE"
  force_delete         = false

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Project   = "barofit"
    Service   = each.key
    ManagedBy = "terraform"
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_ecr_lifecycle_policy" "service" {
  provider = aws.ecr
  for_each = aws_ecr_repository.service

  repository = each.value.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "최근 ${local.ecr_max_image_count}개 이미지만 유지하고 이전 이미지는 자동 만료"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = local.ecr_max_image_count
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}
