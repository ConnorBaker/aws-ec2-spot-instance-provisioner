region               = "us-east-1"
cidr_vpc             = "10.0.0.0/16"
cidr_subnet          = "10.0.0.0/24"
cidr_allowed_ssh     = "108.51.128.59/32"
instance_type        = "m6g.metal"
instance_arch        = "arm64"
key_name             = "terraform-ec2-key"
aws_credentials_path = "~/.aws/credentials"
