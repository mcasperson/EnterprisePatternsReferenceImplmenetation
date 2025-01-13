terraform {
  backend "pg" {
    conn_str = "postgres://terraform:terraform@localhost:15432/account_azure?sslmode=disable"
  }
}

terraform {
  required_providers {
    octopusdeploy = { source = "OctopusDeployLabs/octopusdeploy", version = "0.22.0" }
  }
}

variable "octopus_space_id" {
  type        = string
  nullable    = false
  sensitive   = false
  description = "The ID of the Octopus space to populate."
  default     = "Spaces-1"

  validation {
    condition     = length(var.octopus_space_id) > 7 && substr(var.octopus_space_id, 0, 7) == "Spaces-"
    error_message = "The space_id value must be a valid Space id, starting with \"Spaces-\"."
  }
}

provider "octopusdeploy" {
  address  = "http://localhost:18080"
  api_key  = "API-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
  space_id = var.octopus_space_id
}

variable "azure_application_id" {
  type        = string
  nullable    = false
  sensitive   = false
  description = "The Azure application ID."
  default     = "00000000-0000-0000-0000-000000000000"
}

variable "azure_subscription_id" {
  type        = string
  nullable    = false
  sensitive   = false
  description = "The Azure subscription ID."
  default     = "00000000-0000-0000-0000-000000000000"
}

variable "azure_password" {
  type        = string
  nullable    = false
  sensitive   = true
  description = "The Azure password."
  default     = "dummy"
}

variable "azure_tenant_id" {
  type        = string
  nullable    = false
  sensitive   = false
  description = "The Azure tenant ID."
  default     = "00000000-0000-0000-0000-000000000000"
}

module "octopus" {
  source       = "../octopus"
  azure_application_id = var.azure_application_id
  azure_subscription_id = var.azure_subscription_id
  azure_password = var.azure_password
  azure_tenant_id = var.azure_tenant_id
}