# ====================================
# TFLint Configuration
# ====================================
# TFLint is a Terraform linter that helps identify potential issues
# in Terraform configurations before deployment.
#
# Documentation: https://github.com/terraform-linters/tflint

# ====================================
# Plugin Configuration
# ====================================

# Enable the Terraform plugin with recommended rules
plugin "terraform" {
  enabled = true
  preset  = "recommended"
}

# Enable AWS plugin for AWS-specific linting
plugin "aws" {
  enabled = true
  version = "0.32.0"
  source  = "github.com/terraform-linters/tflint-ruleset-aws"
}

# ====================================
# Global Rules
# ====================================

# Enforce terraform version constraint
rule "terraform_required_version" {
  enabled = true
}

# Enforce terraform providers version constraint
rule "terraform_required_providers" {
  enabled = true
}

# Check for unused declarations
rule "terraform_unused_declarations" {
  enabled = true
}

# Check for deprecated syntax
rule "terraform_deprecated_index" {
  enabled = true
}

rule "terraform_deprecated_interpolation" {
  enabled = true
}

# ====================================
# Naming Conventions
# ====================================

# Disable strict naming convention (too restrictive for multi-env)
# We use prefixes like "dev-" and "prod-" which may violate standard conventions
rule "terraform_naming_convention" {
  enabled = false
}

# ====================================
# Documentation
# ====================================

# Require descriptions for variables
rule "terraform_documented_variables" {
  enabled = true
}

# Require descriptions for outputs
rule "terraform_documented_outputs" {
  enabled = true
}

# ====================================
# Best Practices
# ====================================

# Check for module pinning
rule "terraform_module_pinned_source" {
  enabled = true
  style   = "flexible"  # Allow local modules and flexible versioning
}

# Check for valid module versions
rule "terraform_module_version" {
  enabled = true
}

# Enforce use of terraform workspace (disabled for multi-account)
rule "terraform_workspace_remote" {
  enabled = false  # We don't use workspaces in multi-account setup
}

# ====================================
# Type Checking
# ====================================

rule "terraform_typed_variables" {
  enabled = true
}

# ====================================
# AWS-Specific Rules
# ====================================

# S3 bucket rules
rule "aws_s3_bucket_invalid_bucket_name" {
  enabled = true
}

# IAM rules
rule "aws_iam_policy_document_gov_friendly_arns" {
  enabled = false  # Not required for commercial AWS
}

rule "aws_iam_role_policy_too_long_policy" {
  enabled = true
}

# EC2 rules
rule "aws_instance_invalid_ami" {
  enabled = true
}

rule "aws_instance_invalid_type" {
  enabled = true
}

rule "aws_instance_previous_type" {
  enabled = true
}

# DynamoDB rules
rule "aws_dynamodb_table_invalid_billing_mode" {
  enabled = true
}

# ====================================
# Disabled Rules
# ====================================
# These rules are disabled because they are too strict or not applicable
# to our multi-account setup

# Allow resource count/for_each (we use it intentionally)
rule "terraform_standard_module_structure" {
  enabled = false
}

# We allow inline policies for simplicity
rule "aws_iam_policy_attachment_exclusive" {
  enabled = false
}