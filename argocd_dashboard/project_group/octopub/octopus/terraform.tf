terraform {
  required_providers {
    octopusdeploy = { source = "OctopusDeployLabs/octopusdeploy", version = "0.22.0" }
  }
}

resource "octopusdeploy_project_group" "project_group_overview_dashboard" {
  name        = "Scenario 1: Overview Dashboard"
  description = "Displays the status of ArgoCD deployments"
}

resource "octopusdeploy_project_group" "project_group_environment_progression" {
  name        = "Scenario 2: Environment Progression"
  description = "Manages the promotion of ArgoCD applications to higher environments"
}

resource "octopusdeploy_project_group" "project_group_platform_engineering" {
  name        = "Scenario 3: Platform Engineering"
  description = "Creates new template ArgoCD projects"
}

