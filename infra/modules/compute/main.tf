# =============================================================================
# COMPUTE MODULE
# =============================================================================
# Creates EC2 instances, security groups, and key pairs
# =============================================================================

# =============================================================================
# DATA SOURCE - AMI
# =============================================================================

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# =============================================================================
# KEY PAIR
# =============================================================================

resource "aws_key_pair" "main" {
  key_name   = "${var.name_prefix}-key"
  public_key = file(var.ssh_public_key_path)

  tags = var.common_tags
}

# =============================================================================
# SECURITY GROUP
# =============================================================================

resource "aws_security_group" "web" {
  name        = "${var.name_prefix}-web-sg"
  description = "Security group for web server"
  vpc_id      = var.vpc_id

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-web-sg"
  })
}

resource "aws_vpc_security_group_ingress_rule" "http" {
  security_group_id = aws_security_group.web.id
  description       = "HTTP"
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "https" {
  security_group_id = aws_security_group.web.id
  description       = "HTTPS"
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "ssh" {
  security_group_id = aws_security_group.web.id
  description       = "SSH"
  cidr_ipv4         = var.allowed_ssh_cidr
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "all_outbound" {
  security_group_id = aws_security_group.web.id
  description       = "All outbound"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# =============================================================================
# WEB SERVER EC2 INSTANCE
# =============================================================================

locals {
  ami_id = var.custom_ami_id != "" ? var.custom_ami_id : data.aws_ami.ubuntu.id
}

resource "aws_instance" "web" {
  ami                         = local.ami_id
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [aws_security_group.web.id]
  key_name                    = aws_key_pair.main.key_name
  associate_public_ip_address = true

  root_block_device {
    delete_on_termination = true
    volume_size           = var.root_volume_size
    volume_type           = "gp3"
    encrypted             = true
  }

  user_data = var.custom_ami_id != "" ? null : var.user_data

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-web"
    Role = "web-server"
  })
}
