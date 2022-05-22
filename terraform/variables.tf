variable "region" {
  description = "The region in which Terraform deploys your instance"
  type        = string
}

variable "az" {
  description = "The availability in which Terraform deploys your instance"
  type        = string
  default     = null
}

variable "cidr_vpc" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "cidr_subnet" {
  description = "CIDR block for the subnet"
  type        = string
  default     = "10.0.0.0/24"
}

variable "cidr_allowed" {
  description = "CIDR block from which to allow traffic"
  type        = list(string)
}

variable "instance_type" {
  description = "Type of EC2 instance to start"
  type        = string
}

variable "instance_arch" {
  description = "Architecutre of EC2 instance to start"
  type        = string
}

variable "ami_owners" {
  description = "AMI owners"
  type        = list(string)
}

variable "ami_names" {
  description = "AMI names"
  type        = list(string)
}

variable "ami_username" {
  description = "AMI username"
  type        = string
}

variable "aws_key_pair_name" {
  description = "Name of the RSA 2048 bit key pair to create"
  type        = string
}
