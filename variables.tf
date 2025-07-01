variable "aws_region" {
  description = "AWS region where resources will be created"
  type        = string
  default     = "us-east-1"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC (e.g., 10.0.0.0/16)"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_1_cidr" {
  description = "CIDR block for first public subnet (for ALB and NAT Gateway)"
  type        = string
  default     = "10.0.1.0/24"
}

variable "public_subnet_2_cidr" {
  description = "CIDR block for second public subnet (for ALB high availability)"
  type        = string
  default     = "10.0.2.0/24"
}

variable "private_subnet_cidr" {
  description = "CIDR block for private subnet (for EC2 instance)"
  type        = string
  default     = "10.0.3.0/24"
}

variable "availability_zone_1" {
  description = "First availability zone for resources"
  type        = string
  default     = "us-east-1a"
}

variable "availability_zone_2" {
  description = "Second availability zone for ALB high availability"
  type        = string
  default     = "us-east-1b"
}

variable "instance_type" {
  description = "EC2 instance type for the web server"
  type        = string
  default     = "t2.micro"
}

variable "ami_id" {
  description = "AMI ID for EC2 instance (Amazon Linux 2 recommended)"
  type        = string
  default     = "ami-05ffe3c48a9991133"  # Amazon Linux 2 in us-east-1
}

variable "key_name" {
  description = "Name of the SSH key pair for EC2 instance access"
  type        = string
  default     = "deployer-key"
}

variable "public_key_path" {
  description = "Path to the public SSH key file"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

variable "enable_nat_gateway" {
  description = "Enable NAT Gateway for private subnet internet access"
  type        = bool
  default     = true
}

variable "alb_name" {
  description = "Name for the Application Load Balancer"
  type        = string
  default     = "app-gateway-alb"
}

variable "target_group_name" {
  description = "Name for the ALB target group"
  type        = string
  default     = "app-gateway-tg"
}

variable "health_check_path" {
  description = "Path for ALB health checks"
  type        = string
  default     = "/"
}

variable "health_check_port" {
  description = "Port for ALB health checks"
  type        = string
  default     = "80"
}

variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default = {
    Environment = "demo"
    Project     = "app-gateway"
    ManagedBy   = "terraform"
  }
} 