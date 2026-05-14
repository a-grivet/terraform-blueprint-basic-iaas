# ============================================================================
# TERRAFORM VARIABLES FILE (terraform.tfvars)
# ============================================================================
# This file contains the actual values for variables used in your Terraform configuration.
# Think of this as the "settings file" where you customize your infrastructure.
# Each variable defined in variables.tf gets its value assigned here.
#
# IMPORTANT: This file contains environment-specific values and should be customized
# for each environment (dev, staging, prod). Never commit sensitive data like passwords.
# ============================================================================

# ============================================================================
# PROJECT IDENTIFICATION
# ============================================================================
# These variables identify your project and environment

app_id       = "basic-iaas" # Short name for your project (used in resource names)
environment  = "d"          # Environment name: d (dev), p (prod), s (stage), t (test), c (poc)
label        = null          # Optional: add a label to distinguish multiple instances (e.g., "eu-west-3a")
region       = "eu-west-1"  # AWS region where resources will be created

# ============================================================================
# NETWORKING (Existing Infrastructure)
# ============================================================================
# These are existing network resources.
# Replace these IDs with your actual VPC and subnet IDs from your AWS account.

vpc_id = "vpc-xxxxxxxxxxxxxxxxx" # The VPC (Virtual Private Cloud) where all resources will be deployed

# Public subnets: Used for internet-facing resources like the Load Balancer
# Must be in different Availability Zones (AZs) for high availability
public_subnet_ids = [
  "subnet-xxxxxxxxxxxxxxxxx", # Public subnet in eu-west-1a
  "subnet-xxxxxxxxxxxxxxxxx"  # Public subnet in eu-west-1b
]

# Private subnets: Used for backend resources like EC2 instances and databases
# These subnets don't have direct internet access (more secure)
private_subnet_ids = [
  "subnet-xxxxxxxxxxxxxxxxx", # Private subnet in eu-west-1a
  "subnet-xxxxxxxxxxxxxxxxx"  # Private subnet in eu-west-1b
]

# ============================================================================
# AUTO SCALING GROUP (ASG) CONFIGURATION
# ============================================================================
# The ASG automatically manages EC2 instances, scaling them up or down based on demand

# --- Capacity Settings ---
# These control how many EC2 instances will run
asg_min_size         = 2 # Minimum number of instances (always running)
asg_max_size         = 3 # Maximum number of instances (during high traffic)
asg_desired_capacity = 2 # Target number of instances (normal operation)

# --- Instance Configuration ---
instance_type = "t3.small" # EC2 instance size (t3.micro = 2 vCPU, 1GB RAM)
# ami_id           = "ami-02f57c3d4e39a30db"       # OLD AMI
ami_id           = "ami-081fca5ba1b2ee989" # AMI ID: The machine image (OS + pre-installed software)
root_volume_size = 20                      # Root disk size in GB
# ami_kms_key_id   = "arn:aws:kms:eu-west-1:471112561413:key/mrk-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"  # KMS key for encrypted AMI (if needed)

# --- User Data Script ---
# This script runs automatically when each EC2 instance launches
# Script below installs and configures Apache web server
user_data_script = <<-EOF
  #!/bin/bash
  
  # Log everything to a file for troubleshooting
  exec > >(tee /var/log/user-data.log) 2>&1
  echo "=== User Data Started at $(date) ==="
  
  # Update system packages (non-critical if it fails)
  echo "Updating packages..."
  dnf update -y || echo "Package update failed, continuing..."
  
  # Install Apache web server (critical - script fails if this fails)
  echo "Installing httpd..."
  dnf install -y httpd || {
    echo "Failed to install httpd"
    exit 1
  }
  
  # Start Apache and configure it to start on boot
  echo "Starting httpd..."
  systemctl start httpd
  systemctl enable httpd
  
  # Create a health check endpoint for the Load Balancer
  # The ALB will ping this endpoint to verify the instance is healthy
  echo "Creating health endpoint..."
  echo "OK" > /var/www/html/health
  
  # Create a simple homepage showing the hostname
  echo "Creating index page..."
  echo "Hello from $(hostname)" > /var/www/html/index.html
  
  # Set proper file permissions (readable by web server)
  chmod 644 /var/www/html/health
  chmod 644 /var/www/html/index.html
  
  # Verify that Apache is running correctly
  echo "Verifying httpd status..."
  if systemctl is-active --quiet httpd; then
    echo "✅ Apache is running"
    curl -s http://localhost/health && echo "✅ Health check OK"
  else
    echo "❌ Apache is NOT running"
    systemctl status httpd
    exit 1
  fi
  
  echo "=== User Data Completed at $(date) ==="
