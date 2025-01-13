terraform {
  required_providers {
    octopusdeploy = { source = "OctopusDeployLabs/octopusdeploy", version = "0.22.0" }
  }
}

data "octopusdeploy_library_variable_sets" "variable" {
  partial_name = "This Instance"
  skip         = 0
  take         = 1
}

data "octopusdeploy_library_variable_sets" "octopus_server" {
  partial_name = "Octopus Server"
  skip         = 0
  take         = 1
}

data "octopusdeploy_library_variable_sets" "azure" {
  partial_name = "Azure"
  skip         = 0
  take         = 1
}

data "octopusdeploy_library_variable_sets" "docker" {
  partial_name = "Docker"
  skip         = 0
  take         = 1
}

data "octopusdeploy_library_variable_sets" "k8s" {
  partial_name = "Kubernetes"
  skip         = 0
  take         = 1
}

data "octopusdeploy_library_variable_sets" "slack" {
  partial_name = "Client Slack"
  skip         = 0
  take         = 1
}

data "octopusdeploy_environments" "development" {
  ids          = []
  partial_name = "Development"
  skip         = 0
  take         = 1
}

data "octopusdeploy_environments" "test" {
  ids          = []
  partial_name = "Test"
  skip         = 0
  take         = 1
}

data "octopusdeploy_environments" "production" {
  ids          = []
  partial_name = "Production"
  skip         = 0
  take         = 1
}

data "octopusdeploy_environments" "sync" {
  ids          = []
  partial_name = "Sync"
  skip         = 0
  take         = 1
}


data "octopusdeploy_projects" "project" {
  cloned_from_project_id = null
  ids                    = []
  is_clone               = false
  name                   = "Hello World"
  partial_name           = null
  skip                   = 0
  take                   = 1
}

data "octopusdeploy_projects" "project_cac" {
  cloned_from_project_id = null
  ids                    = []
  is_clone               = false
  name                   = "Hello World CaC"
  partial_name           = null
  skip                   = 0
  take                   = 1
}

data "octopusdeploy_projects" "project_init_space" {
  cloned_from_project_id = null
  ids                    = []
  is_clone               = false
  name                   = "__ Compose Azure Resources"
  partial_name           = null
  skip                   = 0
  take                   = 1
}

data "octopusdeploy_projects" "project_init_space_k8s" {
  cloned_from_project_id = null
  ids                    = []
  is_clone               = false
  name                   = "__ Compose K8S Resources"
  partial_name           = null
  skip                   = 0
  take                   = 1
}

data "octopusdeploy_projects" "project_create_client_space" {
  cloned_from_project_id = null
  ids                    = []
  is_clone               = false
  name                   = "__ Create Client Space"
  partial_name           = null
  skip                   = 0
  take                   = 1
}

data "octopusdeploy_projects" "project_web_app_cac" {
  cloned_from_project_id = null
  ids                    = []
  is_clone               = false
  name                   = "Azure Web App CaC"
  partial_name           = null
  skip                   = 0
  take                   = 1
}

data "octopusdeploy_projects" "project_k8s_microservice_template" {
  cloned_from_project_id = null
  ids                    = []
  is_clone               = false
  name                   = "K8S Microservice Template"
  partial_name           = null
  skip                   = 0
  take                   = 1
}

variable "slack_bot_token" {
  type        = string
  nullable    = false
  sensitive   = false
  description = "The Slack Bot Token"
  default     = "dummy"
}

variable "slack_support_users" {
  type        = string
  nullable    = false
  sensitive   = false
  description = "The Slack support users"
  default     = "dummy"
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

variable "docker_username" {
  type        = string
  nullable    = false
  sensitive   = true
  description = "The DOcker username."
}

variable "docker_password" {
  type        = string
  nullable    = false
  sensitive   = false
  description = "The Docker password"
}