# Month 1 Assessment — TechCorp Terraform

## Overview
This repository contains a Terraform configuration to provision a multi-AZ VPC, public and private subnets, NAT gateways, a bastion host, web and DB EC2 instances, and an Application Load Balancer.

## Prerequisites
- AWS account with permissions to create VPC, EC2, ELB, IAM resources
- Terraform v1.x installed
- AWS CLI configured with credentials (`aws configure`) or environment variables set
- Local SSH key (if using `key_pair_name`); the key must exist in EC2 or set `create_key_pair = true` in `terraform.tfvars`
- Your public IP in CIDR format (e.g., `1.2.3.4/32`)

## Files
- `main.tf` — all resources
- `variables.tf` — variables and defaults
- `outputs.tf` — outputs
- `terraform.tfvars.example` — sample variables file
- `user_data/web_server_setup.sh` — installs Apache and creates an index page
- `user_data/db_server_setup.sh` — installs Postgres and a test DB

## Deploy
1. Copy example variables:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars and set key_pair_name and my_ip
# month-one-assessment
