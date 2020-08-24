provider "aws" {
  region  = "ap-south-1"
  profile = "prem"
}
# create a variable to store mysql password
variable "mysql_password" {
  type = string
}

# create a new vpc
resource "aws_vpc" "main" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "new_vpc_terraform"
  }
}
# create private subnet
resource "aws_subnet" "private" {
  depends_on = [aws_vpc.main,]
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "ap-south-1a"


  tags = {
    Name = "subnet_private"
  }
}
# create public subnet
resource "aws_subnet" "public" {
  depends_on = [aws_subnet.private,]
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.2.0/24"
  map_public_ip_on_launch = true
  availability_zone = "ap-south-1b"
  tags = {
    Name = "subnet_public"
  }
}
# create a internat gateway
resource "aws_internet_gateway" "gw" {
  depends_on = [aws_subnet.public,]
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "terraform_gateway"
  }
}
# create a routing table 
resource "aws_route_table" "r" {
depends_on =   [aws_internet_gateway.gw,]
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
  tags = {
    Name = "route_terraform"
  }
}
# associate routing tabel to public subnet
resource "aws_route_table_association" "a" {
  depends_on = [aws_route_table.r,]
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.r.id
}
# associate routing tabel to vpc
resource "aws_main_route_table_association" "a" {
  depends_on = [aws_route_table_association.a,]
  vpc_id         = aws_vpc.main.id
  route_table_id = aws_route_table.r.id
}
#create security group for wordpress instance
resource "aws_security_group" "allow_wordpress" {
  depends_on =[aws_main_route_table_association.a,]
  name        = "security_created_by_terraform_for_wordpress"
  description = "Allow TLS inbound traffic"
  vpc_id      =  aws_vpc.main.id

  ingress {
    description = "TLS from VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "TLS from VPC"
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
    Name = "terraform_wordpress_security_group"
  }
}
#Create a security group for mysql instance
resource "aws_security_group" "allow_mysql" {
  depends_on =[aws_main_route_table_association.a,]
  name        = "security_created_by_terraform_mysql"
  description = "Allow TLS inbound traffic"
  vpc_id      =  aws_vpc.main.id

  ingress {
    description = "TLS from VPC"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "TLS from VPC"
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
    Name = "terraform_mysql_security_group"
  }
}
#Launch mysql instance on aws
resource "aws_instance" "mysql" {
   depends_on = [
  aws_security_group.allow_mysql ,
     ]
  ami           = "ami-0052c21533adedad3"
  instance_type = "t2.micro"
  key_name = "mykey"
  subnet_id = aws_subnet.private.id
  security_groups = [ aws_security_group.allow_mysql.id , ]
  user_data = <<-EOT
	  #! /bin/bash
    sudo systemctl start docker
    sudo docker run --name mysql1 -e MYSQL_ROOT_PASSWORD=${var.mysql_password} -d -p 3306:3306 mysql:5.7
	EOT
  tags = {
    Name = "mysql"
  }

}
#Launch wordpress instance on aws
resource "aws_instance" "wordpress" {
   depends_on = [
  aws_instance.mysql ,aws_security_group.allow_wordpress
     ]
  ami           = "ami-0447a12f28fddb066"
  instance_type = "t2.micro"
  key_name = "mykey"
  subnet_id = aws_subnet.public.id
  security_groups = [ aws_security_group.allow_wordpress.id , ]
  user_data = <<-EOT
		#! /bin/bash
    sudo yum install docker -y
    sudo systemctl start docker
    sudo docker container run -dit -e WORDPRESS_DB_HOST=${aws_instance.mysql.private_ip}:3306 -e WORDPRESS_DB_PASSWORD=${var.mysql_password} -e WORDPRESS_DB_USER=root -p 80:80  wordpress:php7.3
  EOT
  tags = {
    Name = "wordpress"
  }

}
