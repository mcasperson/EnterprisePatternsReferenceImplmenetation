terraform {
  required_providers {
    octopusdeploy = { source = "OctopusDeployLabs/octopusdeploy", version = "0.22.0" }
  }
}

resource "octopusdeploy_library_variable_set" "octopus_library_variable_set" {
  name = "This Instance"
  description = "Variables related to interacting with an Octopus server"
}

resource "octopusdeploy_variable" "octopus_api_key" {
  name = "ThisInstance.Api.Key"
  type = "Sensitive"
  description = "The API key of this Octopus instance"
  is_sensitive = true
  is_editable = true
  owner_id = octopusdeploy_library_variable_set.octopus_library_variable_set.id
  sensitive_value = "API-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
}

resource "octopusdeploy_variable" "octopus_internal_url" {
  name = "ThisInstance.Server.InternalUrl"
  type = "String"
  description = "The URL of this Octopus instance as seen when run from Octopus"
  is_sensitive = false
  is_editable = true
  owner_id = octopusdeploy_library_variable_set.octopus_library_variable_set.id
  value = "http://localhost:8080"
}

resource "octopusdeploy_variable" "octopus_external_url" {
  name = "ThisInstance.Server.Url"
  type = "String"
  description = "The URL of this Octopus instance as seen from a Docker container on the same network"
  is_sensitive = false
  is_editable = true
  owner_id = octopusdeploy_library_variable_set.octopus_library_variable_set.id
  value = "http://octopus:8080"
}