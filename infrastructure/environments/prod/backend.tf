# ============================================================================
# TERRAFORM BACKEND CONFIGURATION - DEV ENVIRONMENT
# ============================================================================
# This file configures where Terraform stores its state file and how it
# locks state during operations. The backend configuration is provided
# dynamically at runtime via GitHub Actions workflow.
#
# What is Terraform backend?
# - Remote storage location for state file (terraform.tfstate)
# - State locking mechanism to prevent concurrent modifications
# - State versioning for history and rollback
# - Team collaboration (shared state)
#
# Why use S3 backend?
# - Centralized state storage (not local files)
# - Native S3 lockfile support prevents concurrent modifications
# - Versioning enabled (rollback capability)
# - Team collaboration (multiple users can access)
#
# Backend infrastructure (created by backend module):
# - S3 bucket: State file storage
# - Native S3 lockfile support: State locking
# - KMS key: State encryption
# ============================================================================

terraform {
  # ============================================================================
  # TERRAFORM VERSION REQUIREMENT
  # ============================================================================
  required_version = ">= 1.7.4"
  # Minimum Terraform version required to run this configuration


  # ============================================================================
  # BACKEND CONFIGURATION - S3 (Production)
  # ============================================================================
  backend "s3" {
  }
  # Configuration provided via -backend-config at terraform init
  # 
  # GitHub Actions workflow provides these values dynamically:
  # - bucket: {prefix}-terraform-backend-{region}-{account_id}
  # - key: {environment}/terraform.tfstate (e.g., dev/terraform.tfstate)
  # - region: eu-west-1
  # - encrypt: true (KMS encryption enabled)
  # - encrypt: true
  # - use_lockfile: true
  # 
  # Why dynamic configuration?
  # - Same code works across environments (dev, staging, prod)
  # - AWS account ID detected at runtime (multi-account support)
  # - No hardcoded values (infrastructure-as-code best practice)
  # - GitHub Actions constructs values automatically

  # ============================================================================
  # REQUIRED PROVIDERS - AWS Provider Version
  # ============================================================================
  required_providers {
    aws = {
      source  = "hashicorp/aws" # Official AWS provider from HashiCorp
      version = "~> 5.0"        # AWS provider version 5.x
      # "~> 5.0" means: Version 5.x (allows 5.0, 5.1, 5.2, but not 6.0)
    }
  }
}

# ============================================================================
# AWS PROVIDER CONFIGURATION - PRODUCTION
# ============================================================================
# Provider configuration defines AWS API interactions for production

provider "aws" {
  region = var.region # Production AWS region (e.g., eu-west-1)
  # Region configuration:
  # - All resources created in this region
  # - Regional services: EC2, RDS, ALB
  # - Global services: IAM, Route53 (region doesn't matter)

  # ============================================================================
  # DEFAULT TAGS - Applied to All Resources (PRODUCTION)
  # ============================================================================
  default_tags {
    tags = {
      Environment = "prod"           # Environment identifier (PRODUCTION)
      ManagedBy   = "terraform"      # Infrastructure management method
      Project     = var.app_id # Project identifier
      Account     = "prod"           # AWS account type (production account)
    }
  }
  # Default tags explained:
  # 
  # What are default tags?
  # - Automatically applied to ALL resources
  # - Consistent tagging across infrastructure
  # - No need to repeat in each resource
  # - Can be overridden per resource if needed  
}
