# This file creates a bunch of generic tenants used to test deploying and managing projects across many spaces.
# generic_tenant_count is set to the required number of tenants (and defaults to zero).

variable "generic_tenant_count" {
  type        = string
  nullable    = false
  sensitive   = false
  description = "How many generic tenants to create."
  default     = "0"
}


resource "octopusdeploy_tenant" "generic" {
  count       = var.generic_tenant_count
  name        = "Generic ${count.index}"
  description = "A generic tenant use for load testing"
  tenant_tags = ["tenant_type/regional"]
}

resource "octopusdeploy_tenant_project" "generic_project_environment" {
  count       = var.generic_tenant_count
  environment_ids = [
    data.octopusdeploy_environments.development.environments[0].id,
    data.octopusdeploy_environments.test.environments[0].id,
    data.octopusdeploy_environments.production.environments[0].id,
    data.octopusdeploy_environments.sync.environments[0].id
  ]
  project_id = data.octopusdeploy_projects.project.projects[0].id
  tenant_id  = octopusdeploy_tenant.generic[count.index].id
}

resource "octopusdeploy_tenant_project" "generic_project_cac_environment" {
  count       = var.generic_tenant_count
  environment_ids = [
    data.octopusdeploy_environments.development.environments[0].id,
    data.octopusdeploy_environments.test.environments[0].id,
    data.octopusdeploy_environments.production.environments[0].id,
    data.octopusdeploy_environments.sync.environments[0].id
  ]
  project_id = data.octopusdeploy_projects.project_cac.projects[0].id
  tenant_id  = octopusdeploy_tenant.generic[count.index].id
}

resource "octopusdeploy_tenant_project" "generic_project_web_app_cac_environment" {
  count       = var.generic_tenant_count
  environment_ids = [
    data.octopusdeploy_environments.development.environments[0].id,
    data.octopusdeploy_environments.test.environments[0].id,
    data.octopusdeploy_environments.production.environments[0].id,
    data.octopusdeploy_environments.sync.environments[0].id
  ]
  project_id = data.octopusdeploy_projects.project_web_app_cac.projects[0].id
  tenant_id  = octopusdeploy_tenant.generic[count.index].id
}

resource "octopusdeploy_tenant_project" "generic_project_init_space_environment" {
  count       = var.generic_tenant_count
  environment_ids = [
    data.octopusdeploy_environments.sync.environments[0].id
  ]
  project_id = data.octopusdeploy_projects.project_init_space.projects[0].id
  tenant_id  = octopusdeploy_tenant.generic[count.index].id
}

resource "octopusdeploy_tenant_project" "generic_project_init_space_k8s_environment" {
  count       = var.generic_tenant_count
  environment_ids = [
    data.octopusdeploy_environments.sync.environments[0].id
  ]
  project_id = data.octopusdeploy_projects.project_init_space_k8s.projects[0].id
  tenant_id  = octopusdeploy_tenant.generic[count.index].id
}

resource "octopusdeploy_tenant_project" "generic_project_create_client_space_environment" {
  count       = var.generic_tenant_count
  environment_ids = [
    data.octopusdeploy_environments.sync.environments[0].id
  ]
  project_id = data.octopusdeploy_projects.project_create_client_space.projects[0].id
  tenant_id  = octopusdeploy_tenant.generic[count.index].id
}

resource "octopusdeploy_tenant_project" "generic_project_k8s_microservice_template_environment" {
  count       = var.generic_tenant_count
  environment_ids = [
    data.octopusdeploy_environments.sync.environments[0].id
  ]
  project_id = data.octopusdeploy_projects.project_k8s_microservice_template.projects[0].id
  tenant_id  = octopusdeploy_tenant.generic[count.index].id
}

resource "octopusdeploy_tenant_common_variable" "generic_octopus_apikey" {
  count                   = var.generic_tenant_count
  library_variable_set_id = data.octopusdeploy_library_variable_sets.octopus_server.library_variable_sets[0].id
  template_id             = tolist([
    for tmp in data.octopusdeploy_library_variable_sets.octopus_server.library_variable_sets[0].template :
    tmp.id if tmp.name == "ManagedTenant.Octopus.ApiKey"
  ])[
  0
  ]
  tenant_id = octopusdeploy_tenant.generic[count.index].id
  value     = "API-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
  depends_on = [
    octopusdeploy_tenant_project.generic_project_environment,
    octopusdeploy_tenant_project.generic_project_cac_environment,
    octopusdeploy_tenant_project.generic_project_web_app_cac_environment,
    octopusdeploy_tenant_project.generic_project_init_space_environment,
    octopusdeploy_tenant_project.generic_project_init_space_k8s_environment,
    octopusdeploy_tenant_project.generic_project_create_client_space_environment,
    octopusdeploy_tenant_project.generic_project_k8s_microservice_template_environment,
  ]
}

