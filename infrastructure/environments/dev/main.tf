# ============================================================================
# MAIN INFRASTRUCTURE CONFIGURATION - DEV ENVIRONMENT
# ============================================================================
# This file orchestrates all infrastructure modules to deploy a complete
# 3-tier web application stack in AWS:
# - Presentation tier: Application Load Balancer (public subnets)
# - Application tier: Auto Scaling Group with EC2 instances (private subnets)
# - Data tier: Aurora RDS cluster (private subnets)
#
#
# Module dependencies:
# 1. Security Groups (network firewall rules)
# 2. KMS keys (encryption)
# 3. ACM certificate (HTTPS)
# 4. IAM role (EC2 permissions)
# 5. Secrets Manager (database password)
# 6. ALB (load balancer)
# 7. ASG (compute instances)
# 8. Aurora (database)
# 9. Monitoring (CloudWatch)
# 10. SSM Parameters (Aurora cluster writer endpoint)


# ============================================================================
# DATA SOURCES - AWS Account and Region Information
# ============================================================================

data "aws_caller_identity" "current" {}
# Get current AWS account ID
# Used for: Resource naming, IAM ARNs, account-specific configurations
# Example: account_id = "123456789012"

data "aws_region" "current" {}
# Get current AWS region
# Used for: Regional resource identifiers, availability zones
# Example: name = "eu-west-1"

# ============================================================================
# MODULE: SECURITY GROUPS - Network Firewall Rules
# ============================================================================
# Creates security groups for 3-tier architecture

module "security_groups" {
  source = "git::ssh://your-alert-email@example.com/a-grivet/terraform-modules-aws-aws.git//modules/security-groups?ref=v1.0.0"

  app_id       = var.app_id # Project identifier for naming
  environment  = var.environment  # Environment (dev, staging, prod)
  label        = var.label
  vpc_id       = var.vpc_id       # Existing VPC ID
  app_port     = 80               # Application listens on port 80
  tags         = var.tags         # Common resource tags
  # Security groups created:
  # 1. ALB security group: Allows HTTP/HTTPS from internet
  # 2. App security group: Allows traffic from ALB only
  # 3. DB security group: Allows traffic from app tier only
  # 
  # Traffic flow:
  # Internet (0.0.0.0/0) → ALB:443 → App:80 → DB:5432
  # 
}

# ============================================================================
# MODULE: ACM CERTIFICATE - SSL/TLS Certificate
# ============================================================================
# Creates and validates SSL/TLS certificate for HTTPS

module "acm_certificate" {
  source = "git::ssh://your-alert-email@example.com/a-grivet/terraform-modules-aws-aws.git//modules/acm-alb?ref=v1.0.0"

  # Domain configuration
  domain_name = var.domain_name # Example: app.dev.mydomain.com
  zone_id     = var.zone_id     # Route53 hosted zone ID
  zone_name   = var.zone_name   # Route53 hosted zone name
  environment = var.environment
  CostCenter  = var.app_id


  # Certificate expiry monitoring
  enable_expiry_alarm         = var.enable_certificate_monitoring
  expiry_alarm_threshold_days = 30 # Alert 30 days before expiry
  # Note: ACM certificates auto-renew if DNS validation stays valid


  tags = merge(
    var.tags,
    { Component = "Certificate" }
  )

  # Certificate features:
  # - Automatic DNS validation (no manual email validation)
  # - Automatic renewal (before expiration)
  # 
  # HTTPS workflow:
  # 1. Request certificate for domain
  # 2. Create DNS validation record in Route53
  # 3. Wait for validation (usually < 5 minutes)
  # 4. Attach certificate to ALB HTTPS listener
}

# ============================================================================
# MODULE: APPLICATION LOAD BALANCER - Layer 7 Load Balancer
# ============================================================================
# Creates internet-facing ALB for HTTPS traffic distribution

module "alb" {
  source = "git::ssh://your-alert-email@example.com/a-grivet/terraform-modules-aws-aws.git//modules/alb?ref=v1.0.0"

  # Basic configuration
  app_id       = var.app_id
  environment  = var.environment
  label        = var.label
  vpc_id       = var.vpc_id

  # Network configuration
  subnet_ids         = var.public_subnet_ids # Deploy in public subnets (internet-facing)
  security_group_ids = [module.security_groups.alb_security_group_id]
  internal           = false # Internet-facing (not internal)

