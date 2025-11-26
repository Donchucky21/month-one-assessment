terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.0"
    }
  }
  required_version = ">= 1.0"
}

provider "aws" {
  region = var.region
}

# Fetch the AZs if not provided
data "aws_availability_zones" "available" {}

locals {
  azs = length(var.availability_zones) >= 2 ? var.availability_zones : slice(data.aws_availability_zones.available.names, 0, 2)
}

# Amazon Linux 2 AMI
data "aws_ami" "amazon_linux2" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-ebs"]
  }
}

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = {
    Name = "techcorp-vpc"
  }
}

# Public subnets
resource "aws_subnet" "public" {
  for_each = { for idx, cidr in var.public_subnets : idx => cidr }
  vpc_id                  = aws_vpc.this.id
  cidr_block              = each.value
  availability_zone       = local.azs[tonumber(each.key)]
  map_public_ip_on_launch = true
  tags = {
    Name = "techcorp-public-subnet-${tonumber(each.key) + 1}"
  }
}

# Private subnets
resource "aws_subnet" "private" {
  for_each = { for idx, cidr in var.private_subnets : idx => cidr }
  vpc_id            = aws_vpc.this.id
  cidr_block        = each.value
  availability_zone = local.azs[tonumber(each.key)]
  tags = {
    Name = "techcorp-private-subnet-${tonumber(each.key) + 1}"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.this.id
  tags = {
    Name = "techcorp-igw"
  }
}

# Public route table -> IGW
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = { Name = "techcorp-public-rt" }
}

# Associate public subnets to public RT
resource "aws_route_table_association" "public_asg" {
  for_each = aws_subnet.public
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

# Elastic IPs for NAT gateways
resource "aws_eip" "nat" {
  for_each = aws_subnet.public
  domain = "vpc"
  tags = {
    Name = "nat-eip-${each.key}"
  }
}

# NAT Gateways (one per public subnet)
resource "aws_nat_gateway" "nat" {
  for_each = aws_subnet.public
  allocation_id = aws_eip.nat[each.key].id
  subnet_id     = each.value.id
  tags = {
    Name = "nat-gw-${each.key}"
  }
  depends_on = [aws_internet_gateway.igw]
}

# Private route tables (one per AZ) THAT route 0.0.0.0/0 to the NAT Gateway in the same AZ
resource "aws_route_table" "private" {
  for_each = aws_subnet.private
  vpc_id = aws_vpc.this.id
  route {
    cidr_block = "0.0.0.0/0"
    # find nat gateway with same AZ index
    nat_gateway_id = aws_nat_gateway.nat[each.key].id
  }
  tags = { Name = "techcorp-private-rt-${each.key}" }
}

# Associate private subnets to their private RT
resource "aws_route_table_association" "private_asg" {
  for_each = aws_subnet.private
  subnet_id      = each.value.id
  route_table_id = aws_route_table.private[each.key].id
}

# Optional: create key pair from local public key
resource "aws_key_pair" "default" {
  count      = var.create_key_pair ? 1 : 0
  key_name   = var.key_pair_name != "" ? var.key_pair_name : "techcorp-key"
  public_key = file(var.public_key_path)
}

# Security groups
resource "aws_security_group" "bastion_sg" {
  name        = "techcorp-bastion-sg"
  description = "Allow SSH from my IP"
  vpc_id      = aws_vpc.this.id

  ingress {
    description      = "SSH from my IP"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = [var.my_ip]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "web_sg" {
  name        = "techcorp-web-sg"
  description = "Allow HTTP/HTTPS from anywhere and SSH from bastion"
  vpc_id      = aws_vpc.this.id

  ingress {
    description = "http"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "https"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # SSH from bastion SG (self reference via id)
  ingress {
    description       = "SSH from bastion"
    from_port         = 22
    to_port           = 22
    protocol          = "tcp"
    security_groups   = [aws_security_group.bastion_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "db_sg" {
  name        = "techcorp-db-sg"
  description = "Allow Postgres only from web SG and SSH from bastion"
  vpc_id      = aws_vpc.this.id

  # Postgres access from web SG
  ingress {
    description     = "Postgres from web"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.web_sg.id]
  }

  # SSH from bastion
  ingress {
    description       = "SSH from bastion"
    from_port         = 22
    to_port           = 22
    protocol          = "tcp"
    security_groups   = [aws_security_group.bastion_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Key name used by instances (prefer explicit var key or created aws_key_pair)
locals {
  effective_key_name = var.key_pair_name != "" ? var.key_pair_name : (var.create_key_pair ? aws_key_pair.default[0].key_name : "")
}

# Elastic IP for Bastion
resource "aws_eip" "bastion_eip" {
  domain = "vpc"
  depends_on = [aws_internet_gateway.igw]
  tags = { Name = "bastion-eip" }
}

# Bastion EC2
resource "aws_instance" "bastion" {
  ami                         = data.aws_ami.amazon_linux2.id
  instance_type               = var.bastion_instance_type
  subnet_id                   = aws_subnet.public[0].id
  vpc_security_group_ids      = [aws_security_group.bastion_sg.id]
  associate_public_ip_address = true
  key_name                    = local.effective_key_name
  tags = { Name = "techcorp-bastion" }

  provisioner "local-exec" {
    when    = destroy
    command = "echo 'Destroying bastion'"
  }
}

# Attach EIP to bastion
resource "aws_eip_association" "bastion_assoc" {
  instance_id   = aws_instance.bastion.id
  allocation_id = aws_eip.bastion_eip.id
}

# Web servers: create 2 instances, one per private subnet
resource "aws_instance" "web" {
  count         = 2
  ami           = data.aws_ami.amazon_linux2.id
  instance_type = var.web_instance_type
  subnet_id     = aws_subnet.private[tostring(count.index)].id
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  key_name      = local.effective_key_name
  user_data     = file("${path.module}/user_data/web_server_setup.sh")
  tags = {
    Name = "techcorp-web-${count.index + 1}"
  }
}

# DB server
resource "aws_instance" "db" {
  ami           = data.aws_ami.amazon_linux2.id
  instance_type = var.db_instance_type
  subnet_id     = aws_subnet.private[0].id
  vpc_security_group_ids = [aws_security_group.db_sg.id]
  key_name      = local.effective_key_name
  user_data     = file("${path.module}/user_data/db_server_setup.sh")
  tags = {
    Name = "techcorp-db"
  }
}

# ALB
resource "aws_lb" "alb" {
  name               = "techcorp-alb"
  load_balancer_type = "application"
  subnets            = [for s in aws_subnet.public : s.id]
  security_groups    = [aws_security_group.web_sg.id]
  tags = { Name = "techcorp-alb" }
}

# Target group (instance target type)
resource "aws_lb_target_group" "web_tg" {
  name        = "techcorp-web-tg"
  port        = 80
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = aws_vpc.this.id

  health_check {
    path                = "/"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = { Name = "techcorp-web-tg" }
}

# Attach web instances to target group
resource "aws_lb_target_group_attachment" "web_attachments" {
  for_each = { for idx, inst in aws_instance.web : idx => inst.id }
  target_group_arn = aws_lb_target_group.web_tg.arn
  target_id        = each.value
  port             = 80
}

# Listener
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web_tg.arn
  }
}

# Output resources
#output "vpc_id" {
#  description = "VPC ID"
#  value       = aws_vpc.this.id
#}

#output "alb_dns" {
#  description = "ALB DNS name"
#  value       = aws_lb.alb.dns_name
#}

#output "bastion_public_ip" {
#  description = "Bastion public IP"
#  value       = aws_eip.bastion.public_ip
#}
