terraform {
  backend "pg" {
    conn_str = "postgres://terraform:terraform@localhost:15432/target_k8s?sslmode=disable"
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

variable "k8s_cluster_url" {
  type        = string
  nullable    = false
  sensitive   = false
  description = "The K8s url"
}

variable "k8s_client_cert" {
  type        = string
  nullable    = false
  sensitive   = true
  description = "The K8s client cert"
}

module "octopus" {
  source       = "../octopus"
  k8s_cluster_url = var.k8s_cluster_url
  k8s_client_cert = var.k8s_client_cert
}