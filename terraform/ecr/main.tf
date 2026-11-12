terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

data "aws_caller_identity" "current" {}

locals {
  services = toset(var.services)
}

# 1. 백엔드 마이크로서비스별 ECR 프라이빗 리포지토리 생성
resource "aws_ecr_repository" "barofit" {
  for_each = local.services

  name                 = "${var.repository_prefix}-${each.key}"
  image_tag_mutability = var.image_tag_mutability
  force_delete         = var.force_delete

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
}

# 2. 스토리지 비용 최적화를 위한 ECR 수명주기 정책 (최근 N개 이미지만 유지)
resource "aws_ecr_lifecycle_policy" "barofit" {
  for_each   = aws_ecr_repository.barofit
  repository = each.value.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "최근 ${var.max_image_count}개 이미지만 유지하고 이전 이미지는 자동 만료"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = var.max_image_count
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}
