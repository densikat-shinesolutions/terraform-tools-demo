resource "aws_vpc" "main" {
  cidr_block       = var.base_cidr_block

  tags = {
    Name = "${var.stack_name}-${var.environment}"
  }
}

resource "aws_subnet" "main-subnet" {
  vpc_id            = aws_vpc.main.id
  availability_zone = var.availability_zone
  cidr_block        = var.base_cidr_block
  tags = {
    Name = "${var.stack_name}-${var.environment}-subnet"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.stack_name}-${var.environment}-igw"
  }
}

resource "aws_route_table" "rtb" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "${var.stack_name}-${var.environment}-rtb"
  }
}

resource "aws_main_route_table_association" "rtb-assoc" {
  vpc_id         = aws_vpc.main.id
  route_table_id = aws_route_table.rtb.id
}
