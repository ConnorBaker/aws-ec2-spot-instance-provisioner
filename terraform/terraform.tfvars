region       = "us-east-1"
cidr_vpc     = "10.0.0.0/16"
cidr_subnet  = "10.0.0.0/24"
cidr_allowed = ["108.51.128.59/32", "67.174.76.24/32"]

# instance_type = "m6i.2xlarge"
# instance_arch = "x86_64"
# instance_type     = "m6g.2xlarge"
# instance_arch     = "arm64"
# ami_owners = ["137112412989"] # Amazon
# ami_names = ["al2022-ami-minimal*"] # Amazon Linux 2022
# ami_username = "ec2-user"

instance_type = "g5.4xlarge"
instance_arch = "x86_64"
ami_owners    = ["492681118881"]
ami_names     = ["NVIDIA GPU-Optimized AMI*"] # Base image for Nvidia's NGC
ami_username  = "ubuntu"

aws_key_pair_name = "terraform-ec2-key"
