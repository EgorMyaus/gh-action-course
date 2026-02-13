# =============================================================================
# AMI DATA SOURCE
# =============================================================================
# Used as fallback when not using Packer custom AMIs
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
# LOCALS FOR AMI SELECTION
# =============================================================================

locals {
  # Use custom Packer AMI if provided, otherwise use base Ubuntu
  web_server_ami = var.use_custom_ami && var.web_server_ami_id != "" ? var.web_server_ami_id : data.aws_ami.ubuntu.id
}

# =============================================================================
# KEY PAIR
# =============================================================================

resource "aws_key_pair" "web" {
  key_name   = "${local.name_prefix}-key"
  public_key = file(var.ssh_public_key_path)

  tags = local.common_tags
}

# =============================================================================
# WEB SERVER EC2 INSTANCE
# =============================================================================

resource "aws_instance" "web" {
  ami                         = local.web_server_ami
  instance_type               = var.instance_type
  associate_public_ip_address = true
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.web.id]
  key_name                    = aws_key_pair.web.key_name

  root_block_device {
    delete_on_termination = true
    volume_size           = 20
    volume_type           = "gp3"
    encrypted             = true
  }

  # Only use user_data if NOT using custom Packer AMI
  user_data = var.use_custom_ami ? null : <<-EOF
    #!/bin/bash
    set -e
    exec > >(tee /var/log/user-data.log) 2>&1
    echo "Starting web server setup at $(date)"
    
    apt-get update
    apt-get install -y nginx docker.io docker-compose curl wget git vim
    systemctl enable nginx docker
    systemctl start nginx docker
    usermod -aG docker ubuntu
    
    echo "Web server setup completed at $(date)"
  EOF

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-web"
    Role = "web-server"
    AMI_Type = var.use_custom_ami ? "packer-custom" : "base-ubuntu"
  })
}

# =============================================================================
# SECURITY GROUP
# =============================================================================

resource "aws_security_group" "web" {
  name        = "${local.name_prefix}-web-sg"
  description = "Security group for web server - HTTP, HTTPS, SSH"
  vpc_id      = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-web-sg"
  })
}

resource "aws_vpc_security_group_ingress_rule" "http" {
  security_group_id = aws_security_group.web.id
  description       = "Allow HTTP"
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "https" {
  security_group_id = aws_security_group.web.id
  description       = "Allow HTTPS"
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "ssh" {
  security_group_id = aws_security_group.web.id
  description       = "Allow SSH"
  cidr_ipv4         = var.allowed_ssh_cidr
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "all_outbound" {
  security_group_id = aws_security_group.web.id
  description       = "Allow all outbound"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}