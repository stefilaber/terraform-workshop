/*
TERRAFORM WORKSHOP 3

Terraform uses the aws cli to authenticate to AWS
The AWS CLI must be installed and configured
the credentials are stored in ~/.aws/credentials

To execute the file using terraform:
terraform init
(terraform plan)
terraform apply

To destroy the resources:
terraform destroy

*/

terraform {
    required_providers {
        aws = {
            source  = "hashicorp/aws"
            version = "~> 4.16"
        }
    }

    required_version = ">= 1.2.0"
}
provider "aws" {
  region  = "us-east-1"
}

// VPC
// is a virtual private cloud (virtual network)
// the cidr_block is the ip range of the VPC
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}

// Internet gateway
// is a connection between the VPC and the internet
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "main"
  }
}

// Create a subnet
// is a range of ip addresses in the VPC
// the cidr_block must be a subset of the VPC cidr_block
resource "aws_subnet" "main" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.1.0/24"

  tags = {
    Name = "Main"
  }
}

// Create route table
// is a set of rules, called routes, that are used to determine where network traffic is directed
// in this case we directing the traffic from the internet to the gateway
resource "aws_route_table" "rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "rt"
  }
}

// associate route table with subnet
resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.main.id
  route_table_id = aws_route_table.rt.id
}

// create security group
// ingress (inbound) and egress (outbound) rules
resource "aws_security_group" "allow_http" {
  name        = "allow_http"
  description = "Allow HTTP inbound traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP from Internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    }
}

// create a network interface with an ip in the subnet
// a network interface is a virtual network card
resource "aws_network_interface" "main" {
  subnet_id       = aws_subnet.main.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.allow_http.id]
}

// create an elastic ip
// associate the elastic ip with the network interface
resource "aws_eip" "main" {
  network_interface = aws_network_interface.main.id
  associate_with_private_ip = aws_network_interface.main.private_ip
  depends_on = [aws_network_interface.main]
}

// creates an ec2 instance
// the user_data is a script that is executed when the instance is created
//    the script installs apache and starts it
// the ami as an ubuntu image (id looked up in aws ui)
// attach the network interface to the instance (-> attach the elastic ip)
resource "aws_instance" "app_server" {
  ami           = "ami-0fc5d935ebf8bc3bc"
  instance_type = "t2.micro"
  
  network_interface {
    network_interface_id = aws_network_interface.main.id
    device_index         = 0
  }

  tags = {
    Name = "MyAppacheServer"
  }

  user_data = "${file("user-data-apache.sh")}"

  depends_on = [aws_eip.main]
}
///////////////// 

resource "aws_network_interface" "second" {
  subnet_id       = aws_subnet.main.id
  private_ips     = ["10.0.1.51"]
  security_groups = [aws_security_group.allow_http.id]
}

resource "aws_eip" "second" {
  network_interface = aws_network_interface.second.id
  associate_with_private_ip = aws_network_interface.second.private_ip
  depends_on = [aws_network_interface.second]
}

resource "aws_instance" "app_server_1" {
  ami           = "ami-0fc5d935ebf8bc3bc"
  instance_type = "t2.micro"
  
  network_interface {
    network_interface_id = aws_network_interface.second.id
    device_index         = 0
  }

  tags = {
    Name = "MyAppacheServer1"
  }

  user_data = "${file("user-data-apache_other.sh")}"

  depends_on = [aws_eip.second]
}

# Create a new load balancer
resource "aws_elb" "bar" {
  name               = "foobar-terraform-elb"
  subnets = [aws_subnet.main.id]
  security_groups    = [aws_security_group.allow_http.id]

  listener {
    instance_port     = 80
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    target              = "HTTP:80/"
    interval            = 30
  }

  instances                   = [aws_instance.app_server.id, aws_instance.app_server_1.id]
  cross_zone_load_balancing   = true
  idle_timeout                = 400
  connection_draining         = true
  connection_draining_timeout = 400

  tags = {
    Name = "my-terraform-elb"
  }
}

# this outputs the elastic ip
output "public_ip" {
  value = aws_eip.main.public_ip
}

output "public_ip_1" {
  value = aws_eip.second.public_ip
}

output "load_balancer_ip" {
  value = aws_elb.bar.dns_name
}