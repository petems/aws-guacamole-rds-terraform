# Configure the AWS Provider
terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Data source for availability zones
data "aws_availability_zones" "available" {
  state = "available"
}

# Data source for latest Amazon Linux 2 AMI
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Data sources for existing VPC and subnets
data "aws_vpc" "existing" {
  count = var.use_existing_vpc ? 1 : 0
  id    = var.existing_vpc_id
}

data "aws_subnets" "existing_public" {
  count = var.use_existing_vpc ? 1 : 0
  filter {
    name   = "subnet-id"
    values = var.existing_public_subnet_ids
  }
}

data "aws_subnets" "existing_private" {
  count = var.use_existing_vpc ? 1 : 0
  filter {
    name   = "subnet-id"
    values = var.existing_private_subnet_ids
  }
}

# Local values to determine which VPC and subnets to use
locals {
  vpc_id             = var.use_existing_vpc ? data.aws_vpc.existing[0].id : aws_vpc.guacamole_vpc[0].id
  public_subnet_ids  = var.use_existing_vpc ? var.existing_public_subnet_ids : aws_subnet.public_subnet[*].id
  private_subnet_ids = var.use_existing_vpc ? var.existing_private_subnet_ids : aws_subnet.private_subnet[*].id
  
  # Deployment mode configurations
  deployment_configs = {
    development = {
      # Fast deployment (2-3 minutes)
      backup_retention_period = 0
      storage_encrypted       = false
      storage_type           = "gp3"
      instance_class         = var.db_instance_class  # Keep user's choice
      multi_az              = false
      deletion_protection   = false
      description           = "Fast deployment for development/testing"
    }
    staging = {
      # Balanced deployment (4-6 minutes)  
      backup_retention_period = 1
      storage_encrypted       = true
      storage_type           = "gp3"
      instance_class         = var.db_instance_class
      multi_az              = false
      deletion_protection   = false
      description           = "Balanced speed vs features for staging"
    }
    production = {
      # Robust deployment (8-12 minutes)
      backup_retention_period = 7
      storage_encrypted       = true
      storage_type           = "gp3"
      instance_class         = var.db_instance_class
      multi_az              = true
      deletion_protection   = true
      description           = "Full production features and redundancy"
    }
  }
  
  # Current deployment config
  db_config = local.deployment_configs[var.deployment_mode]
}

# Create VPC (only if not using existing)
resource "aws_vpc" "guacamole_vpc" {
  count                = var.use_existing_vpc ? 0 : 1
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

# Create Internet Gateway (only if not using existing VPC)
resource "aws_internet_gateway" "guacamole_igw" {
  count  = var.use_existing_vpc ? 0 : 1
  vpc_id = aws_vpc.guacamole_vpc[0].id

  tags = {
    Name = "${var.project_name}-igw"
  }
}

# Create public subnets (only if not using existing VPC) 
resource "aws_subnet" "public_subnet" {
  count                   = var.use_existing_vpc ? 0 : 2
  vpc_id                  = aws_vpc.guacamole_vpc[0].id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-public-subnet-${count.index + 1}"
  }
}

# Create private subnets for RDS (only if not using existing VPC)
resource "aws_subnet" "private_subnet" {
  count             = var.use_existing_vpc ? 0 : 2
  vpc_id            = aws_vpc.guacamole_vpc[0].id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 10)
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "${var.project_name}-private-subnet-${count.index + 1}"
  }
}

# Create private subnets for EC2 (only if not using existing VPC)
resource "aws_subnet" "private_ec2_subnet" {
  count             = var.use_existing_vpc ? 0 : 2
  vpc_id            = aws_vpc.guacamole_vpc[0].id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 20)
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "${var.project_name}-private-ec2-subnet-${count.index + 1}"
  }
}

# Create Elastic IP for NAT Gateway (only if not using existing VPC)
resource "aws_eip" "nat_eip" {
  count  = var.use_existing_vpc ? 0 : 1
  domain = "vpc"

  tags = {
    Name = "${var.project_name}-nat-eip"
  }

  depends_on = [aws_internet_gateway.guacamole_igw]
}

# Create NAT Gateway (only if not using existing VPC)
resource "aws_nat_gateway" "guacamole_nat" {
  count         = var.use_existing_vpc ? 0 : 1
  allocation_id = aws_eip.nat_eip[0].id
  subnet_id     = aws_subnet.public_subnet[0].id

  tags = {
    Name = "${var.project_name}-nat-gateway"
  }

  depends_on = [aws_internet_gateway.guacamole_igw]
}

