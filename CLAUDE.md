# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Terraform configuration that deploys Apache Guacamole on AWS with a secure, multi-tier architecture:

- **EC2 Instance**: Runs Apache Guacamole in Docker containers (Amazon Linux 2)
- **RDS MySQL 8.0**: Database backend for authentication and connection storage
- **VPC**: Three-tier network architecture with public, private EC2, and private RDS subnets
- **NAT Gateway**: Provides internet access for private subnets
- **Security Groups**: Configured for principle of least privilege access

## Key Architecture Components

### Network Architecture
- **VPC**: Default CIDR `10.0.0.0/16` with DNS support enabled
- **Public Subnets**: 2 subnets (`10.0.0.0/24`, `10.0.1.0/24`) for NAT Gateway and external access
- **Private EC2 Subnets**: 2 subnets (`10.0.20.0/24`, `10.0.21.0/24`) for application servers
- **Private RDS Subnets**: 2 subnets (`10.0.10.0/24`, `10.0.11.0/24`) for database isolation
- **Route Tables**: Separate routing for public (IGW) and private (NAT) traffic

### Security Model
- Guacamole EC2 instance deployed in public subnet with Elastic IP
- RDS instance isolated in private subnets accessible only from Guacamole security group
- SSH access restricted via `allowed_ssh_cidrs` variable
- Web access (ports 80, 443, 8080) restricted via `user_ip_address` variable

## Essential Commands

### Terraform Operations
```bash
# Initialize Terraform
terraform init

# Validate configuration
terraform validate

# Plan deployment (with specific AWS profile)
AWS_PROFILE=ese-sandbox terraform plan

# Deploy infrastructure (with specific AWS profile)
AWS_PROFILE=ese-sandbox terraform apply

# Destroy infrastructure (with specific AWS profile)
AWS_PROFILE=ese-sandbox terraform destroy

# Format code
terraform fmt

# Show current state
terraform show

# View outputs
terraform output
```

### AWS CLI Operations
When using AWS CLI commands, always specify the region and profile:
```bash
# List RDS instances
AWS_PROFILE=ese-sandbox aws rds describe-db-instances --region us-west-2

# Get caller identity
AWS_PROFILE=ese-sandbox aws sts get-caller-identity --region us-west-2

# List EC2 instances
AWS_PROFILE=ese-sandbox aws ec2 describe-instances --region us-west-2
```

### Required Configuration
Before deployment, create `terraform.tfvars`:
```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with required values:
# - public_key (SSH key content)
# - db_password (secure password)
# - allowed_ssh_cidrs (your IP)
```

## File Structure and Responsibilities

- **main.tf**: Core infrastructure resources (VPC, EC2, RDS, networking)
- **variables.tf**: Input variable definitions with defaults
- **outputs.tf**: Output values including access URLs and network info
- **user_data.sh**: EC2 initialization script for Guacamole Docker setup
- **terraform.tfvars.example**: Template for required configuration variables

## Critical Variables

### Required (must be set in terraform.tfvars)
- `public_key`: SSH public key content for EC2 access
- `db_password`: MySQL database password (marked sensitive)
- `guacamole_admin_password`: Custom Guacamole admin password (marked sensitive)

### Security-Critical
- `allowed_ssh_cidrs`: CIDR blocks for SSH access (default: `["0.0.0.0/0"]`)
- `user_ip_address`: Your IP for web access (default: hardcoded IP)
- `guacamole_admin_username`: Custom admin username (default: `admin`)

### Infrastructure Sizing
- `instance_type`: EC2 type (default: `t3.medium`)
- `db_instance_class`: RDS type (default: `db.t3.micro`)
- `db_allocated_storage`: Initial DB storage (default: 20GB)

## Deployment Dependencies

1. AWS CLI configured with appropriate credentials
2. Terraform >= 1.0
3. SSH key pair for EC2 access
4. Network connectivity for RDS initialization

## Service Architecture

The user_data.sh script configures:
- Docker containers for Guacamole daemon (guacd) and web application
- Systemd services for container lifecycle management
- Custom MySQL schema initialization with secure admin user creation
- Database credential injection via Terraform templating
- Custom database initialization script (`guacamole_init.sql.tpl`) that replaces default schema

### Security Improvements
- **Custom Admin Credentials**: Replaces insecure default `guacadmin/guacadmin` with configurable credentials
- **Secure Password Hashing**: Uses SHA-256 with random salt generation for password storage
- **Template-based Initialization**: `guacamole_init.sql.tpl` creates complete schema with custom admin user

Access Guacamole at: `http://<elastic_ip>:8080/guacamole`
Admin credentials: Set via `guacamole_admin_username` and `guacamole_admin_password` variables

## State Management

