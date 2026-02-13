# =============================================================================
# APPLICATION LOAD BALANCER
# =============================================================================
# Production-ready ALB with:
#   - HTTPS termination
#   - Health checks
#   - Access logging
#   - WAF integration ready
# =============================================================================

# =============================================================================
# VARIABLES
# =============================================================================

variable "enable_alb" {
  description = "Enable Application Load Balancer"
  type        = bool
  default     = false
}

variable "domain_name" {
  description = "Domain name for the application (e.g., example.com)"
  type        = string
  default     = ""
}

variable "enable_https" {
  description = "Enable HTTPS (requires domain_name and ACM certificate)"
  type        = bool
  default     = false
}

# =============================================================================
# ADDITIONAL PUBLIC SUBNET FOR ALB (requires 2 AZs)
# =============================================================================

resource "aws_subnet" "public_alb" {
  count = var.enable_alb ? 1 : 0

  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.4.0/24"
  availability_zone       = "${var.aws_region}b"
  map_public_ip_on_launch = true

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-public-alb"
    Type = "public"
  })
}

resource "aws_route_table_association" "public_alb" {
  count = var.enable_alb ? 1 : 0

  subnet_id      = aws_subnet.public_alb[0].id
  route_table_id = aws_route_table.public.id
}

# =============================================================================
# SECURITY GROUP FOR ALB
# =============================================================================

resource "aws_security_group" "alb" {
  count = var.enable_alb ? 1 : 0

  name        = "${local.name_prefix}-alb-sg"
  description = "Security group for Application Load Balancer"
  vpc_id      = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-alb-sg"
  })
}

# Allow HTTP from anywhere
resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  count = var.enable_alb ? 1 : 0

  security_group_id = aws_security_group.alb[0].id
  description       = "HTTP from anywhere"
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
}

# Allow HTTPS from anywhere
resource "aws_vpc_security_group_ingress_rule" "alb_https" {
  count = var.enable_alb && var.enable_https ? 1 : 0

  security_group_id = aws_security_group.alb[0].id
  description       = "HTTPS from anywhere"
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
}

# Allow all outbound
resource "aws_vpc_security_group_egress_rule" "alb_all_outbound" {
  count = var.enable_alb ? 1 : 0

  security_group_id = aws_security_group.alb[0].id
  description       = "All outbound"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# Update web security group to only allow traffic from ALB
resource "aws_vpc_security_group_ingress_rule" "web_from_alb" {
  count = var.enable_alb ? 1 : 0

  security_group_id            = aws_security_group.web.id
  description                  = "HTTP from ALB"
  referenced_security_group_id = aws_security_group.alb[0].id
  from_port                    = 80
  to_port                      = 80
  ip_protocol                  = "tcp"
}

# =============================================================================
# APPLICATION LOAD BALANCER
# =============================================================================

resource "aws_lb" "main" {
  count = var.enable_alb ? 1 : 0

  name               = "${local.name_prefix}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb[0].id]
  subnets            = [aws_subnet.public.id, aws_subnet.public_alb[0].id]

  enable_deletion_protection = var.environment == "prod" ? true : false

  # Access logs (optional - requires S3 bucket)
  # access_logs {
  #   bucket  = aws_s3_bucket.alb_logs[0].id
  #   prefix  = "alb"
  #   enabled = true
  # }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-alb"
  })
}

# =============================================================================
# TARGET GROUP
# =============================================================================

resource "aws_lb_target_group" "web" {
  count = var.enable_alb ? 1 : 0

  name     = "${local.name_prefix}-web-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    path                = "/"
    port                = "traffic-port"
    protocol            = "HTTP"
    matcher             = "200-399"
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-web-tg"
  })
}

# Register EC2 instance with target group
resource "aws_lb_target_group_attachment" "web" {
  count = var.enable_alb ? 1 : 0

  target_group_arn = aws_lb_target_group.web[0].arn
  target_id        = aws_instance.web.id
  port             = 80
}

# =============================================================================
# LISTENERS
# =============================================================================

# HTTP Listener - redirects to HTTPS if enabled
resource "aws_lb_listener" "http" {
  count = var.enable_alb ? 1 : 0

  load_balancer_arn = aws_lb.main[0].arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = var.enable_https ? "redirect" : "forward"

    dynamic "redirect" {
      for_each = var.enable_https ? [1] : []
      content {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }

    dynamic "forward" {
      for_each = var.enable_https ? [] : [1]
      content {
        target_group {
          arn = aws_lb_target_group.web[0].arn
        }
      }
    }
  }
}

# HTTPS Listener
resource "aws_lb_listener" "https" {
  count = var.enable_alb && var.enable_https ? 1 : 0

  load_balancer_arn = aws_lb.main[0].arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = aws_acm_certificate.main[0].arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web[0].arn
  }

  depends_on = [aws_acm_certificate_validation.main]
}

# =============================================================================
# ACM CERTIFICATE (for HTTPS)
# =============================================================================

resource "aws_acm_certificate" "main" {
  count = var.enable_alb && var.enable_https && var.domain_name != "" ? 1 : 0

  domain_name       = var.domain_name
  validation_method = "DNS"

  subject_alternative_names = [
    "*.${var.domain_name}"
  ]

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-cert"
  })
}

# Certificate validation (requires Route53 hosted zone)
resource "aws_acm_certificate_validation" "main" {
  count = var.enable_alb && var.enable_https && var.domain_name != "" ? 1 : 0

  certificate_arn = aws_acm_certificate.main[0].arn
  # validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}
