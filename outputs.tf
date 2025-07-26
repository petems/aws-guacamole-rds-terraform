output "guacamole_public_ip" {
  description = "Public IP address of the Guacamole server"
  value       = aws_eip.guacamole_eip.public_ip
}

output "guacamole_url" {
  description = "URL to access Guacamole"
  value       = "http://${aws_eip.guacamole_eip.public_ip}:8080/guacamole"
}

output "guacamole_server_id" {
  description = "ID of the Guacamole EC2 instance"
  value       = aws_instance.guacamole_server.id
}

output "rds_endpoint" {
  description = "RDS instance endpoint"
  value       = aws_db_instance.guacamole_db.endpoint
  sensitive   = true
}

output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.guacamole_vpc.id
}

output "ssh_command" {
  description = "SSH command to connect to the Guacamole server"
  value       = "ssh -i ~/.ssh/${var.project_name}-key ec2-user@${aws_eip.guacamole_eip.public_ip}"
}

output "network_architecture" {
  description = "Network architecture information"
  value = {
    vpc_cidr = aws_vpc.guacamole_vpc.cidr_block
    public_subnets = aws_subnet.public_subnet[*].cidr_block
    private_ec2_subnets = aws_subnet.private_ec2_subnet[*].cidr_block
    private_rds_subnets = aws_subnet.private_subnet[*].cidr_block
    nat_gateway_id = aws_nat_gateway.guacamole_nat.id
    ec2_subnet_id = aws_instance.guacamole_server.subnet_id
    rds_subnet_group = aws_db_subnet_group.guacamole_db_subnet_group.name
  }
}

output "security_notes" {
  description = "Security and network architecture notes"
  value = "EC2 instance is now in private subnet with NAT Gateway for internet access. Database communication is internal through VPC. SSH access is still available via Elastic IP."
}