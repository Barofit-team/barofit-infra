variable "aws_region" {
  description = "ECR 리포지토리를 생성할 AWS 리전"
  type        = string
  default     = "ap-northeast-2"
}

variable "repository_prefix" {
  description = "ECR 리포지토리 이름 접두사 (예: barofit-identity)"
  type        = string
  default     = "barofit"
}

variable "services" {
  description = "ECR 리포지토리를 생성할 바로핏 백엔드 마이크로서비스 목록"
  type        = list(string)
  default = [
    "identity",
    "routine",
    "workout",
    "analytics",
    "report"
  ]
}

variable "image_tag_mutability" {
  description = "이미지 태그 덮어쓰기 허용 여부 (MUTABLE 또는 IMMUTABLE)"
  type        = string
  default     = "MUTABLE"
}

variable "force_delete" {
  description = "리포지토리 삭제 시 내부에 이미지가 남아있어도 강제 삭제할지 여부"
  type        = bool
  default     = true
}

variable "max_image_count" {
  description = "리포지토리당 보관할 최대 도커 이미지 개수 (초과분 자동 정리)"
  type        = number
  default     = 15
}
