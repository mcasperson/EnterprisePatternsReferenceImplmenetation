terraform {
  backend "pg" {
    conn_str = "postgres://terraform:terraform@localhost:15432/serialize_and_deploy?sslmode=disable"
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

variable "project_name" {
  type        = string
  nullable    = false
  sensitive   = false
  description = "The name of the project to attach the runbooks to."
}

variable "compose_project" {
  type        = string
  nullable    = false
  sensitive   = false
  description = "The name of the project containing the runbook required to compose in global resource"
  default     = ""
}

variable "compose_runbook" {
  type        = string
  nullable    = false
  sensitive   = false
  description = "The name of the runbook required to compose in global resource"
  default     = ""
}

variable "create_space_project" {
  type        = string
  nullable    = false
  sensitive   = false
  description = "The name of the project containing the runbook required to create the space"
  default     = ""
}

variable "create_space_runbook" {
  type        = string
  nullable    = false
  sensitive   = false
  description = "The name of the runbook required to create the space"
  default     = ""
}

module "octopus" {
  source                = "../octopus"
  project_name          = var.project_name
  compose_project       = var.compose_project
  compose_runbook       = var.compose_runbook
  create_space_project  = var.create_space_project
  create_space_runbook  = var.create_space_runbook
}