  # HTTPS configuration
  certificate_arn = module.acm_certificate.certificate_arn
  ssl_policy      = "ELBSecurityPolicy-TLS-1-2-2017-01" # TLS 1.2 minimum (secure)

  # Target group configuration
  target_group_port     = 80     # Forward to instances on port 80
  target_group_protocol = "HTTP" # HTTP between ALB and instances (internal network)
  deregistration_delay  = 30     # Fast deregistration for dev (30s instead of 300s)

  # Health check configuration
  health_check_path                = "/health" # Health check endpoint
  health_check_protocol            = "HTTP"
  health_check_interval            = 30    # Check every 30 seconds
  health_check_timeout             = 10    # Timeout after 10 seconds
  health_check_healthy_threshold   = 3     # 3 successful checks = healthy
  health_check_unhealthy_threshold = 3     # 3 failed checks = unhealthy
  health_check_matcher             = "200" # HTTP 200 = healthy

  # CloudWatch alarms
  enable_cloudwatch_alarms         = true
  unhealthy_target_alarm_threshold = 1  # Alert if any target unhealthy
  response_time_alarm_threshold    = 5  # Alert if response time > 5s
  http_5xx_alarm_threshold         = 10 # Alert if 10+ 5xx errors

  tags = merge(
    var.tags,
    { Component = "LoadBalancer" }
  )
}

# ============================================================================
# ROUTE53 DNS RECORD - Domain Name Resolution
# ============================================================================
# Creates DNS A record pointing to ALB

resource "aws_route53_record" "app" {
  zone_id = module.acm_certificate.route53_zone_id
  name    = var.domain_name # Example: app.dev.your-org.com
  type    = "A"             # A record (maps domain to IPv4 address)

  alias {
    name                   = module.alb.alb_dns_name # ALB DNS name
    zone_id                = module.alb.alb_zone_id  # ALB hosted zone ID
    evaluate_target_health = true                    # Check ALB health for DNS routing
  }
  # DNS configuration:
  # - Type: A (Address record)
  # - Alias: Points to ALB
  # 
  # DNS resolution flow:
  # 1. User types: https://app.dev.mydomain.com
  # 2. Browser queries DNS for app.dev.mydomain.com
  # 3. Route53 returns ALB DNS name
  # 4. Browser resolves ALB DNS to IP addresses
  # 5. Browser connects to ALB IP on port 443
}

# ============================================================================
# MODULE: KMS KEYS - Encryption Keys
# ============================================================================
# Creates separate KMS keys for different data types (security isolation)

# 1. KMS key for EBS volume encryption
module "kms_ebs" {
  source = "git::ssh://your-alert-email@example.com/a-grivet/terraform-modules-aws-aws.git//modules/kms?ref=v1.0.0"

  app_id       = var.app_id
  environment  = var.environment
  label        = var.label
  key_name     = "ebs" # Key identifier
  description  = "EBS volume encryption"

  tags = var.tags
  # EBS encryption:
  # - Root volumes: Operating system disk
  # - Data volumes: Application data
  # - Snapshots: Encrypted with same key
}

# 2. KMS key for RDS database encryption
module "kms_rds" {
  source = "git::ssh://your-alert-email@example.com/a-grivet/terraform-modules-aws-aws.git//modules/kms?ref=v1.0.0"

  app_id       = var.app_id
  environment  = var.environment
  label        = var.label
  key_name     = "rds" # Key identifier
  description  = "Aurora database encryption"

  tags = var.tags
  # RDS encryption:
  # - Database storage: All data at rest
  # - Automated backups: Encrypted with same key
  # - Snapshots: Encrypted with same key
  # - Read replicas: Must use same key
}

# 3. KMS key for Secrets Manager encryption
module "kms_secrets" {
  source = "git::ssh://your-alert-email@example.com/a-grivet/terraform-modules-aws-aws.git//modules/kms?ref=v1.0.0"

  app_id       = var.app_id
  environment  = var.environment
  label        = var.label
  key_name     = "secrets" # Key identifier
  description  = "Secrets Manager encryption"

  tags = var.tags
  # Secrets encryption:
  # - Secrets Manager: Database passwords
  # - SSM Parameter Store: SecureString parameters
  # - Application secrets: API keys, tokens
}

