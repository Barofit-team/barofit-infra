############################################
# S3 Gateway VPC Endpoint
# - Private App Route Table 2개에만 연결 (Public/DB RT에는 연결하지 않음)
############################################
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${local.region}.s3"
  vpc_endpoint_type = "Gateway"

  route_table_ids = [
    for k in sort(keys(aws_route_table.private_app)) : aws_route_table.private_app[k].id
  ]

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-s3-gateway-endpoint"
  })
}
