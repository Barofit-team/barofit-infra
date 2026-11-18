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

# CloudFront 커스텀 도메인 인증서는 us-east-1 리전에서만 발급받을 수 있다(AWS 고정 요구사항).
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"

  default_tags {
    tags = {
      Project     = "barofit"
      Environment = "prod"
      ManagedBy   = "terraform"
    }
  }
}
