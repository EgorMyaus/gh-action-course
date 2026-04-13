# =============================================================================
# COMPUTE MODULE — single EC2 instance with HTTP + SSH (EC2 Instance Connect)
# =============================================================================
# Creates a security group (HTTP 80, SSH 22) and a single EC2 instance.
# No aws_key_pair — SSH access is expected to go through EC2 Instance Connect,
# which installs ephemeral keys on-demand via the AWS API (see deploy workflow).
# The caller provides ami_id (from a data source or a Packer build) and user_data.
# =============================================================================

resource "aws_security_group" "app" {
  name_prefix = "${var.name_prefix}-app-"
  description = "Allow HTTP and SSH for ${var.name_prefix}"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH for debugging via EC2 Instance Connect"
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

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-app-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_instance" "app" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [aws_security_group.app.id]
  associate_public_ip_address = true

  user_data                   = var.user_data
  user_data_replace_on_change = true

  root_block_device {
    volume_size = var.root_volume_size
    volume_type = "gp3"
  }

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-app"
  })
}
