############################################
# RDS DB Subnet Group (Private DB 2a/2c)
# - RDS 인스턴스는 여기서 생성하지 않음 (태현님 RDS Terraform 담당)
############################################
resource "aws_db_subnet_group" "main" {
  name        = "${local.name_prefix}-db-subnet-group"
  description = "BaroFit prod RDS subnet group (private DB subnets 2a/2c)"

  subnet_ids = [
    for k in sort(keys(aws_subnet.private_db)) : aws_subnet.private_db[k].id
  ]

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-db-subnet-group"
  })
}
