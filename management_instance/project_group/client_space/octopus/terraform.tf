terraform {
  required_providers {
    octopusdeploy = { source = "OctopusDeployLabs/octopusdeploy", version = "0.22.0" }
  }
}

resource "octopusdeploy_project_group" "project_group_client_space" {
  name        = "__ Client Space"
  description = "Holds the projects that create and manage client spaces"
}