# Create route table for public subnets (only if not using existing VPC)
resource "aws_route_table" "public_rt" {
  count  = var.use_existing_vpc ? 0 : 1
  vpc_id = aws_vpc.guacamole_vpc[0].id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.guacamole_igw[0].id
  }

  tags = {
    Name = "${var.project_name}-public-rt"
  }
}

# Create route table for private subnets (only if not using existing VPC)
resource "aws_route_table" "private_rt" {
  count  = var.use_existing_vpc ? 0 : 1
  vpc_id = aws_vpc.guacamole_vpc[0].id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.guacamole_nat[0].id
  }

  tags = {
    Name = "${var.project_name}-private-rt"
  }
}

# Associate public subnets with public route table (only if not using existing VPC)
resource "aws_route_table_association" "public_rta" {
  count          = var.use_existing_vpc ? 0 : 2
  subnet_id      = aws_subnet.public_subnet[count.index].id
  route_table_id = aws_route_table.public_rt[0].id
}

# Associate private EC2 subnets with private route table (only if not using existing VPC)
resource "aws_route_table_association" "private_ec2_rta" {
  count          = var.use_existing_vpc ? 0 : 2
  subnet_id      = aws_subnet.private_ec2_subnet[count.index].id
  route_table_id = aws_route_table.private_rt[0].id
}

# Note: Public subnet route table association should be managed externally
# when using existing VPC to avoid conflicts with other services

# Security group for Guacamole EC2 instance
resource "aws_security_group" "guacamole_sg" {
  name_prefix = "${var.project_name}-guacamole-"
  vpc_id      = local.vpc_id

  # HTTP access
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.user_ip_address]
  }

  # HTTPS access
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.user_ip_address]
  }

  # Guacamole default port
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = [var.user_ip_address]
  }

  # SSH access (restrict this to your IP in production)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_ssh_cidrs
  }

  # All outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-guacamole-sg"
  }
}

# Security group for RDS
resource "aws_security_group" "rds_sg" {
  name_prefix = "${var.project_name}-rds-"
  vpc_id      = local.vpc_id

  # MySQL access from Guacamole instance
  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.guacamole_sg.id]
  }

  # All outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-rds-sg"
  }
}

# DB subnet group
resource "aws_db_subnet_group" "guacamole_db_subnet_group" {
  name       = "${var.project_name}-db-subnet-group"
  subnet_ids = local.private_subnet_ids

  tags = {
    Name = "${var.project_name}-db-subnet-group"
  }
}

# RDS MySQL instance
resource "aws_db_instance" "guacamole_db" {
  identifier     = "${var.project_name}-mysql"
  engine         = "mysql"
  engine_version = "8.0"
  instance_class = var.db_instance_class

  allocated_storage     = var.db_allocated_storage
  max_allocated_storage = var.db_max_allocated_storage
  storage_type          = local.db_config.storage_type
  storage_encrypted     = local.db_config.storage_encrypted

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  db_subnet_group_name   = aws_db_subnet_group.guacamole_db_subnet_group.name

  backup_retention_period = local.db_config.backup_retention_period
  backup_window           = local.db_config.backup_retention_period > 0 ? "03:00-04:00" : null
  maintenance_window      = "sun:04:00-sun:05:00"

  multi_az               = local.db_config.multi_az
  skip_final_snapshot    = true
  deletion_protection    = local.db_config.deletion_protection

  tags = {
    Name = "${var.project_name}-mysql"
  }
}

# Key pair for EC2 instance
resource "aws_key_pair" "guacamole_key" {
  key_name   = "${var.project_name}-key"
  public_key = var.public_key
}

# EC2 instance for Guacamole
resource "aws_instance" "guacamole_server" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.guacamole_key.key_name
  vpc_security_group_ids = [aws_security_group.guacamole_sg.id]
  subnet_id              = local.public_subnet_ids[0]

  user_data = templatefile("${path.module}/user_data.sh", {
    db_host        = aws_db_instance.guacamole_db.endpoint
    db_name        = var.db_name
    db_username    = var.db_username
    db_password    = var.db_password
    admin_username = var.guacamole_admin_username
    admin_password = var.guacamole_admin_password
  })

  root_block_device {
    volume_type = "gp3"
    volume_size = 20
    encrypted   = true
  }

  tags = {
    Name = "${var.project_name}-server"
  }

  depends_on = [aws_db_instance.guacamole_db]
}

# Elastic IP for Guacamole server
resource "aws_eip" "guacamole_eip" {
  instance = aws_instance.guacamole_server.id
  domain   = "vpc"

  tags = {
    Name = "${var.project_name}-eip"
  }

  depends_on = [aws_internet_gateway.guacamole_igw]
}