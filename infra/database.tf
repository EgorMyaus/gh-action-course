# =============================================================================
# RDS POSTGRESQL DATABASE
# =============================================================================
# Production-ready PostgreSQL database in private subnet
# Best Practices:
#   - Multi-AZ for high availability (optional, adds cost)
#   - Encrypted storage
#   - Automated backups
#   - Private subnet (no public access)
#   - Security group restricts access to app servers only
# =============================================================================

# =============================================================================
# VARIABLES
# =============================================================================

variable "enable_database" {
  description = "Enable RDS PostgreSQL database"
  type        = bool
  default     = false
}

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"  # Free tier eligible: db.t2.micro
}

variable "db_name" {
  description = "Database name"
  type        = string
  default     = "reactapp"
}

variable "db_username" {
  description = "Database master username"
  type        = string
  default     = "dbadmin"
  sensitive   = true
}

variable "db_multi_az" {
  description = "Enable Multi-AZ deployment for high availability"
  type        = bool
  default     = false  # Set to true for production
}

variable "db_backup_retention" {
  description = "Number of days to retain backups"
  type        = number
  default     = 7
}

# =============================================================================
# ADDITIONAL SUBNET FOR RDS (Multi-AZ requires 2 AZs)
# =============================================================================

resource "aws_subnet" "private_db" {
  count = var.enable_database ? 1 : 0

  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "${var.aws_region}b"  # Different AZ

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-private-db"
    Type = "private"
  })
}

resource "aws_route_table_association" "private_db" {
  count = var.enable_database ? 1 : 0

  subnet_id      = aws_subnet.private_db[0].id
  route_table_id = aws_route_table.private.id
}

# =============================================================================
# DB SUBNET GROUP
# =============================================================================

resource "aws_db_subnet_group" "main" {
  count = var.enable_database ? 1 : 0

  name        = "${local.name_prefix}-db-subnet-group"
  description = "Database subnet group for ${var.project_name}"
  subnet_ids  = [aws_subnet.private.id, aws_subnet.private_db[0].id]

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-db-subnet-group"
  })
}

# =============================================================================
# SECURITY GROUP FOR RDS
# =============================================================================

resource "aws_security_group" "database" {
  count = var.enable_database ? 1 : 0

  name        = "${local.name_prefix}-db-sg"
  description = "Security group for RDS PostgreSQL"
  vpc_id      = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-db-sg"
  })
}

# Allow PostgreSQL from web servers only
resource "aws_vpc_security_group_ingress_rule" "db_from_web" {
  count = var.enable_database ? 1 : 0

  security_group_id            = aws_security_group.database[0].id
  description                  = "PostgreSQL from web servers"
  referenced_security_group_id = aws_security_group.web.id
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
}

# Allow PostgreSQL from E2E runners (if enabled)
resource "aws_vpc_security_group_ingress_rule" "db_from_e2e" {
  count = var.enable_database && var.enable_e2e_infrastructure ? 1 : 0

  security_group_id            = aws_security_group.database[0].id
  description                  = "PostgreSQL from E2E runners"
  referenced_security_group_id = aws_security_group.e2e[0].id
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
}

# =============================================================================
# RDS POSTGRESQL INSTANCE
# =============================================================================

resource "aws_db_instance" "main" {
  count = var.enable_database ? 1 : 0

  identifier = "${local.name_prefix}-postgres"

  # Engine
  engine               = "postgres"
  engine_version       = "15.4"
  instance_class       = var.db_instance_class
  parameter_group_name = aws_db_parameter_group.main[0].name

  # Storage
  allocated_storage     = 20
  max_allocated_storage = 100  # Auto-scaling up to 100GB
  storage_type          = "gp3"
  storage_encrypted     = true

  # Database
  db_name  = var.db_name
  username = var.db_username
  password = random_password.db_password[0].result

  # Network
  db_subnet_group_name   = aws_db_subnet_group.main[0].name
  vpc_security_group_ids = [aws_security_group.database[0].id]
  publicly_accessible    = false
  port                   = 5432

  # High Availability
  multi_az = var.db_multi_az

  # Backup
  backup_retention_period = var.db_backup_retention
  backup_window           = "03:00-04:00"  # UTC
  maintenance_window      = "Mon:04:00-Mon:05:00"

  # Monitoring
  performance_insights_enabled = true
  monitoring_interval          = 60
  monitoring_role_arn          = aws_iam_role.rds_monitoring[0].arn

  # Deletion protection
  deletion_protection      = var.environment == "prod" ? true : false
  skip_final_snapshot      = var.environment == "prod" ? false : true
  final_snapshot_identifier = var.environment == "prod" ? "${local.name_prefix}-final-snapshot" : null

  # Updates
  auto_minor_version_upgrade = true
  apply_immediately          = var.environment != "prod"

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-postgres"
  })

  depends_on = [aws_iam_role_policy_attachment.rds_monitoring]
}

# =============================================================================
# DB PARAMETER GROUP
# =============================================================================

resource "aws_db_parameter_group" "main" {
  count = var.enable_database ? 1 : 0

  name   = "${local.name_prefix}-pg15-params"
  family = "postgres15"

  parameter {
    name  = "log_connections"
    value = "1"
  }

  parameter {
    name  = "log_disconnections"
    value = "1"
  }

  parameter {
    name  = "log_statement"
    value = "ddl"
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-pg15-params"
  })
}

# =============================================================================
# RANDOM PASSWORD FOR DATABASE
# =============================================================================

resource "random_password" "db_password" {
  count = var.enable_database ? 1 : 0

  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# =============================================================================
# IAM ROLE FOR RDS ENHANCED MONITORING
# =============================================================================

resource "aws_iam_role" "rds_monitoring" {
  count = var.enable_database ? 1 : 0

  name = "${local.name_prefix}-rds-monitoring-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "monitoring.rds.amazonaws.com"
        }
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  count = var.enable_database ? 1 : 0

  role       = aws_iam_role.rds_monitoring[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

# =============================================================================
# STORE PASSWORD IN SECRETS MANAGER
# =============================================================================

resource "aws_secretsmanager_secret" "db_password" {
  count = var.enable_database ? 1 : 0

  name        = "${local.name_prefix}/database/password"
  description = "RDS PostgreSQL master password"

  tags = local.common_tags
}

resource "aws_secretsmanager_secret_version" "db_password" {
  count = var.enable_database ? 1 : 0

  secret_id = aws_secretsmanager_secret.db_password[0].id
  secret_string = jsonencode({
    username = var.db_username
    password = random_password.db_password[0].result
    host     = aws_db_instance.main[0].address
    port     = aws_db_instance.main[0].port
    dbname   = var.db_name
    engine   = "postgres"
  })
}
