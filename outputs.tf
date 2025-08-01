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
  value       = local.vpc_id
}

output "ssh_command" {
  description = "SSH command to connect to the Guacamole server"
  value       = "ssh -i ~/.ssh/${var.project_name}-key ec2-user@${aws_eip.guacamole_eip.public_ip}"
}

output "network_architecture" {
  description = "Network architecture information"
  value = {
    vpc_id              = local.vpc_id
    use_existing_vpc    = var.use_existing_vpc
    public_subnet_ids   = local.public_subnet_ids
    private_subnet_ids  = local.private_subnet_ids
    ec2_subnet_id       = aws_instance.guacamole_server.subnet_id
    rds_subnet_group    = aws_db_subnet_group.guacamole_db_subnet_group.name
  }
}

output "security_notes" {
  description = "Security and network architecture notes"
  value       = "EC2 instance is now in private subnet with NAT Gateway for internet access. Database communication is internal through VPC. SSH access is still available via Elastic IP."
}