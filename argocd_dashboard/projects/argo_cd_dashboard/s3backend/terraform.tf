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
  address  = var.octopus_server
  api_key  = "API-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
  space_id = var.octopus_space_id
}

variable "octopus_server" {
  type        = string
  nullable    = false
  sensitive   = false
  description = "The URL of the Octopus server e.g. https://myinstance.octopus.app."
  default     = "http://localhost:18080"
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

variable "project_name" {
  default = "Overview: Octopub Frontend"
  type    = string
}

variable "project_description" {
  default = "This project is used to manage the deployment of the Octopub Frontend via ArgoCD."
  type    = string
}

variable "argocd_application_development" {
  default = "argocd/octopub-frontend-development"
  type    = string
}

variable "argocd_application_test" {
  default = "argocd/octopub-frontend-test"
  type    = string
}

variable "argocd_application_production" {
  default = "argocd/octopub-frontend-production"
  type    = string
}

variable "argocd_version_image" {
  default = "octopussamples/octopub-frontend"
  type    = string
}

variable "argocd_sbom_version_image" {
  default = "octopussamples/octopub-frontend"
  type    = string
}

module "octopus" {
  source = "../octopus"
  project_name                   = var.project_name
  project_description            = var.project_description
  argocd_application_development = var.argocd_application_development
  argocd_application_test        = var.argocd_application_test
  argocd_application_production  = var.argocd_application_production
  argocd_version_image           = var.argocd_version_image
  argocd_sbom_version_image      = var.argocd_sbom_version_image
}