resource "octopusdeploy_tenant_common_variable" "generic_octopus_spaceid" {
  count                   = var.generic_tenant_count
  library_variable_set_id = data.octopusdeploy_library_variable_sets.octopus_server.library_variable_sets[0].id
  template_id             = tolist([
    for tmp in data.octopusdeploy_library_variable_sets.octopus_server.library_variable_sets[0].template :
    tmp.id if tmp.name == "ManagedTenant.Octopus.Url"
  ])[
  0
  ]
  tenant_id = octopusdeploy_tenant.generic[count.index].id
  value     = "http://octopus:8080"
  depends_on = [
    octopusdeploy_tenant_project.generic_project_environment,
    octopusdeploy_tenant_project.generic_project_cac_environment,
    octopusdeploy_tenant_project.generic_project_web_app_cac_environment,
    octopusdeploy_tenant_project.generic_project_init_space_environment,
    octopusdeploy_tenant_project.generic_project_init_space_k8s_environment,
    octopusdeploy_tenant_project.generic_project_create_client_space_environment,
    octopusdeploy_tenant_project.generic_project_k8s_microservice_template_environment,
  ]
}

resource "octopusdeploy_tenant_common_variable" "generic_azure_application_id" {
  count                   = var.generic_tenant_count
  library_variable_set_id = data.octopusdeploy_library_variable_sets.azure.library_variable_sets[0].id
  template_id             = tolist([
    for tmp in data.octopusdeploy_library_variable_sets.azure.library_variable_sets[0].template :
    tmp.id if tmp.name == "Tenant.Azure.ApplicationId"
  ])[
  0
  ]
  tenant_id = octopusdeploy_tenant.generic[count.index].id
  value     = "00000000-0000-0000-0000-000000000000"
  depends_on = [
    octopusdeploy_tenant_project.generic_project_environment,
    octopusdeploy_tenant_project.generic_project_cac_environment,
    octopusdeploy_tenant_project.generic_project_web_app_cac_environment,
    octopusdeploy_tenant_project.generic_project_init_space_environment,
    octopusdeploy_tenant_project.generic_project_init_space_k8s_environment,
    octopusdeploy_tenant_project.generic_project_create_client_space_environment,
    octopusdeploy_tenant_project.generic_project_k8s_microservice_template_environment,
  ]
}

resource "octopusdeploy_tenant_common_variable" "generic_azure_subscription_id" {
  count                   = var.generic_tenant_count
  library_variable_set_id = data.octopusdeploy_library_variable_sets.azure.library_variable_sets[0].id
  template_id             = tolist([
    for tmp in data.octopusdeploy_library_variable_sets.azure.library_variable_sets[0].template :
    tmp.id if tmp.name == "Tenant.Azure.SubscriptionId"
  ])[
  0
  ]
  tenant_id = octopusdeploy_tenant.generic[count.index].id
  value     = "00000000-0000-0000-0000-000000000000"
  depends_on = [
    octopusdeploy_tenant_project.generic_project_environment,
    octopusdeploy_tenant_project.generic_project_cac_environment,
    octopusdeploy_tenant_project.generic_project_web_app_cac_environment,
    octopusdeploy_tenant_project.generic_project_init_space_environment,
    octopusdeploy_tenant_project.generic_project_init_space_k8s_environment,
    octopusdeploy_tenant_project.generic_project_create_client_space_environment,
    octopusdeploy_tenant_project.generic_project_k8s_microservice_template_environment,
  ]
}

