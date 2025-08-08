provider "aws" {
  region = "eu-north-1"
}

# ------------------ VPC ------------------
resource "aws_vpc" "main_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = "MainVPC" }
}

# ------------------ SUBNETS ------------------
resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.main_vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "eu-north-1a"

  tags = { Name = "PublicSubnet" }
}

resource "aws_subnet" "private_subnet" {
  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "eu-north-1b"

  tags = { Name = "PrivateSubnet" }
}

# ------------------ INTERNET GATEWAY ------------------
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main_vpc.id
  tags   = { Name = "MainIGW" }
}

# ------------------ ELASTIC IP for NAT ------------------
resource "aws_eip" "nat_eip" {
  domain = "vpc"
}

# ------------------ NAT GATEWAY ------------------
resource "aws_nat_gateway" "nat_gw" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_subnet.id

  tags = { Name = "MainNAT" }

  depends_on = [aws_internet_gateway.gw]
}

# ------------------ ROUTE TABLES ------------------
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = { Name = "PublicRouteTable" }
}

resource "aws_route_table_association" "public_association" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

# Private Route Table with NAT access
resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.main_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw.id
  }

  tags = { Name = "PrivateRouteTable" }
}

resource "aws_route_table_association" "private_association" {
  subnet_id      = aws_subnet.private_subnet.id
  route_table_id = aws_route_table.private_rt.id
}

# ------------------ SECURITY GROUPS ------------------
# FRONTEND SG
resource "aws_security_group" "frontend_sg" {
  name        = "frontend-sg"
  description = "Allow HTTP and SSH"
  vpc_id      = aws_vpc.main_vpc.id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "FrontendSG" }
}

# BACKEND SG
resource "aws_security_group" "backend_sg" {
  name        = "backend-sg"
  description = "Allow internal communication"
  vpc_id      = aws_vpc.main_vpc.id

  ingress {
    description     = "Allow from frontend only"
    from_port       = 5000
    to_port         = 5000
    protocol        = "tcp"
    security_groups = [aws_security_group.frontend_sg.id]
  }

  ingress {
    description     = "SSH from frontend"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.frontend_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "BackendSG" }
}

# ------------------ EC2 INSTANCES ------------------
# FRONTEND (Public)
resource "aws_instance" "frontend" {
  ami                    = "ami-042b4708b1d05f512"
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.public_subnet.id
  vpc_security_group_ids = [aws_security_group.frontend_sg.id]
  key_name               = "satya-key-new"

  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = file("${path.module}/../keys/satya-key-new.pem")
    host        = self.public_ip
  }

  provisioner "file" {
    source      = "../scripts/frontend.sh"
    destination = "/home/ubuntu/frontend.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x frontend.sh",
      "sudo ./frontend.sh"
    ]
  }

  tags = { Name = "FrontendInstance" }
}

# BACKEND (Private with NAT)
resource "aws_instance" "backend" {
  ami                    = "ami-042b4708b1d05f512"
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.private_subnet.id
  vpc_security_group_ids = [aws_security_group.backend_sg.id]
  key_name               = "satya-key-new"

  connection {
    type                = "ssh"
    user                = "ubuntu"
    private_key         = file("${path.module}/../keys/satya-key-new.pem")
    host                = self.private_ip
    bastion_host        = aws_instance.frontend.public_ip
    bastion_user        = "ubuntu"
    bastion_private_key = file("${path.module}/../keys/satya-key-new.pem")
  }

  provisioner "file" {
    source      = "../scripts/backend.sh"
    destination = "/home/ubuntu/backend.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x backend.sh",
      "sudo ./backend.sh"
    ]
  }

  tags = { Name = "BackendInstance" }
}
