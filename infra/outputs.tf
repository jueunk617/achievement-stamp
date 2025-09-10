output "vpc_id" {
  value = aws_vpc.vpc_1.id
}

output "security_group_id" {
  value = aws_security_group.sg_1.id
}

output "instance_id" {
  value = aws_instance.ec2_1.id
}

output "instance_public_ip" {
  value = aws_instance.ec2_1.public_ip
}

output "ssm_connect_command" {
  value = "aws ssm start-session --target ${aws_instance.ec2_1.id} --region ${var.region}"
}
