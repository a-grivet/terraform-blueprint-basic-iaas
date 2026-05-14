# ============================================================================
# BACKEND BOOTSTRAP VARIABLES - variables.tf
# ============================================================================
# The bootstrap wrapper needs only the values required to name and place the
# shared backend resources.
# ============================================================================

variable "region" {
  description = "AWS region where backend resources are created"
  type        = string
}

variable "prefix" {
  description = "Prefix used to name backend resources"
  type        = string
}
