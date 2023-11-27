
/*
TERRAFORM WORKSHOP 1

Terraform uses the aws cli to authenticate to AWS
The AWS CLI must be installed and configured
the credentials are stored in ~/.aws/credentials


To execute the file using terraform:
terraform init
terraform plan
terraform apply

To destroy the resources:
terraform destroy

specify the required provider and version
The provider source is "hashicorp/aws", version 4.16 
required Terraform version >= 1.2.0
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

# this block creates a default VPC
# if it exists, it will not be created but will be used
resource "aws_default_vpc" "default" {
  tags = {
    Name = "DefaultVPC"
  }
}

# this block creates a security group
# ingress block allows inbound traffic
# egress block allows outbound traffic
resource "aws_security_group" "allow_http" {
  name        = "allow_http"
  description = "Allow HTTP inbound traffic"
  vpc_id      = aws_default_vpc.default.id

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

# this block creates an EC2 instance
# the ami is the Ubuntu 22.04 LTS AMI
# the user_data block is used to install and configure Apache
resource "aws_instance" "app_server" {
  ami           = "ami-0fc5d935ebf8bc3bc"
  instance_type = "t2.micro"
  associate_public_ip_address = true
  vpc_security_group_ids = [aws_security_group.allow_http.id]

  tags = {
    Name = "MyAppacheServer"
  }

  user_data = "${file("user-data-apache.sh")}"
}

# this block outputs the public IP address of the EC2 instance
output "public_ip" {
  value = aws_instance.app_server.public_ip
}