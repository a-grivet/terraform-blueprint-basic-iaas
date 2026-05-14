# ============================================================================
# TERRAFORM VARIABLES DEFINITION FILE (variables.tf)
# ============================================================================
# This file DEFINES what variables exist and their properties (type, default, description).
# Think of this as a "contract" or "template" that specifies what inputs your Terraform
# configuration accepts.
#
# The VALUES for these variables are set in terraform.tfvars.
#
#
# Variables without a default value MUST be provided in terraform.tfvars.
# Variables that gave a default value and that are set in terraform.tfvars are overrited by value in terraform.tfvars
# ============================================================================

# ============================================================================
# GENERAL VARIABLES
# ============================================================================

variable "app_id" {
  description = "Application identifier (AppId) as registered in the Your Organization application catalog. Used as the 3rd segment of the Your Organization naming convention."
  type        = string
}

variable "environment" {
  description = "Environment code following the Your Organization naming convention: c (poc), t (test/sandbox), d (dev), s (stage), p (prod)."
  type        = string

  validation {
    condition     = contains(["c", "t", "d", "s", "p"], var.environment)
    error_message = "environment must be one of: c (poc), t (test/sandbox), d (dev), s (stage), p (prod)."
  }
}

variable "label" {
  description = "Optional label (5th segment of the Your Organization naming convention) to distinguish multiple instances of the same resource type."
  type        = string
  default     = null
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-1" # Default value if not specified in terraform.tfvars 
}

# ============================================================================
# NETWORKING VARIABLES (Pre-existing infrastructure)
# ============================================================================
# These variables reference network resources that already exist in AWS

variable "vpc_id" {
  description = "Existing VPC ID"
  type        = string
  # No default = REQUIRED variable
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs for NAT Gateways"
  type        = list(string) # list(string) = array of text values
  # No default = REQUIRED variable
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs"
  type        = list(string)
  # No default = REQUIRED variable
}

# ============================================================================
# AUTO SCALING GROUP (ASG) VARIABLES
# ============================================================================
# These variables control the Auto Scaling Group behavior

variable "asg_min_size" {
  description = "Minimum number of instances in the ASG"
  type        = number
  default     = 1 # Always keep at least 1 instance running
}

variable "asg_max_size" {
  description = "Maximum number of instances in the ASG"
  type        = number
  default     = 3 # Can scale up to 3 instances maximum
}

variable "asg_desired_capacity" {
  description = "Desired number of instances in the ASG"
  type        = number
  default     = 2 # Target number of instances under normal conditions
}

variable "ami_kms_key_id" {
  description = "KMS key ID/ARN used to encrypt the AMI. Required for Auto Scaling to decrypt the AMI snapshot. Default is Your Organization Golden AMI shared key."
  type        = string
  # Default provided: Your Organization shared KMS key for Golden AMI decryption
  default = "arn:aws:kms:eu-west-1:471112561413:key/mrk-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
}

# ============================================================================
# EC2 INSTANCE CONFIGURATION VARIABLES
# ============================================================================
# These variables define the properties of individual EC2 instances

variable "instance_type" {
  description = "EC2 instance type for ASG instances"
  type        = string
  # No default = REQUIRED variable
}

variable "ami_id" {
  description = "AMI ID to use for instances (leave empty for auto-selection of latest Amazon Linux 2023)"
  type        = string
  default     = "" # Empty string = use latest Amazon Linux 2023 AMI automatically
}

variable "root_volume_size" {
  description = "Size of root volume in GB"
  type        = number
  # No default = REQUIRED variable (root disk size)
}


# ============================================================================
# USER DATA VARIABLE
# ============================================================================
# User data is a script that runs automatically when an EC2 instance launches

variable "user_data_script" {
  description = "User data script to run on instance launch"
  type        = string
  default     = "" # Empty string = no user data script except if defined in terraform.tfvars
}

# ============================================================================
# HEALTH CHECK CONFIGURATION
# ============================================================================
# Health checks determine if an instance is functioning properly

variable "health_check_type" {
  description = "Health check type: EC2 or ELB (use ELB if attached to load balancer)"
  type        = string
  default     = "EC2" # EC2 = basic instance health check
}

