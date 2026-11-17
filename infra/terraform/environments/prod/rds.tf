############################################
# RDS PostgreSQL (Single-AZ 기본, 추후 Multi-AZ 전환 가능)
# - 기존 vpc.tf (aws_vpc.main) 및 rds_subnet_group.tf (aws_db_subnet_group.main) 참조
############################################

locals {
  rds_identifier = coalesce(var.rds_identifier, "${local.name_prefix}-postgres")
  rds_effective_cidr_blocks = var.rds_allowed_cidr_blocks != null ? var.rds_allowed_cidr_blocks : [
    for k in sort(keys(aws_subnet.private_app)) : aws_subnet.private_app[k].cidr_block
  ]
}

resource "aws_security_group" "rds" {
  name        = "${local.rds_identifier}-sg"
  description = "Security group for BaroFit prod RDS PostgreSQL"
  vpc_id      = aws_vpc.main.id

  dynamic "ingress" {
    for_each = length(local.rds_effective_cidr_blocks) > 0 ? [1] : []
    content {
      description = "PostgreSQL access from allowed private-app subnets"
      from_port   = 5432
      to_port     = 5432
      protocol    = "tcp"
      cidr_blocks = local.rds_effective_cidr_blocks
    }
  }

  dynamic "ingress" {
    for_each = toset(var.rds_allowed_security_group_ids)
    content {
      description     = "PostgreSQL access from allowed security groups"
      from_port       = 5432
      to_port         = 5432
      protocol        = "tcp"
      security_groups = [ingress.value]
    }
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${local.rds_identifier}-sg"
  })
}

resource "aws_db_instance" "main" {
  identifier = local.rds_identifier

  engine         = "postgres"
  engine_version = var.rds_engine_version
  instance_class = var.rds_instance_class

  allocated_storage     = var.rds_allocated_storage
  max_allocated_storage = var.rds_max_allocated_storage
  storage_type          = "gp3"
  storage_encrypted     = true

  db_name  = var.rds_db_name
  username = var.rds_username
  password = var.rds_password
  port     = 5432

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false

  multi_az          = var.rds_multi_az
  availability_zone = var.rds_multi_az ? null : var.rds_availability_zone

  backup_retention_period   = var.rds_backup_retention_period
  deletion_protection       = var.rds_deletion_protection
  skip_final_snapshot       = var.rds_skip_final_snapshot
  final_snapshot_identifier = var.rds_skip_final_snapshot ? null : "${local.rds_identifier}-final-snapshot"
  apply_immediately         = var.rds_apply_immediately

  tags = merge(local.common_tags, {
    Name = local.rds_identifier
  })
}
