############################################
# Locals - 설계값 시트(엑셀) 기준 CIDR, 임의 변경 금지
############################################
locals {
  name_prefix = "barofit-prod"
  region      = "ap-northeast-2"

  common_tags = {
    Project     = "barofit"
    Environment = "prod"
    ManagedBy   = "terraform"
  }

  # key = AZ 접미사
  azs = {
    a = "ap-northeast-2a"
    c = "ap-northeast-2c"
  }

  public_subnet_cidrs = {
    a = "10.20.1.0/24"
    c = "10.20.2.0/24"
  }

  private_app_subnet_cidrs = {
    a = "10.20.11.0/24"
    c = "10.20.12.0/24"
  }

  private_db_subnet_cidrs = {
    a = "10.20.21.0/24"
    c = "10.20.22.0/24"
  }

  # NAT Gateway는 2a Public 서브넷에 1개만 배치
  nat_az_key = "a"
}

############################################
# Subnets
############################################
resource "aws_subnet" "public" {
  for_each = local.public_subnet_cidrs

  vpc_id            = aws_vpc.main.id
  cidr_block        = each.value
  availability_zone = local.azs[each.key]

  tags = merge(local.common_tags, {
    Name                     = "${local.name_prefix}-public-2${each.key}"
    Tier                     = "public"
    "kubernetes.io/role/elb" = "1"
  })
}

resource "aws_subnet" "private_app" {
  for_each = local.private_app_subnet_cidrs

  vpc_id            = aws_vpc.main.id
  cidr_block        = each.value
  availability_zone = local.azs[each.key]

  tags = merge(local.common_tags, {
    Name                              = "${local.name_prefix}-private-app-2${each.key}"
    Tier                              = "private-app"
    "kubernetes.io/role/internal-elb" = "1"
  })
}

resource "aws_subnet" "private_db" {
  for_each = local.private_db_subnet_cidrs

  vpc_id            = aws_vpc.main.id
  cidr_block        = each.value
  availability_zone = local.azs[each.key]

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-private-db-2${each.key}"
    Tier = "private-db"
  })
}

############################################
# Internet Gateway
############################################
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-igw"
  })
}

############################################
# NAT Gateway (1개, 2a Public) + Elastic IP
############################################
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-nat-eip-2${local.nat_az_key}"
  })

  depends_on = [aws_internet_gateway.main]
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[local.nat_az_key].id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-nat-2${local.nat_az_key}"
  })

  depends_on = [aws_internet_gateway.main]
}

############################################
# Route Tables
############################################

# Public: 0.0.0.0/0 -> IGW
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-public-rt"
  })
}

resource "aws_route" "public_default" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main.id
}

resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

# Private App: AZ별 2개, 0.0.0.0/0 -> NAT (NAT는 2a 1개 공유)
resource "aws_route_table" "private_app" {
  for_each = local.private_app_subnet_cidrs

  vpc_id = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-private-app-rt-2${each.key}"
  })
}

resource "aws_route" "private_app_default" {
  for_each = aws_route_table.private_app

  route_table_id         = each.value.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.main.id
}

resource "aws_route_table_association" "private_app" {
  for_each = aws_subnet.private_app

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private_app[each.key].id
}

# Private DB: 인터넷 기본 경로(0.0.0.0/0) 없음 - VPC local 경로만 존재
resource "aws_route_table" "private_db" {
  vpc_id = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-private-db-rt"
  })
}

resource "aws_route_table_association" "private_db" {
  for_each = aws_subnet.private_db

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private_db.id
}
