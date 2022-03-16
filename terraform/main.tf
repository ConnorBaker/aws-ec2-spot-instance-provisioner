terraform {
  required_version = ">= 1.1.4"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.5"
    }

    local = {
      source  = "hashicorp/local"
      version = "~> 2.2"
    }

    tls = {
      source  = "hashicorp/tls"
      version = "~> 3.1"
    }
  }
}

provider "aws" {
  region = var.region
}

resource "aws_vpc" "vpc" {
  cidr_block           = var.cidr_vpc
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "terraform-vpc"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "terraform-igw"
  }
}

resource "aws_network_acl" "nacl" {
  vpc_id = aws_vpc.vpc.id

  ingress {
    protocol   = -1
    rule_no    = 100
    action     = "allow"
    cidr_block = var.cidr_allowed_ssh
    from_port  = 0
    to_port    = 0
  }

  egress {
    protocol   = -1
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  tags = {
    Name = "terraform-nacl"
  }
}

resource "aws_subnet" "subnet" {
  vpc_id     = aws_vpc.vpc.id
  cidr_block = var.cidr_subnet

  tags = {
    Name = "terraform-subnet"
  }
}

resource "aws_route_table" "rtb" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "terraform-rtb"
  }
}

resource "aws_route_table_association" "rta_subnet" {
  subnet_id      = aws_subnet.subnet.id
  route_table_id = aws_route_table.rtb.id

  # See:
  # https://github.com/hashicorp/terraform-provider-aws/issues/21629
  # https://github.com/hashicorp/terraform-provider-aws/issues/21683
  depends_on = [aws_subnet.subnet, aws_route_table.rtb]
}

resource "aws_security_group" "sg_terraform_ssh" {
  name   = "sg_terraform_ssh"
  vpc_id = aws_vpc.vpc.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = [var.cidr_allowed_ssh]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "sg_terraform_ssh"
  }
}

data "aws_ami" "al2022" {
  most_recent = true

  filter {
    name   = "name"
    values = ["al2022-ami-minimal*"] # Amazon Linux 2022
  }

  filter {
    name   = "architecture"
    values = [var.instance_arch]
  }

  owners = ["137112412989"] # Amazon
}

resource "tls_private_key" "pk" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "local_file" "local_pk" {
  content         = tls_private_key.pk.private_key_pem
  filename        = "pk.pem"
  file_permission = "0400"
}

resource "aws_key_pair" "kp" {
  key_name   = var.aws_key_pair_name
  public_key = tls_private_key.pk.public_key_openssh
}

resource "aws_spot_instance_request" "ec2" {
  ami                  = data.aws_ami.al2022.id
  instance_type        = var.instance_type
  wait_for_fulfillment = true

  vpc_security_group_ids      = [aws_security_group.sg_terraform_ssh.id]
  subnet_id                   = aws_subnet.subnet.id
  associate_public_ip_address = true
  key_name                    = var.aws_key_pair_name

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
  }

  tags = {
    Name = "terraform-ec2"
  }
}