# ============================================================================
# DNS & SSL/TLS CERTIFICATE VARIABLES
# ============================================================================
# These variables configure your custom domain and HTTPS certificate

variable "domain_name" {
  description = "Domain name for the application (e.g., app.prod.your-org.com)"
  type        = string
  # No default = REQUIRED variable
}

variable "zone_name" {
  description = "Route53 hosted zone name (e.g., your-org.com)"
  type        = string
  # No default = REQUIRED variable
}

variable "zone_id" {
  description = "Route53 Hosted Zone ID (optional, use instead of zone_name for delegated zones)"
  type        = string
  default     = "" # Empty string = use zone_name to look up the zone
}

variable "enable_certificate_monitoring" {
  description = "Enable certificate expiry monitoring"
  type        = bool  # Boolean: true or false
  default     = false # Disabled by default (enable in prod for alerts)
}


# ============================================================================
# DATABASE VARIABLES (Aurora)
# ============================================================================
# Aurora is AWS's managed relational database with automatic failover

variable "db_engine" {
  description = "Database engine (aurora-postgresql or aurora-mysql)"
  type        = string
  default     = "aurora-postgresql" # PostgreSQL-compatible Aurora
}

variable "db_engine_version" {
  description = "Database engine version"
  type        = string
  # No default = REQUIRED variable (DB engine version)
}

variable "db_name" {
  description = "Database name"
  type        = string
  # No default = REQUIRED variable (the name of the database to create)
}

variable "db_username" {
  description = "Database master username"
  type        = string
  # No default = REQUIRED variable (admin username for database access)
}

variable "db_port" {
  description = "Database port"
  type        = number
  default     = 5432 # PostgreSQL default port
  # Use 3306 for MySQL
}

variable "db_instance_class" {
  description = "Database instance class"
  type        = string
  default     = "db.t3.medium" # Medium instance size (2 vCPU, 4GB RAM)
}

variable "db_writer_instances" {
  description = "Number of writer instances"
  type        = number
  default     = 1 # Typically 1 writer instance (handles all write operations)
}

variable "db_reader_instances" {
  description = "Number of reader instances"
  type        = number
  default     = 1 # Reader instances handle read queries (improves performance)
  # Scale readers up for read-heavy workloads
}

variable "db_backup_retention_period" {
  description = "Backup retention period in days"
  type        = number
  default     = 7 # Keep automated backups for 7 days
  # Increase for production (e.g., 30 days)
}

variable "db_backup_window" {
  description = "Preferred backup window"
  type        = string
  default     = "03:00-04:00" # UTC time (1-hour window during low-traffic period)
}

variable "db_maintenance_window" {
  description = "Preferred maintenance window"
  type        = string
  default     = "sun:04:00-sun:05:00" # UTC time (Sunday, 1-hour window)
  # AWS may apply patches or updates during this window
}


# ============================================================================
# IAM (Identity and Access Management) VARIABLES
# ============================================================================
# IAM controls who/what can access AWS resources and what actions they can perform

variable "permissions_boundary_arn" {
  description = "ARN of the IAM Permissions Boundary to attach to the IAM Role."
  type        = string
  # Permissions boundary: A security control that sets the maximum permissions
  # a role can have, even if more permissive policies are attached
  default = "arn:aws:iam::670943688569:policy/OrgPermissionBoundary" # Your Organization default permission boundary
}

# ============================================================================
# MONITORING CONFIGURATION VARIABLES
# ============================================================================
# These variables configure CloudWatch alarms and notifications

variable "alert_email" {
  description = "Email address to receive CloudWatch alarm notifications"
  type        = string
  # No default = REQUIRED variable (where to send alerts)
  # Note: You'll need to confirm the email subscription when first created
}

variable "database_connection_threshold" {
  description = "Threshold for Aurora database connections alarm"
  type        = number
  default     = 80 # Alert if database connections exceed 80
  # Adjust based on your db_instance_class (each class has max connection limits)
}


# ============================================================================
# TAGS VARIABLE
# ============================================================================
# Tags are key-value pairs for organizing and tracking AWS resources

variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string) # map(string) = dictionary/object with string values
  default     = {}          # Empty map = no tags by default
  # Tags are typically provided in terraform.tfvars and applied to all resources
}