resource "octopusdeploy_tenant_common_variable" "generic_azure_tenant_id" {
  count                   = var.generic_tenant_count
  library_variable_set_id = data.octopusdeploy_library_variable_sets.azure.library_variable_sets[0].id
  template_id             = tolist([
    for tmp in data.octopusdeploy_library_variable_sets.azure.library_variable_sets[0].template :
    tmp.id if tmp.name == "Tenant.Azure.TenantId"
  ])[
  0
  ]
  tenant_id = octopusdeploy_tenant.generic[count.index].id
  value     = "00000000-0000-0000-0000-000000000000"
  depends_on = [
    octopusdeploy_tenant_project.generic_project_environment,
    octopusdeploy_tenant_project.generic_project_cac_environment,
    octopusdeploy_tenant_project.generic_project_web_app_cac_environment,
    octopusdeploy_tenant_project.generic_project_init_space_environment,
    octopusdeploy_tenant_project.generic_project_init_space_k8s_environment,
    octopusdeploy_tenant_project.generic_project_create_client_space_environment,
    octopusdeploy_tenant_project.generic_project_k8s_microservice_template_environment,
  ]
}

resource "octopusdeploy_tenant_common_variable" "generic_azure_password" {
  count                   = var.generic_tenant_count
  library_variable_set_id = data.octopusdeploy_library_variable_sets.azure.library_variable_sets[0].id
  template_id             = tolist([
    for tmp in data.octopusdeploy_library_variable_sets.azure.library_variable_sets[0].template :
    tmp.id if tmp.name == "Tenant.Azure.Password"
  ])[
  0
  ]
  tenant_id = octopusdeploy_tenant.generic[count.index].id
  value     = "blah"
  depends_on = [
    octopusdeploy_tenant_project.generic_project_environment,
    octopusdeploy_tenant_project.generic_project_cac_environment,
    octopusdeploy_tenant_project.generic_project_web_app_cac_environment,
    octopusdeploy_tenant_project.generic_project_init_space_environment,
    octopusdeploy_tenant_project.generic_project_init_space_k8s_environment,
    octopusdeploy_tenant_project.generic_project_create_client_space_environment,
    octopusdeploy_tenant_project.generic_project_k8s_microservice_template_environment,
  ]
}

