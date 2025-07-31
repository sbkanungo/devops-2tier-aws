provider "aws" {
  region = "eu-north-1"
}

resource "aws_vpc" "main_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "MainVPC"
  }
}
# PUBLIC SUBNET
resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.main_vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "ap-south-1a"

  tags = {
    Name = "PublicSubnet"
  }
}

# PRIVATE SUBNET
resource "aws_subnet" "private_subnet" {
  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "ap-south-1b"

  tags = {
    Name = "PrivateSubnet"
  }
}

# INTERNET GATEWAY
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main_vpc.id

  tags = {
    Name = "MainIGW"
  }
}

# PUBLIC ROUTE TABLE
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "PublicRouteTable"
  }
}

# Associate Route Table with Public Subnet
resource "aws_route_table_association" "public_association" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

# SECURITY GROUP FOR FRONTEND (PUBLIC)
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

  tags = {
    Name = "FrontendSG"
  }
}

# SECURITY GROUP FOR BACKEND (PRIVATE)
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

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "BackendSG"
  }
}

# SECURITY GROUP FOR FRONTEND (PUBLIC)
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

  tags = {
    Name = "FrontendSG"
  }
}

# SECURITY GROUP FOR BACKEND (PRIVATE)
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

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "BackendSG"
  }
}

# FRONTEND EC2 INSTANCE (PUBLIC)
resource "aws_instance" "frontend" {
  ami                    = "ami-042b4708b1d05f512"
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.public_subnet.id
  vpc_security_group_ids = [aws_security_group.frontend_sg.id]
  key_name               = "satya-key"

  provisioner "file" {
    source      = "../scripts/frontend.sh"
    destination = "/home/ubuntu/frontend.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x frontend.sh",
      "sudo ./frontend.sh"
    ]

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("~/.ssh/satya-key.pem")
      host        = self.public_ip
    }
  }

  tags = {
    Name = "FrontendInstance"
  }
}

# BACKEND EC2 INSTANCE (PRIVATE)
resource "aws_instance" "backend" {
  ami                    = "ami-042b4708b1d05f512"
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.private_subnet.id
  vpc_security_group_ids = [aws_security_group.backend_sg.id]
  key_name               = "satya-key"

  provisioner "file" {
    source      = "../scripts/backend.sh"
    destination = "/home/ubuntu/backend.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x backend.sh",
      "sudo ./backend.sh"
    ]

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("~/.ssh/your-keypair-name.pem")
      host        = self.private_ip
      bastion_host = aws_instance.frontend.public_ip
      bastion_user = "ubuntu"
      bastion_private_key = file("~/.ssh/satya-key.pem")
    }
  }

  tags = {
    Name = "BackendInstance"
  }
}
