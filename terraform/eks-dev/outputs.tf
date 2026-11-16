output "cluster_name" {
  value = aws_eks_cluster.barofit.name
}

output "vpc_id" {
  value = aws_vpc.barofit.id
}

output "private_subnet_ids" {
  value = aws_subnet.private[*].id
}

output "public_subnet_ids" {
  value = aws_subnet.public[*].id
}