- Terraform state files (`terraform.tfstate`) track deployed resources
- No remote state backend configured (local state only)
- State contains sensitive data (database passwords, endpoints)

## Working with Existing Infrastructure

This configuration supports two deployment modes via the `use_existing_vpc` variable:

### Using Existing VPC (Recommended for shared environments)
```hcl
use_existing_vpc = true
existing_vpc_id = "vpc-01b4f1de3f0d20efe"
existing_public_subnet_ids = ["subnet-03acb606079c59e5d"]
existing_private_subnet_ids = ["subnet-0a21e1af1b00bdd81", "subnet-0627c3c80e1bfcabb"]
```

**Important Considerations:**
- Introspect existing environment first with AWS CLI commands listed above
- Ensure public subnets have proper route table associations for internet access
- May require manual cleanup of conflicting Terraform-managed networking resources
- Test with `terraform plan` before applying to understand infrastructure changes

### Creating New VPC
```hcl
use_existing_vpc = false
vpc_cidr = "10.1.0.0/16"  # Use non-conflicting CIDR
```

## Deployment Modes

The configuration supports three deployment modes via the `deployment_mode` variable:

### Development Mode (Fast - 2-3 minutes)
```hcl
deployment_mode = "development"
```
- ⚡ **Fastest deployment**
- ❌ No backups (backup_retention_period = 0)
- ❌ No encryption (faster provisioning)
- ✅ GP3 storage (faster than GP2)
- ✅ Single-AZ (no redundancy overhead)

### Staging Mode (Balanced - 4-6 minutes)  
```hcl
deployment_mode = "staging"
```
- ⚖️ **Balanced speed vs features**
- ✅ 1-day backup retention
- ✅ Storage encryption enabled
- ✅ GP3 storage
- ✅ Single-AZ deployment

### Production Mode (Robust - 8-12 minutes)
```hcl
deployment_mode = "production"
```
- 🛡️ **Full production features**
- ✅ 7-day backup retention
- ✅ Storage encryption
- ✅ Multi-AZ deployment (high availability)
- ✅ Deletion protection enabled

### Usage
Set the deployment mode in your `terraform.tfvars`:
```hcl
deployment_mode = "development"  # Choose: development, staging, production
```

## Security Improvements

- **No Default Credentials**: Database initialization uses custom admin credentials instead of `guacadmin/guacadmin`
- **Secure Password Hashing**: SHA-256 with random salt generation prevents credential window vulnerability
- **Conditional Infrastructure**: Adapts to existing environments without unnecessary resource conflicts
- **Flexible Deployment Modes**: Choose appropriate speed vs security trade-offs for your use case

## User Management

The configuration supports multiple approaches for managing additional Guacamole users:

### Option 1: Terraform with MySQL Provider (Recommended)
Manage users declaratively with infrastructure as code:

```hcl
# In terraform.tfvars
manage_users_with_terraform = true

guacamole_users = {
  "john.doe" = {
    password    = "SecurePassword123!"
    full_name   = "John Doe"
    email       = "john.doe@company.com"
    permissions = ["CREATE_CONNECTION", "CREATE_CONNECTION_GROUP"]
  }
  "jane.smith" = {
    password    = "AnotherSecure456!"
    full_name   = "Jane Smith"
    email       = "jane.smith@company.com"
    permissions = ["CREATE_CONNECTION"]
  }
}
```

**Benefits:**
- ✅ Version controlled user management
- ✅ Secure password hashing (SHA-256 + salt)
- ✅ Automatic cleanup on destroy
- ✅ Consistent with infrastructure as code

### Option 2: Direct SQL Scripts
Use provided SQL templates for manual user creation:

```bash
# Single user creation
mysql -h <rds_endpoint> -u guacamole -p guacamole_db < scripts/add_users.sql.tpl

# Bulk user creation
./scripts/bulk_add_users.sh <rds_endpoint> guacamole <password> guacamole_db
```

**Benefits:**
- ✅ No additional Terraform providers
- ✅ Can be run independently
- ✅ Good for one-time bulk imports
- ✅ Easy to customize for specific needs

### Available Permissions
- **CREATE_CONNECTION** - Create new connections
- **CREATE_CONNECTION_GROUP** - Organize connections into groups
- **CREATE_SHARING_PROFILE** - Create screen sharing profiles
- **CREATE_USER** - Create new users (admin)
- **CREATE_USER_GROUP** - Manage user groups (admin)
- **ADMINISTER** - Full system administration

### Security Features
- **Secure password storage**: SHA-256 hashing with random salt generation
- **No plaintext passwords**: All passwords encrypted before database storage
- **Granular permissions**: Fine-grained access control per user
- **Self-management**: Users can update their own profile information