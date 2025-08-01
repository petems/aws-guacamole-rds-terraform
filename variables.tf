variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-west-2"
}

variable "use_existing_vpc" {
  description = "Whether to use existing VPC and subnets instead of creating new ones"
  type        = bool
  default     = true
}

variable "existing_vpc_id" {
  description = "ID of existing VPC to use (when use_existing_vpc is true)"
  type        = string
  default     = "vpc-01b4f1de3f0d20efe"
}

variable "existing_public_subnet_ids" {
  description = "List of existing public subnet IDs to use"
  type        = list(string)
  default     = ["subnet-03acb606079c59e5d"]
}

variable "existing_private_subnet_ids" {
  description = "List of existing private subnet IDs for RDS"
  type        = list(string)
  default     = ["subnet-0a21e1af1b00bdd81", "subnet-0627c3c80e1bfcabb"]
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "guacamole"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.medium"
}

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "db_allocated_storage" {
  description = "The allocated storage in gigabytes"
  type        = number
  default     = 20
}

variable "db_max_allocated_storage" {
  description = "The upper limit to which Amazon RDS can automatically scale the storage"
  type        = number
  default     = 100
}

variable "db_name" {
  description = "The name of the database"
  type        = string
  default     = "guacamole_db"
}

variable "db_username" {
  description = "Username for the master DB user"
  type        = string
  default     = "guacamole"
}

variable "db_password" {
  description = "Password for the master DB user"
  type        = string
  sensitive   = true
}

variable "public_key" {
  description = "Public key for EC2 key pair"
  type        = string
  default     = ""
}

variable "allowed_ssh_cidrs" {
  description = "List of CIDR blocks allowed for SSH access"
  type        = list(string)
  default     = ["0.0.0.0/0"] # Change this to your IP for security
}

variable "user_ip_address" {
  description = "Your current IP address for restricted access"
  type        = string
  default     = "141.0.149.124/32"
}

variable "guacamole_admin_username" {
  description = "Custom admin username for Guacamole (replaces default 'guacadmin')"
  type        = string
  default     = "admin"
}

variable "guacamole_admin_password" {
  description = "Custom admin password for Guacamole (replaces default 'guacadmin')"
  type        = string
  sensitive   = true
}

variable "deployment_mode" {
  description = "Deployment mode: 'development' (fast), 'staging' (balanced), or 'production' (robust)"
  type        = string
  default     = "development"
  validation {
    condition     = contains(["development", "staging", "production"], var.deployment_mode)
    error_message = "Deployment mode must be 'development', 'staging', or 'production'."
  }
}

variable "guacamole_users" {
  description = "Map of additional Guacamole users to create"
  type = map(object({
    password    = string
    full_name   = optional(string, "")
    email       = optional(string, "")
    permissions = optional(list(string), ["CREATE_CONNECTION"])
  }))
  default = {}
  sensitive = true
}

variable "manage_users_with_terraform" {
  description = "Whether to manage additional users with Terraform (requires MySQL provider)"
  type        = bool
  default     = false
}