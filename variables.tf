variable "region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "availability_zones" {
  description = "List of AZs to use (must have at least 2)"
  type        = list(string)
  default     = []
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnets" {
  description = "List of public subnets CIDRs"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnets" {
  description = "List of private subnets CIDRs"
  type        = list(string)
  default     = ["10.0.3.0/24", "10.0.4.0/24"]
}

variable "bastion_instance_type" {
  description = "Instance type for bastion host"
  type        = string
  default     = "t3.micro"
}

variable "web_instance_type" {
  description = "Instance type for web servers"
  type        = string
  default     = "t3.micro"
}

variable "db_instance_type" {
  description = "Instance type for db server"
  type        = string
  default     = "t3.small"
}

variable "key_pair_name" {
  description = "Existing EC2 Key Pair name to use for SSH"
  type        = string
  default     = ""
}

variable "my_ip" {
  description = "Your public IP in CIDR notation (for bastion SSH access), e.g. 1.2.3.4/32"
  type        = string
  default     = ""
}

variable "create_key_pair" {
  description = "If true, Terraform will try to import/create a key pair resource from local public key file"
  type        = bool
  default     = false
}

variable "public_key_path" {
  description = "Local public key path used by aws_key_pair when create_key_pair is true"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}
