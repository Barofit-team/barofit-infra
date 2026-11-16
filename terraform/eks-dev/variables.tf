variable "aws_region" {
  type    = string
  default = "ap-northeast-2"
}

variable "aws_account_id" {
  type    = string
  default = "373514675861"
}

variable "cluster_name" {
  type    = string
  default = "barofit-dev"
}

variable "vpc_cidr" {
  type    = string
  default = "10.42.0.0/16"
}

variable "node_instance_type" {
  type    = string
  default = "t3.medium"
}

variable "node_desired_size" {
  type    = number
  default = 2
}