# ============================================================================
# MODULE: EC2 IAM ROLE - Instance Permissions
# ============================================================================
# Creates IAM role for EC2 instances with SSM and CloudWatch permissions

module "ec2_iam_role" {
  source = "git::ssh://your-alert-email@example.com/a-grivet/terraform-modules-aws-aws.git//modules/iam?ref=v1.0.0"

  app_id       = var.app_id
  environment  = var.environment
  label        = var.label

  # Enable AWS Systems Manager Session Manager (secure shell access)
  enable_ssm = true # Replaces SSH keys (more secure)

  # Enable CloudWatch Logs and Metrics (monitoring)
  enable_cloudwatch = true # Application logs and metrics

  tags = var.tags
  # IAM role features:
  # - Instance profile: Attach to EC2 instances
  # - SSM Session Manager: Browser-based shell access (no SSH keys)
  # - CloudWatch Logs: Stream application logs
  # - CloudWatch Metrics: Publish custom metrics
  # - Permissions boundary: Prevent privilege escalation
  # 
  # Permissions granted:
  # - ssm:UpdateInstanceInformation
  # - ssm:CreateControlChannel
  # - ec2messages:* (Session Manager communication)
  # - logs:CreateLogGroup, logs:CreateLogStream, logs:PutLogEvents
  # - cloudwatch:PutMetricData
}

# ============================================================================
# MODULE: AUTO SCALING GROUP - Compute Instances
# ============================================================================
# Creates Auto Scaling Group with EC2 instances for application tier

module "asg" {
  source = "git::ssh://your-alert-email@example.com/a-grivet/terraform-modules-aws-aws.git//modules/asg?ref=v1.0.0"

  # Network configuration
  private_subnet_ids = var.private_subnet_ids # Deploy in private subnets (not internet-facing)

  # General configuration
  app_id       = var.app_id
  environment  = var.environment
  label        = var.label

  # Instance configuration
  instance_type = var.instance_type # Example: t3.micro
  ami_id        = var.ami_id        # AMI to use

  # Auto Scaling configuration
  min_size         = var.asg_min_size         # Minimum instances
  max_size         = var.asg_max_size         # Maximum instances
  desired_capacity = var.asg_desired_capacity # Target: 2 instances

  # Security
  security_group_ids        = [module.security_groups.app_security_group_id]
  iam_instance_profile_name = module.ec2_iam_role.instance_profile_name

  # ALB integration
  target_group_arns         = [module.alb.target_group_arn]
  health_check_type         = "ELB" # ALB health checks
  health_check_grace_period = 300   # 5 minutes for instance to become healthy

  # User data (bootstrap script)
  user_data_script = var.user_data_script # Script to install and configure application

  tags = merge(
    var.tags,
    { Component = "AutoScaling" }
  )

  depends_on = [
    module.kms_ebs,
    module.alb,
    module.ec2_iam_role,
    module.security_groups
  ]

  # Instance lifecycle:
  # 1. Launch instance from AMI
  # 2. Run user data script (install application)
  # 3. Wait for health check grace period
  # 4. Perform ALB health check
  # 5. Register with target group (start receiving traffic)
  # 6. Monitor health continuously
  # 7. Replace if unhealthy
}

# ============================================================================
# MODULE: SECRETS MANAGER - Database Password Storage
# ============================================================================
# Stores Aurora master password securely with KMS encryption

module "db_secret" {
  source = "git::ssh://your-alert-email@example.com/a-grivet/terraform-modules-aws-aws.git//modules/secrets-manager?ref=v1.0.0"

  app_id       = var.app_id
  environment  = var.environment
  label        = var.label
  secret_name  = "db-master-password"
  description  = "Master password for Aurora database"

  # Encryption
  kms_key_id = module.kms_secrets.key_id # Customer-managed KMS key

  # Password generation
  create_random_password  = true # Auto-generate secure password
  password_length         = 32   # 32 character password
  recovery_window_in_days = 7    # 7 day recovery window (dev environment)

  tags = var.tags
}

# Retrieve password for Aurora module (Terraform only, not applications)
data "aws_secretsmanager_secret_version" "db_password" {
  secret_id = module.db_secret.secret_id

  depends_on = [module.db_secret]
  # This data source retrieves the password value for passing to Aurora module
  # Applications should retrieve password directly from Secrets Manager
  # (not via Terraform outputs)
}

