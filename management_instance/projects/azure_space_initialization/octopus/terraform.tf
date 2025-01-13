terraform {
  required_providers {
    octopusdeploy = { source = "OctopusDeployLabs/octopusdeploy", version = "0.22.0" }
  }
}

data "octopusdeploy_library_variable_sets" "this_instance" {
  partial_name = "This Instance"
  skip         = 0
  take         = 1
}

data "octopusdeploy_lifecycles" "lifecycle_simple" {
  ids          = null
  partial_name = "Simple"
  skip         = 0
  take         = 1
}

data "octopusdeploy_feeds" "feed_docker" {
  feed_type    = "Docker"
  ids          = null
  partial_name = "Docker"
  skip         = 0
  take         = 1
}

data "octopusdeploy_feeds" "feed_octopus_server__built_in_" {
  feed_type    = "BuiltIn"
  ids          = null
  partial_name = ""
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

data "octopusdeploy_project_groups" "project_group_azure" {
  ids          = null
  partial_name = "Azure"
  skip         = 0
  take         = 1
}

data "octopusdeploy_worker_pools" "workerpool_default" {
  name = "Default Worker Pool"
  ids  = null
  skip = 0
  take = 1
}

data "octopusdeploy_environments" "sync" {
  ids          = []
  partial_name = "Sync"
  skip         = 0
  take         = 1
}

resource "octopusdeploy_project" "project_compose_azure_resources" {
  # We want this project to be sorted higher than the template projects, so start with an underscore
  name                                 = "__ Compose Azure Resources"
  description                          = "This project is used to populate a space with any common Azure resources."
  auto_create_release                  = false
  default_guided_failure_mode          = "EnvironmentDefault"
  default_to_skip_if_already_installed = false
  discrete_channel_release             = false
  is_disabled                          = false
  is_version_controlled                = false
  lifecycle_id                         = data.octopusdeploy_lifecycles.lifecycle_simple.lifecycles[0].id
  project_group_id                     = data.octopusdeploy_project_groups.project_group_azure.project_groups[0].id
  included_library_variable_sets       = [
    data.octopusdeploy_library_variable_sets.octopus_server.library_variable_sets[0].id,
    data.octopusdeploy_library_variable_sets.azure.library_variable_sets[0].id,
    data.octopusdeploy_library_variable_sets.this_instance.library_variable_sets[0].id,
  ]
  tenanted_deployment_participation = "Untenanted"

  connectivity_policy {
    allow_deployments_to_no_targets = true
    exclude_unhealthy_targets       = false
    skip_machine_behavior           = "None"
  }
}

resource "octopusdeploy_runbook" "runbook_backend_service_deploy_project" {
  name                        = "Initialize Space"
  project_id                  = octopusdeploy_project.project_compose_azure_resources.id
  environment_scope           = "Specified"
  environments                = [data.octopusdeploy_environments.sync.environments[0].id]
  force_package_download      = false
  default_guided_failure_mode = "EnvironmentDefault"
  description                 = "This runbook initializes a space with common Azure resources sourced from a tenant."
  multi_tenancy_mode          = "Tenanted"

  retention_policy {
    quantity_to_keep    = 100
    should_keep_forever = false
  }

  connectivity_policy {
    allow_deployments_to_no_targets = true
    exclude_unhealthy_targets       = false
    skip_machine_behavior           = "None"
  }
}

resource "octopusdeploy_runbook_process" "runbook_process_backend_service_serialize_project" {
  runbook_id = octopusdeploy_runbook.runbook_backend_service_deploy_project.id

  step {
    condition           = "Success"
    name                = "Create the State Table"
    package_requirement = "LetOctopusDecide"
    start_trigger       = "StartAfterPrevious"

    action {
      action_type                        = "Octopus.Script"
      name                               = "Create the State Table"
      condition                          = "Success"
      run_on_server                      = true
      is_disabled                        = false
      can_be_used_for_project_versioning = false
      is_required                        = false
      worker_pool_id                     = data.octopusdeploy_worker_pools.workerpool_default.worker_pools[0].id
      properties                         = {
        "Octopus.Action.Script.ScriptSource" = "Inline"
        "Octopus.Action.Script.Syntax"       = "Bash"
        "Octopus.Action.Script.ScriptBody"   = <<EOT
echo "Verify Docker is Running"
echo "##octopus[stdout-verbose]"
docker info
if ! docker info
then
  echo "Docker is not running. Check that Docker is installed and the daemon is running."
  exit 1
fi
echo "##octopus[stdout-default]"

echo "Pulling postgres image"
echo "##octopus[stdout-verbose]"
max_retry=12
counter=0
until /usr/bin/flock /tmp/dockerpull.lock docker pull postgres 2>&1
do
   sleep 5
   [[ counter -eq $max_retry ]] && echo "Failed!" && exit 1
   echo "Trying again. Try #$counter"
   ((counter++))
done
echo "##octopus[stdout-default]"
DATABASE=$(dig +short terraformdb)

# Creating databases can lead to race conditions in Postrges. We use flock to try and reduce the chances, and then
# a retry loop to ensure the command succeeds successfully.
max_retry=2
counter=0
until /usr/bin/flock /tmp/project_initialize_azure_space.lock docker run --rm -e "PGPASSWORD=terraform" --entrypoint '/bin/bash' postgres -c "echo \"SELECT 'CREATE DATABASE project_initialize_azure_space' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'project_initialize_azure_space')\gexec\" | /usr/bin/psql -h $${DATABASE} -v ON_ERROR_STOP=1 --username 'terraform'" 2>&1
do
   sleep 5
   [[ counter -eq $max_retry ]] && echo "Failed!" && exit 1
   echo "Trying again. Try #$counter"
   ((counter++))
done

exit 0
EOT
      }
      environments          = []
      excluded_environments = []
      channels              = []
      tenant_tags           = []
      features              = []
    }

    properties   = {}
    target_roles = []
  }

  step {
    condition           = "Success"
    name                = "Configure the Azure Account"
    package_requirement = "LetOctopusDecide"
    start_trigger       = "StartAfterPrevious"

    action {
      action_type                        = "Octopus.TerraformApply"
      name                               = "Configure the Azure Account"
      condition                          = "Success"
      run_on_server                      = true
      is_disabled                        = false
      can_be_used_for_project_versioning = true
      is_required                        = false
      worker_pool_id                     = data.octopusdeploy_worker_pools.workerpool_default.worker_pools[0].id
      properties                         = {
        "Octopus.Action.AutoRetry.MaximumCount"       = "3"
        "Octopus.Action.Terraform.Template"           = file("../terraform_scripts/azure.tf")
        "Octopus.Action.Terraform.TemplateParameters" = jsonencode({
          "azure_application_id"  = "#{Tenant.Azure.ApplicationId}"
          "azure_subscription_id" = "#{Tenant.Azure.SubscriptionId}"
          "azure_password"        = "#{Tenant.Azure.Password}"
          "azure_tenant_id"       = "#{Tenant.Azure.TenantId}"
          "octopus_apikey"        = "#{ManagedTenant.Octopus.ApiKey}"
          "octopus_url"           = "#{ManagedTenant.Octopus.Url}"
          "octopus_space_id"      = "#{ManagedTenant.Octopus.SpaceId}"
        })
        "Octopus.Action.Aws.AssumeRole"                         = "False"
        "Octopus.Action.Terraform.PlanJsonOutput"               = "False"
        "Octopus.Action.AwsAccount.UseInstanceRole"             = "False"
        "Octopus.Action.AwsAccount.Variable"                    = ""
        "Octopus.Action.Terraform.RunAutomaticFileSubstitution" = "True"
        "Octopus.Action.GoogleCloud.ImpersonateServiceAccount"  = "False"
        "Octopus.Action.Aws.Region"                             = ""
        "Octopus.Action.GoogleCloud.UseVMServiceAccount"        = "True"
        "OctopusUseBundledTooling"                              = "False"
        "Octopus.Action.Terraform.ManagedAccount"               = "None"
        "Octopus.Action.Script.ScriptSource"                    = "Inline"
        "Octopus.Action.Terraform.GoogleCloudAccount"           = "False"
        "Octopus.Action.Terraform.AzureAccount"                 = "False"
        "Octopus.Action.Terraform.AllowPluginDownloads"         = "True"
        "Octopus.Action.Terraform.Workspace"                    = "#{Octopus.Deployment.Tenant.Name}"
      }

      environments          = []
      excluded_environments = []
      channels              = []
      tenant_tags           = []
      features              = []
    }

    properties   = {}
    target_roles = []
  }

  step {
    condition           = "Success"
    name                = "Deploy Azure Project Group"
    package_requirement = "LetOctopusDecide"
    start_trigger       = "StartWithPrevious"

    action {
      action_type                        = "Octopus.TerraformApply"
      name                               = "Deploy Azure Project Group"
      condition                          = "Success"
      run_on_server                      = true
      is_disabled                        = false
      can_be_used_for_project_versioning = false
      is_required                        = false
      worker_pool_id                     = ""
      properties                         = {
        "Octopus.Action.AutoRetry.MaximumCount"          = "3"
        "Octopus.Action.Script.ScriptSource"             = "Inline"
        "Octopus.Action.Terraform.Template"              = <<EOF
terraform {
  backend "pg" {
    conn_str = "postgres://terraform:terraform@terraformdb:5432/project_group_azure?sslmode=disable"
  }
}

variable "space_id" {
  type = string

  validation {
    condition     = length(var.space_id) > 7 && substr(var.space_id, 0, 7) == "Spaces-"
    error_message = "The space_id value must be a valid Space id, starting with \"Spaces-\"."
  }
}

provider "octopusdeploy" {
  address  = "http://octopus:8080"
  api_key  = "API-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
  space_id = var.space_id
}

${file("../../../../shared/project_group/azure/octopus/provider.tf")}
${file("../../../../shared/project_group/azure/octopus/terraform.tf")}
EOF
        "Octopus.Action.Terraform.AllowPluginDownloads"  = "True"
        "Octopus.Action.Terraform.GoogleCloudAccount"    = "False"
        "Octopus.Action.GoogleCloud.UseVMServiceAccount" = "True"
        "Octopus.Action.Terraform.TemplateParameters"    = jsonencode({
          "space_id" = "#{ManagedTenant.Octopus.SpaceId}"
        })
        "Octopus.Action.Terraform.Workspace"                    = "#{Octopus.Deployment.Tenant.Name}"
        "Octopus.Action.Terraform.PlanJsonOutput"               = "False"
        "Octopus.Action.Terraform.AzureAccount"                 = "False"
        "Octopus.Action.Terraform.ManagedAccount"               = "None"
        "Octopus.Action.GoogleCloud.ImpersonateServiceAccount"  = "False"
        "Octopus.Action.Terraform.AdditionalActionParams"       = ""
        "Octopus.Action.Terraform.RunAutomaticFileSubstitution" = "True"
      }
      environments          = []
      excluded_environments = []
      channels              = []
      tenant_tags           = []
      features              = []
    }

    properties   = {}
    target_roles = []
  }
}

