terraform {
  backend "pg" {
    conn_str = "postgres://terraform:terraform@localhost:15432/spaces?sslmode=disable"
  }
}

terraform {
  required_providers {
    octopusdeploy = { source = "OctopusDeployLabs/octopusdeploy", version = "0.22.0" }
  }
}

provider "octopusdeploy" {
  address  = "http://localhost:18080"
  api_key  = "API-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
  space_id = "Spaces-1"
}

variable "space_name" {
  type        = string
  nullable    = false
  sensitive   = false
  description = "The name of the new space, which is the same as the tenant name."
}

module "octopus" {
  source     = "../octopus"
  space_name = var.space_name
}