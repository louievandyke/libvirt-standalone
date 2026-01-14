# Get default VPC if not creating a new one
data "aws_vpc" "default" {
  count   = var.create_vpc ? 0 : 1
  default = true
}

data "aws_subnets" "default" {
  count = var.create_vpc ? 0 : 1
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default[0].id]
  }
}

# Create VPC if requested
resource "aws_vpc" "main" {
  count                = var.create_vpc ? 1 : 0
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(var.tags, {
    Name = "${var.stack_name}-vpc"
  })
}

resource "aws_internet_gateway" "main" {
  count  = var.create_vpc ? 1 : 0
  vpc_id = aws_vpc.main[0].id

  tags = merge(var.tags, {
    Name = "${var.stack_name}-igw"
  })
}

resource "aws_subnet" "main" {
  count                   = var.create_vpc ? length(var.availability_zones) : 0
  vpc_id                  = aws_vpc.main[0].id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index)
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = merge(var.tags, {
    Name = "${var.stack_name}-subnet-${count.index}"
  })
}

resource "aws_route_table" "main" {
  count  = var.create_vpc ? 1 : 0
  vpc_id = aws_vpc.main[0].id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main[0].id
  }

  tags = merge(var.tags, {
    Name = "${var.stack_name}-rt"
  })
}

resource "aws_route_table_association" "main" {
  count          = var.create_vpc ? length(var.availability_zones) : 0
  subnet_id      = aws_subnet.main[count.index].id
  route_table_id = aws_route_table.main[0].id
}

locals {
  vpc_id     = var.create_vpc ? aws_vpc.main[0].id : data.aws_vpc.default[0].id
  subnet_ids = var.create_vpc ? aws_subnet.main[*].id : data.aws_subnets.default[0].ids
}