resource "octopusdeploy_tenant_common_variable" "generic_k8s_cert" {
  count                   = var.generic_tenant_count
  library_variable_set_id = data.octopusdeploy_library_variable_sets.k8s.library_variable_sets[0].id
  template_id             = tolist([
    for tmp in data.octopusdeploy_library_variable_sets.k8s.library_variable_sets[0].template :
    tmp.id if tmp.name == "Tenant.K8S.CertificateData"
  ])[
  0
  ]
  tenant_id = octopusdeploy_tenant.generic[count.index].id
  value     = "LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSURJVENDQWdtZ0F3SUJBZ0lJVEZqeGZIbndwUW93RFFZSktvWklodmNOQVFFTEJRQXdGVEVUTUJFR0ExVUUKQXhNS2EzVmlaWEp1WlhSbGN6QWVGdzB5TXpBMU1EUXdPRE14TWpSYUZ3MHlOREExTURNd09ETXhNalZhTURReApGekFWQmdOVkJBb1REbk41YzNSbGJUcHRZWE4wWlhKek1Sa3dGd1lEVlFRREV4QnJkV0psY201bGRHVnpMV0ZrCmJXbHVNSUlCSWpBTkJna3Foa2lHOXcwQkFRRUZBQU9DQVE4QU1JSUJDZ0tDQVFFQTJmaWE2MFZvME9MYWU3QUYKSGN3bjZIcit2aFpzZWt2MUQrb3RGdGFEelBIM085VTlRZFllN3hoVlVGelBuNGlBelYzeUliV1BEUER4a3N2VAo2OW1kNmovRW91WFRzSVVJNTFhdktVVk9pZ21KOTA4ZjB1REMwNlhuM2hOMWloT3BJdnZzOXZxcEZ4LzNDL3I1CjdkallsSDlQclZnTUthckxDNFU2SkMvOFhKOEZOSmE0WmhkWmZTMW85Q2VqQm9sZjZaSm9CRVBiM1lnek1oLzgKTUxQaDVRenNEdVRxMm85VGNHN3Z0SkducUVNUUVPUFpOaTZMNkFLOWNLRHNHL1B1N3U5V0xpdUU2SnpBdmNlawowck1WNHordjV1QmJVSXJ3OGJFL0V1NmhXSGJCWEVRNWgzSjRZOC9Gc0M1ZWd5eE9TNC8xNGE3LzFNTUYvLzZVCjlVNFdCd0lEQVFBQm8xWXdWREFPQmdOVkhROEJBZjhFQkFNQ0JhQXdFd1lEVlIwbEJBd3dDZ1lJS3dZQkJRVUgKQXdJd0RBWURWUjBUQVFIL0JBSXdBREFmQmdOVkhTTUVHREFXZ0JUNzRVcmZmM0diRzlSbVZZUjEyQXliK21wNAovakFOQmdrcWhraUc5dzBCQVFzRkFBT0NBUUVBV1I5RTlaN3NuSmR4RHgxVFU1RHliREdlR244R2NRZVhYMVA3Cmxod1ZMOW5EVXhsTW9WdzhzODE3V0pZSDdQL2Q2Mldoamwya0QxTjNOb1UvU0E4T1RpNS9ZZk1tK2pDUFlYblkKdUpLUnBKKzlzd09WOENoSzk1OU1MVXZISmVKNXRrM0ZhRW4wUUU1RUU5TjhObGhabzNpQ3I0dmloU2xXZEFCOApaTTlMaWFxbUNpMWNzeXc0ZCtwTEJBU0YxR2dZRHdkUkdqaXBrYUtWcGRYSDBnK0t1TTlqOEFuRUVGRFNRTDcxClJrQklnSXBRWmhweFU3RzdiYjBhQkUxS2JLU0s0SUJkMS95aUEwUzNsd3ROL1JVRFh6TmxKVTFHSmhRbHRmYVIKK1hCcHo0U2JRUFczSEJpYlZKdDkzL3VscWViaW5ramZHQ1M1WjFtbG9HY1JEanZrdGc9PQotLS0tLUVORCBDRVJUSUZJQ0FURS0tLS0tCi0tLS0tQkVHSU4gUlNBIFBSSVZBVEUgS0VZLS0tLS0KTUlJRW93SUJBQUtDQVFFQTJmaWE2MFZvME9MYWU3QUZIY3duNkhyK3ZoWnNla3YxRCtvdEZ0YUR6UEgzTzlVOQpRZFllN3hoVlVGelBuNGlBelYzeUliV1BEUER4a3N2VDY5bWQ2ai9Fb3VYVHNJVUk1MWF2S1VWT2lnbUo5MDhmCjB1REMwNlhuM2hOMWloT3BJdnZzOXZxcEZ4LzNDL3I1N2RqWWxIOVByVmdNS2FyTEM0VTZKQy84WEo4Rk5KYTQKWmhkWmZTMW85Q2VqQm9sZjZaSm9CRVBiM1lnek1oLzhNTFBoNVF6c0R1VHEybzlUY0c3dnRKR25xRU1RRU9QWgpOaTZMNkFLOWNLRHNHL1B1N3U5V0xpdUU2SnpBdmNlazByTVY0eit2NXVCYlVJcnc4YkUvRXU2aFdIYkJYRVE1CmgzSjRZOC9Gc0M1ZWd5eE9TNC8xNGE3LzFNTUYvLzZVOVU0V0J3SURBUUFCQW9JQkFRRFh4YzQyRUtQT0JJT2IKNVlkckUrcDlyU1A0TUdKNlBpNzk3aWRzY0RaUTcwWjdLSUJYYUF0L1RHdEgvbGhaNk5yNGNZTjc4eXNFK0k5cgpiZkwvaXBGVWpvT3RiaTI4bERWWUxPdUF3MmNZSnBFNURFN0loazdYRFdrVzRkUjlOekU3dkgrN2ppOU5BUXVpCkJIVGRDc2g3Vi93YjhRazVSaVZ4NWhURU5leHdFZmM3N0QyL2xXZlVQdElCNDBOUlFsZEkyUUgyT1dzdjdBNUIKTVYxMUx5NDRtMG5MNkh3VFUyQWNXZTlIV21YTlZTZlJFcW9LYnBMZVczMHYxZXpKMWhUSHlIYWE5em5mTUdKZgpjU1AramcvTURvMW1MRWFsN0hXT2hVVy95UmdvSFd6OVdFK2NBUVJHUjVrR2FCR3BmNkl3SmJYMkdoZ28wTGtmCndyQitiZzJCQW9HQkFQUHdlVEtJaEZwOGtmcGVpQjJhaW15TnFwRkJISGRHQmM3MFFwOFEzU1ZXRmpLS09qa1gKWFp6UHJwOFh6QWN0elNlRmZBeE5zcG92TXdBRklDZWViWEFVa3V5MzlEdnM0WU1xZ2tzNkVPMGE1Q3lGN0Q4WgpFUXQ0cHAxbGhyZktxSW9WTmNmT1RTTHFTejFQSmc0MC9oRzQyUHZmRjB6dk1sd08vL1RPWXFreEFvR0JBT1MvCmRBYzNPdnl3LzRwc3NMaVBVRmlwNUp1ZmMvaWJ4aVM4NVQ3TEY1eG9TWUNHaVR1Q2c0SVJoUUFQMEl0NGtoUUYKUTN3ck8yb09IVTNZaHJzOTY2VUMzNTFVZ280enhYWmQzQ0xuOEpDUjBJdWxpMFVhc0pMMVZEc29DVGwrc2F5Vwp1b3g1eldaK0dIWjAwanpTWWNYQW1WK1VwQ3pNOEVxS2pyZGhzR1MzQW9HQVIxTDJmTm9CcU50bmEwY2NrVnRRClFmRWlBQnFEa2pROUdvZTh1dm1aVDROZU5pVElaVXo1cUJIcFFzY1lkcmpqbFR5b1NvaWxRZ091NjhDVDZFR2cKU2ZjYUJuQzZ6cEt5VlVHbW13dzlTclprSk1oN2pPOXRWbWRPZ0JMaFV2ZkVVNnRqOENuWHorK2xWQ1hDUU1FcAowRkMxME44bjF1elJVcTFvRlZJSzh1RUNnWUFJSjByYmR2eURSVXZXZzBsSlN0SnlWcHZ2Y0IrU0hQdFRFK2lYCjlHVkREZlNRd0Rya0JDTHIzL1A5ckpLaVpnbk83T0VhNisrU09DNlROOFNWcC85ZVFsdjJINjBIcEpERlIxTXgKYTFNSDFDcTZ6NHZIU3N4QWNMNHYzWjEyankyR0dWbE02SXFKdkxUaWhBZDZZNFZZcHlUUVkxdjJ2TmRUME55RgpiTlg4d1FLQmdEVHJ0NERuQ1VVU0xRS3I3d3B5QVNkejIxam1PU3lNK1dTc2NQVVFxY2FZWWpWZTNnU1RidUV0CmYwODc2R1QxNEJNelg2NklFaEJvWVNrcGFQWUxvWmN3dGlnNThLb0UwKzJoREtxdDRLa2hZbWtBTkZ4TyttVDgKQW5mYmhOZDB1enJscEdPdnhmRkNiMEQ5cjlMaEhJaHVjSWpwWXYvNWc5a3NPaXVEbndSdQotLS0tLUVORCBSU0EgUFJJVkFURSBLRVktLS0tLQo="
  depends_on = [
    octopusdeploy_tenant_project.generic_project_environment,
    octopusdeploy_tenant_project.generic_project_cac_environment,
    octopusdeploy_tenant_project.generic_project_web_app_cac_environment,
    octopusdeploy_tenant_project.generic_project_init_space_environment,
    octopusdeploy_tenant_project.generic_project_init_space_k8s_environment,
    octopusdeploy_tenant_project.generic_project_create_client_space_environment,
    octopusdeploy_tenant_project.generic_project_k8s_microservice_template_environment,
  ]
}

