# ------------------------
# General Configuration
# ------------------------
variable "region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-2"
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "StampPop"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
  
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "prefix" {
  description = "Prefix for all resource names"
  type        = string
  default     = "stamppop"
}

# ------------------------
# Networking Configuration
# ------------------------
variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "List of public subnet CIDR blocks"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "List of private subnet CIDR blocks"
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.11.0/24"]
}

variable "enable_nat_gateway" {
  description = "Whether to create NAT Gateway for private subnets"
  type        = bool
  default     = false
}

# ------------------------
# Security Configuration
# ------------------------
variable "restrict_ssh_access" {
  description = "Restrict SSH access to current public IP"
  type        = bool
  default     = true
}

variable "restrict_admin_access" {
  description = "Restrict admin panel access to current public IP"
  type        = bool
  default     = true
}

variable "ssh_public_key" {
  description = "Public SSH key for EC2 access (optional)"
  type        = string
  default     = ""
}

# ------------------------
# EC2 Configuration
# ------------------------
variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "root_volume_size" {
  description = "Size of the root EBS volume in GB"
  type        = number
  default     = 30
}

# ------------------------
# Application Configuration
# ------------------------
variable "app_domain" {
  description = "Application domain name"
  type        = string
  default     = "api.stamppop.shop"
}

# ------------------------
# S3 Configuration
# ------------------------
variable "create_s3_bucket" {
  description = "Whether to create S3 bucket for app storage"
  type        = bool
  default     = false
}

variable "s3_bucket_name" {
  description = "Name of S3 bucket for app storage"
  type        = string
  default     = "stamppop-app-storage"
}