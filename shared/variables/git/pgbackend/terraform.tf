terraform {
  backend "pg" {
    conn_str = "postgres://terraform:terraform@localhost:15432/lib_var_git?sslmode=disable"
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

variable "git_username" {
  type    = string
  default = "dummy"
}

variable "git_password" {
  type      = string
  default   = "dummy"
  sensitive = true
}

variable "git_protocol" {
  type    = string
  default = "http"
}

variable "git_host" {
  type    = string
  default = "gitea:3000"
}

variable "git_organization" {
  type    = string
  default = "octopuscac"
}

module "octopus" {
  source           = "../octopus"
  git_username     = var.git_username
  git_password     = var.git_password
  git_protocol     = var.git_protocol
  git_host         = var.git_host
  git_organization = var.git_organization
}