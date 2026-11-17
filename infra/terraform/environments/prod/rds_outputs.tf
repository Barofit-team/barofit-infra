output "rds_identifier" {
  description = "생성된 RDS 인스턴스 식별자"
  value       = aws_db_instance.main.identifier
}

output "rds_endpoint" {
  description = "RDS 접속 엔드포인트 (host:port)"
  value       = aws_db_instance.main.endpoint
}

output "rds_address" {
  description = "RDS 호스트 주소"
  value       = aws_db_instance.main.address
}

output "rds_port" {
  description = "RDS 포트"
  value       = aws_db_instance.main.port
}

output "rds_db_name" {
  description = "기본 데이터베이스 이름"
  value       = aws_db_instance.main.db_name
}

output "rds_jdbc_url" {
  description = "백엔드 서비스 DB_URL 환경변수용 JDBC URL"
  value       = "jdbc:postgresql://${aws_db_instance.main.address}:${aws_db_instance.main.port}/${aws_db_instance.main.db_name}"
}

output "rds_security_group_id" {
  description = "RDS 전용 보안 그룹 ID"
  value       = aws_security_group.rds.id
}

output "rds_availability_zone" {
  description = "RDS 인스턴스가 배치된 가용 영역"
  value       = aws_db_instance.main.availability_zone
}
