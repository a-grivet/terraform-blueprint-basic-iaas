# ============================================================================
# BACKEND BOOTSTRAP VERSIONS - versions.tf
# ============================================================================
# Keep the bootstrap wrapper aligned with the Terraform and AWS provider
# versions supported by the centralized backend module.
# ============================================================================

terraform {
  required_version = ">= 1.7.4"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}
