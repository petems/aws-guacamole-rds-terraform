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