resource "octopusdeploy_tenant_common_variable" "generic_k8s_url" {
  count                   = var.generic_tenant_count
  library_variable_set_id = data.octopusdeploy_library_variable_sets.k8s.library_variable_sets[0].id
  template_id             = tolist([
    for tmp in data.octopusdeploy_library_variable_sets.k8s.library_variable_sets[0].template :
    tmp.id if tmp.name == "Tenant.K8S.Url"
  ])[
  0
  ]
  tenant_id = octopusdeploy_tenant.generic[count.index].id
  value     = "http://localhost"
  depends_on = [
    octopusdeploy_tenant_project.generic_project_environment,
    octopusdeploy_tenant_project.generic_project_cac_environment,
    octopusdeploy_tenant_project.generic_project_web_app_cac_environment,
    octopusdeploy_tenant_project.generic_project_init_space_environment,
    octopusdeploy_tenant_project.generic_project_init_space_k8s_environment,
    octopusdeploy_tenant_project.generic_project_create_client_space_environment,
    octopusdeploy_tenant_project.generic_project_k8s_microservice_template_environment,
  ]
}

resource "octopusdeploy_tenant_common_variable" "generic_docker_username" {
  count                   = var.generic_tenant_count
  library_variable_set_id = data.octopusdeploy_library_variable_sets.docker.library_variable_sets[0].id
  template_id             = tolist([
    for tmp in data.octopusdeploy_library_variable_sets.docker.library_variable_sets[0].template :
    tmp.id if tmp.name == "Tenant.Docker.Username"
  ])[
  0
  ]
  tenant_id = octopusdeploy_tenant.generic[count.index].id
  value     = "blah"
  depends_on = [
    octopusdeploy_tenant_project.generic_project_environment,
    octopusdeploy_tenant_project.generic_project_cac_environment,
    octopusdeploy_tenant_project.generic_project_web_app_cac_environment,
    octopusdeploy_tenant_project.generic_project_init_space_environment,
    octopusdeploy_tenant_project.generic_project_init_space_k8s_environment,
    octopusdeploy_tenant_project.generic_project_create_client_space_environment,
    octopusdeploy_tenant_project.generic_project_k8s_microservice_template_environment,
  ]
}