EOF

# ============================================================================
# DNS & SSL/TLS CERTIFICATE CONFIGURATION
# ============================================================================
# These settings configure your custom domain name and HTTPS certificate

# IMPORTANT: Replace these with your actual Route53 hosted zone details
domain_name = "basic-iaas.your-account-alias-dev.np.org-aws.net" # Your application's domain name (where users access your app)
zone_name   = "your-account-alias-dev.np.org-aws.net"            # Your Route53 hosted zone (parent domain)
zone_id     = "ZXXXXXXXXXXXXXXXXXX"                               # Route53 hosted zone ID

# Enable CloudWatch monitoring for certificate expiration (optional)
enable_certificate_monitoring = true # Set to true to receive alerts when certificate is about to expire

# ============================================================================
# DATABASE CONFIGURATION (Aurora PostgreSQL)
# ============================================================================
# Aurora is AWS's managed database service with automatic failover and scaling

# --- Database Engine ---
db_engine         = "aurora-postgresql" # Database type (PostgreSQL-compatible)
db_engine_version = "17.4"              # PostgreSQL version

# --- Database Credentials ---
# Note: The password is NOT stored here (security best practice)
# It will be automatically generated and stored in AWS Secrets Manager
db_name     = "basiciaasdev" # Database name (alphanumeric only, no hyphens)
db_username = "dbadmin"      # Master username for database access
db_port     = 5432           # PostgreSQL default port

# --- Database Cluster Configuration ---
db_instance_class   = "db.t3.medium" # Instance size to adapt according your need
db_writer_instances = 1              # Number of writer instances (handles writes)
db_reader_instances = 1              # Number of reader instances (handles reads, improves performance)

# --- Backup and Maintenance ---
db_backup_retention_period = 7                     # Keep backups for 7 days
db_backup_window           = "03:00-04:00"         # Daily backup window (UTC time, low-traffic period)
db_maintenance_window      = "sun:04:00-sun:05:00" # Weekly maintenance window (UTC time, Sunday early morning)


# ============================================================================
# IAM PERMISSIONS
# ============================================================================
# Permission boundary: A security control that limits the maximum permissions
# that IAM roles can have. This prevents privilege escalation.

permissions_boundary_arn = "arn:aws:iam::670943688569:policy/OrgPermissionBoundary"


# ============================================================================
# RESOURCE TAGS
# ============================================================================
# Tags are key-value pairs attached to AWS resources for organization,
# cost tracking, and automation. These tags will be applied to all resources.

tags = {
  Environment = "dev"                   # Environment identifier
  Pattern     = "basic-iaas-standalone" # Architecture pattern name
  ManagedBy   = "terraform"             # Indicates infrastructure is managed by Terraform
  CostCenter = "your-cost-center"              # Cost allocation tag
}


# ============================================================================
# MONITORING & ALERTING
# ============================================================================
# CloudWatch will send alerts to this email when something goes wrong

alert_email = "your-alert-email@example.com" # Email address for alarm notifications

# Database connection alarm threshold
# Alert will trigger if database connections exceed this value (potential issue)
database_connection_threshold = 80 # Maximum number of concurrent database connections before alerting
