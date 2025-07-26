# Apache Guacamole Terraform Deployment

This Terraform configuration deploys Apache Guacamole on AWS with the following architecture:

- **EC2 Instance**: Runs Apache Guacamole in Docker containers
- **RDS MySQL**: Database backend for Guacamole authentication and connection storage
- **VPC**: Dedicated network with public and private subnets
- **Security Groups**: Configured for secure access
- **Elastic IP**: Static IP for the Guacamole server

## Architecture

```
Internet Gateway
        |
    Public Subnet (Guacamole EC2)
        |
    Private Subnet (RDS MySQL)
```

## Prerequisites

1. **AWS CLI configured** with appropriate credentials
2. **Terraform installed** (version >= 1.0)
3. **SSH key pair** for EC2 access

## Quick Start

1. **Clone or download the configuration files**

2. **Generate SSH key pair** (if you don't have one):
   ```bash
   ssh-keygen -t rsa -b 4096 -f ~/.ssh/guacamole-key
   ```

3. **Create terraform.tfvars file** from the example:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```

4. **Edit terraform.tfvars** with your values:
   ```hcl
   # Required: Add your SSH public key
   public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAA... your-public-key-content"
   
   # Required: Change the database password
   db_password = "YourSecurePassword123!"
   
   # Recommended: Restrict SSH access to your IP
   allowed_ssh_cidrs = ["YOUR.IP.ADDRESS.HERE/32"]
   
   # Optional: Customize other values
   aws_region = "us-west-2"
   project_name = "guacamole"
   instance_type = "t3.medium"
   ```

5. **Initialize and deploy**:
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

6. **Access Guacamole**:
   - The deployment will output the Guacamole URL
   - Default credentials: `guacadmin` / `guacadmin`
   - **Important**: Change the default password immediately after first login

## Configuration Variables

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `aws_region` | AWS region for deployment | `us-west-2` | No |
| `project_name` | Project name (used in resource naming) | `guacamole` | No |
| `vpc_cidr` | CIDR block for the VPC | `10.0.0.0/16` | No |
| `instance_type` | EC2 instance type | `t3.medium` | No |
| `db_instance_class` | RDS instance class | `db.t3.micro` | No |
| `db_allocated_storage` | RDS storage in GB | `20` | No |
| `db_max_allocated_storage` | RDS max auto-scaling storage | `100` | No |
| `db_name` | Database name | `guacamole_db` | No |
| `db_username` | Database username | `guacamole` | No |
| `db_password` | Database password | `GuacamolePassword123!` | **Yes** |
| `public_key` | SSH public key for EC2 access | `""` | **Yes** |
| `allowed_ssh_cidrs` | CIDR blocks allowed for SSH | `["0.0.0.0/0"]` | No |

## Outputs

After successful deployment, Terraform will output:

- `guacamole_public_ip`: Public IP address of the server
- `guacamole_url`: Direct URL to access Guacamole
- `ssh_command`: SSH command to connect to the server

## Security Considerations

1. **Change default password**: The default Guacamole credentials are `guacadmin/guacadmin`
2. **Restrict SSH access**: Update `allowed_ssh_cidrs` to your specific IP address
3. **Use strong database password**: Change the default database password
4. **Enable HTTPS**: Consider setting up SSL/TLS certificates for production use
5. **Regular updates**: Keep the system and Docker images updated

## Post-Deployment Steps

1. **Access Guacamole** using the provided URL
2. **Login** with default credentials (`guacadmin` / `guacadmin`)
3. **Change the admin password** immediately
4. **Create users and connections** as needed
5. **Configure your remote desktop connections** (RDP, VNC, SSH)

## Connecting Remote Machines

To connect remote machines through Guacamole:

1. **Login to Guacamole** web interface
2. **Go to Settings** > **Connections**
3. **Create new connection** with details:
   - **Name**: Descriptive name for the connection
   - **Protocol**: RDP, VNC, SSH, or Telnet
   - **Hostname**: IP address of the target machine
   - **Port**: Protocol-specific port (3389 for RDP, 5901 for VNC, 22 for SSH)
   - **Username/Password**: Credentials for the target machine

## Troubleshooting

### Guacamole not accessible
- Check security group rules
- Verify EC2 instance is running
- Check Docker containers: `docker ps`

### Database connection issues
- Verify RDS instance is running
- Check security group allows MySQL traffic from EC2
- Test database connectivity from EC2

### SSH access issues
- Verify your IP is in `allowed_ssh_cidrs`
- Check that you're using the correct private key
- Ensure security group allows SSH (port 22)

## Cost Optimization

- **Instance type**: Use smaller instances for testing (`t3.small` or `t3.micro`)
- **RDS class**: Use `db.t3.micro` for development/testing
- **Storage**: Start with minimal storage and let auto-scaling handle growth
- **Scheduling**: Consider stopping instances during non-business hours

## Cleanup

To destroy the infrastructure:

```bash
terraform destroy
```

**Warning**: This will permanently delete all resources and data.

## Support

For issues related to:
- **Terraform configuration**: Check the Terraform documentation
- **Apache Guacamole**: Visit [Apache Guacamole documentation](https://guacamole.apache.org/doc/gug/)
- **AWS services**: Consult AWS documentation

## License

This Terraform configuration is provided as-is. Apache Guacamole is licensed under the Apache License 2.0.