resource "octopusdeploy_tenant_common_variable" "generic_docker_password" {
  count                   = var.generic_tenant_count
  library_variable_set_id = data.octopusdeploy_library_variable_sets.docker.library_variable_sets[0].id
  template_id             = tolist([
    for tmp in data.octopusdeploy_library_variable_sets.docker.library_variable_sets[0].template :
    tmp.id if tmp.name == "Tenant.Docker.Password"
  ])[
  0
  ]
  tenant_id = octopusdeploy_tenant.generic[count.index].id
  value     = "blah"
  depends_on = [
    octopusdeploy_tenant_project.generic_project_environment,
    octopusdeploy_tenant_project.generic_project_cac_environment,
    octopusdeploy_tenant_project.generic_project_web_app_cac_environment,
    octopusdeploy_tenant_project.generic_project_init_space_environment,
    octopusdeploy_tenant_project.generic_project_init_space_k8s_environment,
    octopusdeploy_tenant_project.generic_project_create_client_space_environment,
    octopusdeploy_tenant_project.generic_project_k8s_microservice_template_environment,
  ]
}

resource "octopusdeploy_tenant_common_variable" "generic_slack_bot_token" {
  count                   = var.generic_tenant_count
  library_variable_set_id = data.octopusdeploy_library_variable_sets.slack.library_variable_sets[0].id
  template_id             = tolist([
    for tmp in data.octopusdeploy_library_variable_sets.slack.library_variable_sets[0].template :
    tmp.id if tmp.name == "Slack.Bot.Token"
  ])[
  0
  ]
  tenant_id = octopusdeploy_tenant.generic[count.index].id
  value     = "blah"
  depends_on = [
    octopusdeploy_tenant_project.generic_project_environment,
    octopusdeploy_tenant_project.generic_project_cac_environment,
    octopusdeploy_tenant_project.generic_project_web_app_cac_environment,
    octopusdeploy_tenant_project.generic_project_init_space_environment,
    octopusdeploy_tenant_project.generic_project_init_space_k8s_environment,
    octopusdeploy_tenant_project.generic_project_create_client_space_environment,
    octopusdeploy_tenant_project.generic_project_k8s_microservice_template_environment,
  ]
}

resource "octopusdeploy_tenant_common_variable" "generic_slack_support_users" {
  count                   = var.generic_tenant_count
  library_variable_set_id = data.octopusdeploy_library_variable_sets.slack.library_variable_sets[0].id
  template_id             = tolist([
    for tmp in data.octopusdeploy_library_variable_sets.slack.library_variable_sets[0].template :
    tmp.id if tmp.name == "Slack.Support.Users"
  ])[
  0
  ]
  tenant_id = octopusdeploy_tenant.generic[count.index].id
  value     = "blah"
  depends_on = [
    octopusdeploy_tenant_project.generic_project_environment,
    octopusdeploy_tenant_project.generic_project_cac_environment,
    octopusdeploy_tenant_project.generic_project_web_app_cac_environment,
    octopusdeploy_tenant_project.generic_project_init_space_environment,
    octopusdeploy_tenant_project.generic_project_init_space_k8s_environment,
    octopusdeploy_tenant_project.generic_project_create_client_space_environment,
    octopusdeploy_tenant_project.generic_project_k8s_microservice_template_environment,
  ]
}