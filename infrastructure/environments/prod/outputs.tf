# ============================================================================
# TERRAFORM OUTPUTS - PROD ENVIRONMENT
# ============================================================================
# This file defines output values that display information after terraform apply.
# Outputs are useful for:
# - Displaying important resource identifiers
# - Providing access URLs and connection strings
# - Passing data to other Terraform configurations
# - Documenting deployed infrastructure

# ============================================================================
# APPLICATION ACCESS - User-Facing URLs
# ============================================================================

output "application_url" {
  description = "Application URL (HTTPS)"
  value       = "https://${var.domain_name}"
  # Primary application URL with HTTPS
  # Example: https://app.prod.your-org.com
}

output "alb_dns_name" {
  description = "ALB DNS name"
  value       = module.alb.alb_dns_name
  # Application Load Balancer DNS name
  # Example: myapp-prod-alb-1234567890.eu-west-1.elb.amazonaws.com
  # 
  # When to use:
  # - Before DNS record created (direct ALB access)
  # - Troubleshooting DNS issues
  # - Testing load balancer directly
}

# ============================================================================
# KMS ENCRYPTION KEYS - Resource Identifiers
# ============================================================================

output "kms_ebs_key_id" {
  description = "KMS key ID for EBS encryption"
  value       = module.kms_ebs.key_id
  # KMS key identifier for EBS volume encryption
}

output "kms_rds_key_id" {
  description = "KMS key ID for RDS encryption"
  value       = module.kms_rds.key_id
  # KMS key identifier for Aurora database encryption
}

output "kms_secrets_key_id" {
  description = "KMS key ID for Secrets Manager encryption"
  value       = module.kms_secrets.key_id
  # KMS key identifier for Secrets Manager encryption
}

# ============================================================================
# AUTO SCALING GROUP - Compute Resources
# ============================================================================

output "asg_name" {
  description = "Auto Scaling Group name"
  value       = module.asg.autoscaling_group_name
  # Auto Scaling Group identifier
}

output "asg_arn" {
  description = "Auto Scaling Group ARN"
  value       = module.asg.autoscaling_group_arn
  # Auto Scaling Group Amazon Resource Name
}

# ============================================================================
# SSM PARAMETER STORE - Database Configuration
# ============================================================================

output "database_ssm_paths" {
  description = "SSM Parameter Store paths for all database configuration parameters"
  value       = module.ssm_parameters.parameter_names
  # Map of all SSM parameter paths
  # Example:
  #   writer_endpoint = "/myapp/prod/database/writer-endpoint"
  #   reader_endpoint = "/myapp/prod/database/reader-endpoint"
  #   port            = "/myapp/prod/database/port"
  #   database_name   = "/myapp/prod/database/name"
  #   username        = "/myapp/prod/database/username"
  #   secret_arn      = "/myapp/prod/database/secret-arn"
}

output "database_ssm_path_prefix" {
  description = "SSM Parameter Store path prefix (use for bulk retrieval with get-parameters-by-path)"
  value       = module.ssm_parameters.path_prefix
}

output "database_ssm_arns" {
  description = "SSM Parameter ARNs for IAM policy creation"
  value       = module.ssm_parameters.parameter_arns
  # Map of SSM parameter ARNs for IAM policies
  # Example:
  #   writer_endpoint = "arn:aws:ssm:eu-west-1:123456789012:parameter/myapp/prod/database/writer-endpoint"
  #   reader_endpoint = "arn:aws:ssm:eu-west-1:123456789012:parameter/myapp/prod/database/reader-endpoint"
}
