# =============================================================================
# ELASTICACHE REDIS
# =============================================================================
# Production-ready Redis cluster for:
#   - Session storage
#   - Caching
#   - Rate limiting
# Best Practices:
#   - Private subnet only
#   - Encryption in transit and at rest
#   - Multi-AZ for high availability (optional)
# =============================================================================

# =============================================================================
# VARIABLES
# =============================================================================

variable "enable_cache" {
  description = "Enable ElastiCache Redis"
  type        = bool
  default     = false
}

variable "cache_node_type" {
  description = "ElastiCache node type"
  type        = string
  default     = "cache.t3.micro"
}

variable "cache_num_nodes" {
  description = "Number of cache nodes"
  type        = number
  default     = 1  # Set to 2+ for production with replication
}

# =============================================================================
# ELASTICACHE SUBNET GROUP
# =============================================================================

resource "aws_elasticache_subnet_group" "main" {
  count = var.enable_cache ? 1 : 0

  name       = "${local.name_prefix}-cache-subnet-group"
  subnet_ids = var.enable_database ? [aws_subnet.private.id, aws_subnet.private_db[0].id] : [aws_subnet.private.id]

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-cache-subnet-group"
  })
}

# =============================================================================
# SECURITY GROUP FOR ELASTICACHE
# =============================================================================

resource "aws_security_group" "cache" {
  count = var.enable_cache ? 1 : 0

  name        = "${local.name_prefix}-cache-sg"
  description = "Security group for ElastiCache Redis"
  vpc_id      = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-cache-sg"
  })
}

# Allow Redis from web servers
resource "aws_vpc_security_group_ingress_rule" "cache_from_web" {
  count = var.enable_cache ? 1 : 0

  security_group_id            = aws_security_group.cache[0].id
  description                  = "Redis from web servers"
  referenced_security_group_id = aws_security_group.web.id
  from_port                    = 6379
  to_port                      = 6379
  ip_protocol                  = "tcp"
}

# =============================================================================
# ELASTICACHE REDIS CLUSTER
# =============================================================================

resource "aws_elasticache_cluster" "main" {
  count = var.enable_cache ? 1 : 0

  cluster_id = "${local.name_prefix}-redis"

  engine               = "redis"
  engine_version       = "7.0"
  node_type            = var.cache_node_type
  num_cache_nodes      = var.cache_num_nodes
  port                 = 6379
  parameter_group_name = aws_elasticache_parameter_group.main[0].name

  # Network
  subnet_group_name  = aws_elasticache_subnet_group.main[0].name
  security_group_ids = [aws_security_group.cache[0].id]

  # Maintenance
  maintenance_window = "sun:05:00-sun:06:00"

  # Snapshots
  snapshot_retention_limit = var.environment == "prod" ? 7 : 1
  snapshot_window          = "04:00-05:00"

  # Notifications
  notification_topic_arn = var.enable_monitoring ? aws_sns_topic.alerts[0].arn : null

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-redis"
  })
}

# =============================================================================
# ELASTICACHE PARAMETER GROUP
# =============================================================================

resource "aws_elasticache_parameter_group" "main" {
  count = var.enable_cache ? 1 : 0

  name   = "${local.name_prefix}-redis7-params"
  family = "redis7"

  parameter {
    name  = "maxmemory-policy"
    value = "volatile-lru"
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-redis7-params"
  })
}
