variable "rds_identifier" {
  description = "RDS 인스턴스 식별자 (null이면 barofit-prod-postgres)"
  type        = string
  default     = null
}

variable "rds_engine_version" {
  description = "PostgreSQL 엔진 버전 (메이저 버전 지정 시 해당 최신 마이너 버전 선택)"
  type        = string
  default     = "16"
}

variable "rds_instance_class" {
  description = "RDS 인스턴스 사양"
  type        = string
  default     = "db.t4g.micro"
}

variable "rds_allocated_storage" {
  description = "초기 스토리지 용량 (GB)"
  type        = number
  default     = 20
}

variable "rds_max_allocated_storage" {
  description = "스토리지 자동 확장 최대 용량 (GB, 0이면 비활성화)"
  type        = number
  default     = 100
}

variable "rds_db_name" {
  description = "초기 생성 데이터베이스 이름"
  type        = string
  default     = "barofit"
}

variable "rds_username" {
  description = "마스터 DB 사용자명"
  type        = string
  default     = "postgres"
}

variable "rds_password" {
  description = "마스터 DB 비밀번호 (TF_VAR_rds_password 또는 terraform.tfvars로 주입)"
  type        = string
  sensitive   = true
}

variable "rds_multi_az" {
  description = "Multi-AZ 이중화 활성화 여부 (false면 Single-AZ)"
  type        = bool
  default     = false
}

variable "rds_availability_zone" {
  description = "Single-AZ 배포 시 배치할 가용 영역 (null이면 서브넷 그룹 내 자동 선택)"
  type        = string
  default     = "ap-northeast-2a"
}

variable "rds_allowed_cidr_blocks" {
  description = "RDS 5432 포트 접근 허용 CIDR 목록 (null이면 private_app 서브넷 CIDR 자동 사용, []면 비활성화)"
  type        = list(string)
  default     = null
}

variable "rds_allowed_security_group_ids" {
  description = "RDS 5432 포트 접근을 허용할 추가 보안 그룹 ID 목록 (예: EKS 노드 SG)"
  type        = list(string)
  default     = []
}

variable "rds_backup_retention_period" {
  description = "자동 백업 보관 일수 (AWS 프리티어 계정은 최대 1일, 일반 계정은 0~35일)"
  type        = number
  default     = 1
}

variable "rds_deletion_protection" {
  description = "RDS 삭제 방지 활성화 여부"
  type        = bool
  default     = false
}

variable "rds_skip_final_snapshot" {
  description = "RDS 삭제 시 최종 스냅샷 생략 여부 (운영 전환 시 false 권장)"
  type        = bool
  default     = true
}

variable "rds_apply_immediately" {
  description = "변경 사항 즉시 적용 여부 (false면 유지보수 시간대에 적용)"
  type        = bool
  default     = true
}
