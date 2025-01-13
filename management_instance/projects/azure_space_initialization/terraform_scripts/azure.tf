terraform {
  required_providers {
    octopusdeploy = { source = "OctopusDeployLabs/octopusdeploy", version = "0.22.0" }
  }
}

terraform {
  backend "pg" {
    conn_str = "postgres://terraform:terraform@terraformdb:5432/project_initialize_azure_space?sslmode=disable"
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

variable "octopus_url" {
  type        = string
  nullable    = false
  sensitive   = false
  description = "The ID of the Octopus space to populate."
  default     = "Spaces-1"
}

variable "octopus_apikey" {
  type        = string
  nullable    = false
  sensitive   = false
  description = "The ID of the Octopus space to populate."
  default     = "Spaces-1"
}

provider "octopusdeploy" {
  address  = var.octopus_url
  api_key  = var.octopus_apikey
  space_id = var.octopus_space_id
}

variable "azure_application_id" {
  type        = string
  nullable    = false
  sensitive   = false
  description = "The Azure application ID."
}

variable "azure_subscription_id" {
  type        = string
  nullable    = false
  sensitive   = false
  description = "The Azure subscription ID."
}

variable "azure_password" {
  type        = string
  nullable    = false
  sensitive   = true
  description = "The Azure password."
}

variable "azure_tenant_id" {
  type        = string
  nullable    = false
  sensitive   = false
  description = "The Azure tenant ID."
}

resource "octopusdeploy_azure_service_principal" "account_azure" {
  description                       = "Azure Account"
  name                              = "Azure"
  environments                      = null
  tenant_tags                       = []
  tenants                           = null
  tenanted_deployment_participation = "TenantedOrUntenanted"
  application_id                    = var.azure_application_id
  password                          = var.azure_password
  subscription_id                   = var.azure_subscription_id
  tenant_id                         = var.azure_tenant_id
}