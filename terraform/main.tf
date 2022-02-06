terraform {
  required_version = ">= 1.1.4"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 3.74.0"
    }

    local = {
      source  = "hashicorp/local"
      version = ">= 2.1.0"
    }
  }
}

provider "aws" {
  region                  = var.region
  shared_credentials_file = file(var.aws_credentials_path)
}

data "aws_ec2_instance_type_offerings" "acceptable_azs" {
  filter {
    name   = "instance-type"
    values = [var.instance_type]
  }

  location_type = "availability-zone"
}


data "aws_availability_zones" "available_azs" {
  state = "available"

  filter {
    name   = "zone-name"
    values = var.az == null ? data.aws_ec2_instance_type_offerings.acceptable_azs.locations : [var.az]
  }
}

locals {
  chosen_az    = data.aws_availability_zones.available_azs.names[0]
  chosen_az_id = data.aws_availability_zones.available_azs.zone_ids[0]
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
  vpc_id               = aws_vpc.vpc.id
  cidr_block           = var.cidr_subnet
  availability_zone_id = local.chosen_az_id

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

data "aws_ami" "nixos" {
  most_recent = true

  filter {
    name   = "architecture"
    values = [var.instance_arch]
  }

  filter {
    name   = "name"
    values = ["NixOS-21.11*"]
  }

  owners = ["080433136561"] # NixOS
}

resource "aws_key_pair" "kp" {
  key_name   = var.key_name
  public_key = file(var.public_key_path)
}

resource "aws_instance" "ec2" {
  ami                         = data.aws_ami.nixos.id
  instance_type               = var.instance_type
  availability_zone           = local.chosen_az
  vpc_security_group_ids      = [aws_security_group.sg_terraform_ssh.id]
  subnet_id                   = aws_subnet.subnet.id
  associate_public_ip_address = true
  key_name                    = var.key_name

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
  }

  tags = {
    Name = "terraform-ec2"
  }
}
