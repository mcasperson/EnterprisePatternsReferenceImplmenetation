terraform {
  required_providers {
    octopusdeploy = { source = "OctopusDeployLabs/octopusdeploy", version = "0.22.0" }
  }
}

resource "octopusdeploy_tag_set" "type" {
  name        = "tenant_type"
  description = "Tenant Type"
  sort_order  = 0
}

resource "octopusdeploy_tag" "tag_regional" {
  name        = "regional"
  color       = "#333333"
  description = "A tenant representing a region"
  sort_order  = 2
  tag_set_id = octopusdeploy_tag_set.type.id
}