# ============================================================================
# MODULE: RDS AURORA - Database Cluster
# ============================================================================
# Creates Aurora PostgreSQL cluster with read replicas

module "aurora" {
  source = "git::ssh://your-alert-email@example.com/a-grivet/terraform-modules-aws-aws.git//modules/aurora?ref=v1.0.0"

  # General configuration
  app_id       = var.app_id
  environment  = var.environment
  label        = var.label

  # Network configuration
  db_subnet_ids         = var.private_subnet_ids # Private subnets (2 AZs minimum)
  db_security_group_ids = [module.security_groups.db_security_group_id]

  # Engine configuration
  engine         = var.db_engine         # Example: aurora-postgresql
  engine_version = var.db_engine_version # Example: 15.4
  engine_mode    = "provisioned"         # Provisioned (not serverless)

  # Database configuration
  database_name   = var.db_name                                                      # Database name
  master_username = var.db_username                                                  # Master username
  master_password = data.aws_secretsmanager_secret_version.db_password.secret_string # retrieve password from secret manager
  port            = var.db_port                                                      # Port: 5432 (PostgreSQL) or 3306 (MySQL)

  # Instance configuration
  instance_class   = var.db_instance_class   # Example: db.t4g.medium
  writer_instances = var.db_writer_instances # Number of writer instances
  reader_instances = var.db_reader_instances # Number of reader instances 

  # Encryption
  storage_encrypted = true
  kms_key_id        = module.kms_rds.key_arn # Customer-managed KMS key

  # Backup configuration
  backup_retention_period      = var.db_backup_retention_period          # Backup rentention in days. exemple: 7 (dev), 30 (prod)
  preferred_backup_window      = var.db_backup_window                    # Example: "03:00-04:00"
  preferred_maintenance_window = var.db_maintenance_window               # Example: "sun:04:00-sun:05:00"
  skip_final_snapshot          = var.environment == "dev" ? true : false # Skip for dev only

  # Monitoring
  enabled_cloudwatch_logs_exports = var.db_engine == "aurora-postgresql" ? ["postgresql"] : ["error", "general", "slowquery"]
  monitoring_interval             = 0    # 0 = disabled (enable for prod: 60)
  performance_insights_enabled    = true # Query performance analysis

  # Deletion protection
  deletion_protection = var.environment == "prod" ? true : false # Protect prod only

  tags = merge(
    var.tags,
    { Component = "Database" }
  )

  depends_on = [
    module.security_groups,
    module.kms_rds,
    module.db_secret
  ]
  # Aurora features:
  # - High availability: Multi-AZ deployment
  # - Read replicas: Up to 15 read replicas
  # - Automatic failover: <30 seconds
  # - Continuous backup: Point-in-time recovery
  # - Automated patching: Maintenance window
  # - Performance Insights: Query analysis
  # 
  # Writer vs Reader endpoints:
  # - Writer: Primary instance (read/write operations)
  # - Reader: Load-balanced read replicas (read-only operations)
}

# ============================================================================
# MODULE: SSM PARAMETER STORE - Configuration Management
# ============================================================================
# Stores database configuration in SSM Parameter Store for application access

module "ssm_parameters" {
  source = "git::ssh://your-alert-email@example.com/a-grivet/terraform-modules-aws-aws.git//modules/ssm-parameters?ref=v1.0.0"

  # Naming
  app_id      = var.app_id
  environment = var.environment

  # Encryption
  kms_key_id = module.kms_secrets.key_id # SecureString encryption

  # Database configuration values from Aurora module
  db_writer_endpoint = module.aurora.cluster_endpoint        # Primary endpoint (read/write)
  db_reader_endpoint = module.aurora.cluster_reader_endpoint # Read replica endpoint (read-only)
  db_port            = module.aurora.cluster_port            # Port (5432 or 3306)
  db_name            = var.db_name                           # Database name
  db_username        = var.db_username                       # Master username
  db_secret_arn      = module.db_secret.secret_arn           # Secrets Manager ARN (password)

  tags = merge(
    var.tags,
    { Component = "Configuration" }
  )

  depends_on = [
    module.aurora,
    module.db_secret,
    module.kms_secrets
  ]
}
