output "vpc_id" {
  description = "BaroFit prod VPC ID"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "Public 서브넷 ID 목록 (2a, 2c 순)"
  value       = [for k in sort(keys(aws_subnet.public)) : aws_subnet.public[k].id]
}

output "private_subnet_ids" {
  description = "Private App 서브넷 ID 목록 (2a, 2c 순) - EKS 클러스터/노드용"
  value       = [for k in sort(keys(aws_subnet.private_app)) : aws_subnet.private_app[k].id]
}

output "private_db_subnet_ids" {
  description = "Private DB 서브넷 ID 목록 (2a, 2c 순)"
  value       = [for k in sort(keys(aws_subnet.private_db)) : aws_subnet.private_db[k].id]
}

output "db_subnet_group_name" {
  description = "RDS DB Subnet Group 이름 (RDS Terraform에서 참조)"
  value       = aws_db_subnet_group.main.name
}
