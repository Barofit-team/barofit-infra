provider "aws" {
  region = "ap-northeast-2"

  default_tags {
    tags = {
      Project     = "barofit"
      Environment = "prod"
      ManagedBy   = "terraform"
    }
  }
}
