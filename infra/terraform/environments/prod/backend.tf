terraform {
  backend "s3" {
    bucket       = "barofit-dev-tfstate-373514675861-ap-northeast-2"
    key          = "prod/infra.tfstate"
    region       = "ap-northeast-2"
    encrypt      = true
    use_lockfile = true
  }
}
