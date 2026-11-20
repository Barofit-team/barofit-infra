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