output "ec2_public_ip" {
  description = "Elastic Public IP"
  value       = aws_eip.eip_1.public_ip
}

output "ec2_instance_id" {
  description = "EC2 Instance ID"
  value       = aws_instance.ec2_1.id
}

output "security_group_id" {
  description = "Security Group ID"
  value       = aws_security_group.sg_1.id
}

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.vpc_1.id
}

output "ssh_command" {
  description = "Quick SSH command"
  value       = "ssh ec2-user@${aws_eip.eip_1.public_ip}"
}
