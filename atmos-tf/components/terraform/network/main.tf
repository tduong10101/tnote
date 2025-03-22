resource "aws_vpc" "main" {
  cidr_block           = var.ipv4_cidr
  enable_dns_hostnames = true
  tags = {
    Name  = var.namespace
    Stage = var.stage
  }
}

resource "aws_internet_gateway" "gateway" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name  = var.namespace
    Stage = var.stage
  }
  depends_on = [aws_vpc.main]
}

resource "aws_default_route_table" "route_table" {
  default_route_table_id = aws_vpc.main.default_route_table_id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gateway.id
  }

  tags = {
    Name  = var.namespace
    Stage = var.stage
  }
  depends_on = [aws_vpc.main]
}

resource "aws_subnet" "sn1" {
  vpc_id     = aws_vpc.main.id
  cidr_block = var.sn1_ipv4_cidr

  tags = {
    Name  = "${var.namespace}-1"
    Stage = var.stage
  }
  depends_on = [aws_vpc.main]
}

resource "aws_subnet" "sn2" {
  vpc_id     = aws_vpc.main.id
  cidr_block = var.sn2_ipv4_cidr

  tags = {
    Name  = "${var.namespace}-2"
    Stage = var.stage
  }
  depends_on = [aws_vpc.main]
}

resource "aws_subnet" "sn3" {
  vpc_id     = aws_vpc.main.id
  cidr_block = var.sn3_ipv4_cidr

  tags = {
    Name  = "${var.namespace}-3"
    Stage = var.stage
  }
  depends_on = [aws_vpc.main]
}
resource "aws_security_group" "tnote_ecs_sg" {
  name   = "${var.namespace}_ecs_sg"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}
resource "aws_security_group" "tnote_lb_sg" {
  name   = "${var.namespace}_lb_sg"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  ingress {
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

resource "aws_security_group" "tnote_db_sg" {
  name   = "${var.namespace}_db_sg"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = ["${aws_security_group.tnote_ecs_sg.id}"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}
