# hybrid-multi-cloud-task-3
Statement: We have to create a web portal for our company with all the security as much as possible.
So, we use Wordpress software with dedicated database server.
Database should not be accessible from the outside world for security purposes.
We only need to public the WordPress to clients.
So here are the steps for proper understanding!

Steps:
1) Write a Infrastructure as code using terraform, which automatically create a VPC.

2) In that VPC we have to create 2 subnets:
    a)  public  subnet [ Accessible for Public World! ] 
    b)  private subnet [ Restricted for Public World! ]

3) Create a public facing internet gateway for connect our VPC/Network to the internet world and attach this gateway to our VPC.

4) Create  a routing table for Internet gateway so that instance can connect to outside world, update and associate it with public subnet.

5) Launch an ec2 instance which has Wordpress setup already having the security group allowing  port 80 so that our client can connect to our wordpress site.
Also attach the key to instance for further login into it.

6) Launch an ec2 instance which has MYSQL setup already with security group allowing  port 3306 in private subnet so that our wordpress vm can connect with the same.
Also attach the key with the same.

Note: Wordpress instance has to be part of public subnet so that our client can connect our site. 
mysql instance has to be part of private  subnet so that outside world can't connect to it.
# how to use this
<pre>
1. First download terraform code
2. Do some changes in code according to your requirement
   change aws profile name 
3. Run command terraform init
4. Run command terraform apply </pre>
# create  terraform code
<pre>
provider "aws" {
  region  = "ap-south-1"
  profile = "prem"  <b># change profile name</b>
}
</pre>
# create a variable to store mysql password
<pre>
variable "mysql_password" {
  type = string
}
</pre>
# create a new vpc
<pre>
resource "aws_vpc" "main" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "new_vpc_terraform"
  }
}</pre> 
# create private subnet in ap-south-1a data center of aws
<pre>
resource "aws_subnet" "private" {
  depends_on = [aws_vpc.main,]
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "ap-south-1a"


  tags = {
    Name = "subnet_private"
  }
}</pre>
# create public subnet in ap-south-1b data center of aws
<pre>
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
</pre>
# create a internat gateway
<pre>
resource "aws_internet_gateway" "gw" {
  depends_on = [aws_subnet.public,]
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "terraform_gateway"
  }
}
</pre>
# create a routing table 
<pre>
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
</pre>
# associate routing tabel to public subnet
<pre>
resource "aws_route_table_association" "a" {
  depends_on = [aws_route_table.r,]
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.r.id
}
</pre>
# associate routing tabel to vpc
<pre>
resource "aws_main_route_table_association" "a" {
  depends_on = [aws_route_table_association.a,]
  vpc_id         = aws_vpc.main.id
  route_table_id = aws_route_table.r.id
}
</pre>
# create security group for wordpress instance which allow port no 22 and 80
<pre>
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
</pre>
# Create a security group for mysql instance whic allow port no 22 and 3306
<pre>
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
</pre>
# Launch mysql instance on aws
<pre>
resource "aws_instance" "mysql" {
   depends_on = [
  aws_security_group.allow_mysql ,
     ]
  ami           = "ami-0052c21533adedad3"<b># docker is already installed in this image</b>
  instance_type = "t2.micro" 
  key_name = "mykey"
  subnet_id = aws_subnet.private.id
  security_groups = [ aws_security_group.allow_mysql.id , ]
  user_data = <<-EOT
	  #! /bin/bash
    sudo systemctl start docker <b># start docker services</b>
    sudo docker run --name mysql1 -e MYSQL_ROOT_PASSWORD=${var.mysql_password} -d -p 3306:3306 mysql:5.7<b> # launch mysql container</b>
	EOT
  tags = {
    Name = "mysql"
  }

}
</pre>
# Launch wordpress instance on aws
<pre>
resource "aws_instance" "wordpress" {
   depends_on = [
  aws_instance.mysql ,aws_security_group.allow_wordpress
     ]
  ami           = "ami-0447a12f28fddb066" <b>#aws instance image id (amazon linux 2)</b>
  instance_type = "t2.micro" <b># Instance type</b>
  key_name = "mykey"   <b># private key </b>
  subnet_id = aws_subnet.public.id 
  security_groups = [ aws_security_group.allow_wordpress.id , ]
  user_data = <<-EOT
		#! /bin/bash
    sudo yum install docker -y  <b># install docker</b> 
    sudo systemctl start docker <b># start docker service </b>
    sudo docker container run -dit -e WORDPRESS_DB_HOST=${aws_instance.mysql.private_ip}:3306 -e WORDPRESS_DB_PASSWORD=${var.mysql_password} -e WORDPRESS_DB_USER=root -p 80:80  wordpress:php7.3  <b> # launch a wordpress container image </b>
  EOT
  tags = {
    Name = "wordpress"
  }

}
</pre>
