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

variable "cidr_allowed_ssh" {
  description = "CIDR block from which to allow SSH connections"
  type        = string
}

variable "instance_type" {
  description = "Type of EC2 instance to start"
  type        = string
}

variable "instance_arch" {
  description = "Architecutre of EC2 instance to start"
  type        = string
}

variable "key_name" {
  description = "Name of the key pair to use when creating the instance"
  type        = string
}
