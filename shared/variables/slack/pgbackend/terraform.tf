terraform {
  backend "pg" {
    conn_str = "postgres://terraform:terraform@localhost:15432/lib_var_slack?sslmode=disable"
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

variable "slack_bot_token" {
  type    = string
  default = "dummy"
}

variable "slack_support_users" {
  type    = string
  default = "dummy"
}

module "octopus" {
  source              = "../octopus"
  slack_bot_token     = var.slack_bot_token
  slack_support_users = var.slack_support_users
}