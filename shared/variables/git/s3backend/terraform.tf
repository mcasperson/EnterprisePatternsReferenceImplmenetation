terraform {
  backend "s3" {
  }
}

terraform {
  required_providers {
    octopusdeploy = { source = "OctopusDeployLabs/octopusdeploy", version = "0.22.0" }
  }
}

provider "octopusdeploy" {
  address  = "${var.octopus_server}"
  api_key  = "${var.octopus_apikey}"
  space_id = "${var.octopus_space_id}"
}

variable "octopus_server" {
  type        = string
  nullable    = false
  sensitive   = false
  description = "The URL of the Octopus server e.g. https://myinstance.octopus.app."
}

variable "octopus_apikey" {
  type        = string
  nullable    = false
  sensitive   = true
  description = "The API key used to access the Octopus server. See https://octopus.com/docs/octopus-rest-api/how-to-create-an-api-key for details on creating an API key."
}

variable "octopus_space_id" {
  type        = string
  nullable    = false
  sensitive   = false
  description = "The ID of the Octopus space to populate."

  validation {
    condition     = length(var.octopus_space_id) > 7 && substr(var.octopus_space_id, 0, 7) == "Spaces-"
    error_message = "The space_id value must be a valid Space id, starting with \"Spaces-\"."
  }
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
