# output "instance_id" {
#   description = "ID of the EC2 instance"
#   value       = aws_instance.ec2.id
# }

# output "instance_public_dns" {
#   description = "Public DNS of the EC2 instance"
#   value       = aws_instance.ec2.public_dns
# }

output "instance_id" {
  description = "ID of the EC2 instance"
  value       = aws_spot_instance_request.ec2.id
}

output "instance_public_dns" {
  description = "Public DNS of the EC2 instance"
  value       = aws_spot_instance_request.ec2.public_dns
}


output "instance_username" {
  description = "Username of the EC2 instance"
  value       = var.ami_username
}
