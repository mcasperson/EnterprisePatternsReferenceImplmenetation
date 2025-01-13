resource "octopusdeploy_tenant" "test_prod" {
  name        = "Test\\Production"
  description = "Tenant representing the test and production Octopus instance"
  tenant_tags = []
}

resource "octopusdeploy_tenant_project" "test_prod_project_environment" {
  environment_ids = [
    data.octopusdeploy_environments.sync.environments[0].id
  ]
  project_id      = data.octopusdeploy_projects.project.projects[0].id
  tenant_id       = octopusdeploy_tenant.test_prod.id
}

resource "octopusdeploy_tenant_common_variable" "octopus_apikey" {
  library_variable_set_id = data.octopusdeploy_library_variable_sets.octopus_server.library_variable_sets[0].id
  template_id             = tolist([
    for tmp in data.octopusdeploy_library_variable_sets.octopus_server.library_variable_sets[0].template :
    tmp.id if tmp.name == "ManagedTenant.Octopus.ApiKey"
  ])[0]
  tenant_id               = octopusdeploy_tenant.test_prod.id
  value                   = "API-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
}

resource "octopusdeploy_tenant_common_variable" "octopus_url" {
  library_variable_set_id = data.octopusdeploy_library_variable_sets.octopus_server.library_variable_sets[0].id
  template_id             = tolist([
    for tmp in data.octopusdeploy_library_variable_sets.octopus_server.library_variable_sets[0].template :
    tmp.id if tmp.name == "ManagedTenant.Octopus.Url"
  ])[0]
  tenant_id               = octopusdeploy_tenant.test_prod.id
  value                   = "http://octopus:8080"
}

resource "octopusdeploy_tenant_common_variable" "octopus_spaceid" {
  library_variable_set_id = data.octopusdeploy_library_variable_sets.octopus_server.library_variable_sets[0].id
  template_id             = tolist([
    for tmp in data.octopusdeploy_library_variable_sets.octopus_server.library_variable_sets[0].template :
    tmp.id if tmp.name == "ManagedTenant.Octopus.SpaceId"
  ])[0]
  tenant_id               = octopusdeploy_tenant.test_prod.id
  value                   = "Spaces-3"
}

