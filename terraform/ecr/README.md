# BaroFit AWS ECR Terraform 구성

바로핏 백엔드 5개 마이크로서비스(`identity`, `routine`, `workout`, `analytics`, `report`)의 AWS ECR 프라이빗 리포지토리와 이미지 수명주기 정책(Lifecycle Policy)을 생성합니다.

## 1. ECR 리포지토리 생성

```bash
cd terraform/ecr
terraform init
terraform plan
terraform apply
```

## 2. Docker ECR 로그인

`terraform apply` 완료 후 출력되는 `docker_login_command`를 실행하거나 아래 명령어를 실행합니다:

```bash
ECR_REGISTRY=$(terraform -chdir=terraform/ecr output -raw ecr_registry)
AWS_REGION=$(terraform -chdir=terraform/ecr output -raw aws_region)

aws ecr get-login-password --region "$AWS_REGION" | \
  docker login --username AWS --password-stdin "$ECR_REGISTRY"
```

## 3. 전체 백엔드 이미지 빌드 & ECR 푸시

`barofit-infra` 루트 디렉토리에서 실행합니다:

```bash
ECR_REGISTRY=$(terraform -chdir=terraform/ecr output -raw ecr_registry) \
  ./scripts/build-and-push.sh
```
