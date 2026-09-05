############################################
# Terraform Task: Launch Linux EC2 instances
# in TWO AWS regions using a single .tf file
############################################

terraform {
  required_version = ">= 1.3.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

############################################
# VARIABLES
############################################

variable "region_primary" {
  description = "Primary AWS region"
  type        = string
  default     = "ap-south-1" # Mumbai
}

variable "region_secondary" {
  description = "Secondary AWS region"
  type        = string
  default     = "us-east-1" # N. Virginia
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.micro" # free-tier eligible
}

variable "key_name_primary" {
  description = "Existing EC2 key pair name in the primary region (leave blank to skip SSH access)"
  type        = string
  default     = ""
}

variable "key_name_secondary" {
  description = "Existing EC2 key pair name in the secondary region (leave blank to skip SSH access)"
  type        = string
  default     = ""
}

############################################
# PROVIDERS
# Two aliased providers = two regions,
# all still declared in this one file.
############################################

provider "aws" {
  alias  = "primary"
  region = var.region_primary
}

provider "aws" {
  alias  = "secondary"
  region = var.region_secondary
}

############################################
# AMI LOOKUPS (latest Amazon Linux 2023, per region)
############################################

data "aws_ami" "al2023_primary" {
  provider    = aws.primary
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

data "aws_ami" "al2023_secondary" {
  provider    = aws.secondary
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

############################################
# SECURITY GROUPS (allow SSH - lock this down
# to your own IP in production use)
############################################

resource "aws_security_group" "ssh_primary" {
  provider    = aws.primary
  name        = "allow-ssh-primary"
  description = "Allow SSH inbound"

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow-ssh-primary"
  }
}

resource "aws_security_group" "ssh_secondary" {
  provider    = aws.secondary
  name        = "allow-ssh-secondary"
  description = "Allow SSH inbound"

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow-ssh-secondary"
  }
}

############################################
# EC2 INSTANCES
############################################

resource "aws_instance" "linux_primary" {
  provider               = aws.primary
  ami                    = data.aws_ami.al2023_primary.id
  instance_type          = var.instance_type
  key_name               = var.key_name_primary != "" ? var.key_name_primary : null
  vpc_security_group_ids = [aws_security_group.ssh_primary.id]

  tags = {
    Name   = "linux-instance-primary"
    Region = var.region_primary
  }
}

resource "aws_instance" "linux_secondary" {
  provider               = aws.secondary
  ami                    = data.aws_ami.al2023_secondary.id
  instance_type          = var.instance_type
  key_name               = var.key_name_secondary != "" ? var.key_name_secondary : null
  vpc_security_group_ids = [aws_security_group.ssh_secondary.id]

  tags = {
    Name   = "linux-instance-secondary"
    Region = var.region_secondary
  }
}

############################################
# OUTPUTS
############################################

output "primary_instance_id" {
  value = aws_instance.linux_primary.id
}

output "primary_instance_public_ip" {
  value = aws_instance.linux_primary.public_ip
}

output "primary_region" {
  value = var.region_primary
}

output "secondary_instance_id" {
  value = aws_instance.linux_secondary.id
}

output "secondary_instance_public_ip" {
  value = aws_instance.linux_secondary.public_ip
}

output "secondary_region" {
  value = var.region_secondary
}
