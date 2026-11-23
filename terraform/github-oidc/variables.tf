variable "aws_region" {
  type    = string
  default = "ap-northeast-2"
}

variable "aws_account_id" {
  type    = string
  default = "373514675861"
}

variable "github_organization" {
  type    = string
  default = "Barofit-team"
}

variable "services" {
  type = set(string)

  default = [
    "identity",
    "routine",
    "workout",
    "analytics",
    "report"
  ]
}

# GitHub이 신규 레포에 기본 적용하는 "불변 subject claim"(조직/레포 이름이 아니라 불변 ID를
# sub claim에 쓰는 방식) 때문에 필요하다. 레포를 지우고 같은 이름으로 다시 만들어도 과거
# 트러스트가 그대로 이어지지 않도록 막는, GitHub가 권장하는 더 안전한 방식이다.
variable "github_organization_id" {
  type    = string
  default = "338470933"
}

variable "service_repo_ids" {
  type = map(string)

  default = {
    identity  = "1451042717"
    routine   = "1451043213"
    workout   = "1451043967"
    analytics = "1451044416"
    report    = "1451044684"
  }
}