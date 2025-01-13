terraform {
  required_providers {
    octopusdeploy = { source = "OctopusDeployLabs/octopusdeploy", version = "0.22.0" }
  }
}

data "octopusdeploy_library_variable_sets" "octopus_server" {
  ids          = null
  partial_name = "Octopus Server"
  skip         = 0
  take         = 1
}

data "octopusdeploy_library_variable_sets" "this_instance" {
  ids          = null
  partial_name = "This Instance"
  skip         = 0
  take         = 1
}

data "octopusdeploy_library_variable_sets" "docker" {
  partial_name = "Docker"
  skip         = 0
  take         = 1
}

data "octopusdeploy_library_variable_sets" "slack" {
  partial_name = "Client Slack"
  skip         = 0
  take         = 1
}

data "octopusdeploy_environments" "environment_sync" {
  ids          = null
  partial_name = "Sync"
  skip         = 0
  take         = 1
}

variable "runbook____create_client_space_create_client_space_name" {
  type        = string
  nullable    = false
  sensitive   = false
  description = "The name of the project exported from Create Client Space"
  default     = "Create Client Space"
}

resource "octopusdeploy_runbook" "runbook____create_client_space_create_client_space" {
  name                        = var.runbook____create_client_space_create_client_space_name
  project_id                  = octopusdeploy_project.project____create_client_space.id
  environment_scope           = "Specified"
  environments                = [data.octopusdeploy_environments.environment_sync.environments[0].id]
  force_package_download      = false
  default_guided_failure_mode = "EnvironmentDefault"
  description                 = ""
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

data "octopusdeploy_lifecycles" "lifecycle_simple" {
  ids          = null
  partial_name = "Simple"
  skip         = 0
  take         = 1
}

variable "project____create_client_space_name" {
  type        = string
  nullable    = false
  sensitive   = false
  description = "The name of the project exported from __ Create Client Space"
  default     = "__ Create Client Space"
}

resource "octopusdeploy_project" "project____create_client_space" {
  name                                 = var.project____create_client_space_name
  auto_create_release                  = false
  default_guided_failure_mode          = "EnvironmentDefault"
  default_to_skip_if_already_installed = false
  description                          = ""
  discrete_channel_release             = false
  is_disabled                          = false
  is_version_controlled                = false
  lifecycle_id                         = data.octopusdeploy_lifecycles.lifecycle_simple.lifecycles[0].id
  project_group_id                     = data.octopusdeploy_project_groups.project_group_client_space.project_groups[0].id
  included_library_variable_sets       = [
    data.octopusdeploy_library_variable_sets.octopus_server.library_variable_sets[0].id,
    data.octopusdeploy_library_variable_sets.this_instance.library_variable_sets[0].id,
    data.octopusdeploy_library_variable_sets.docker.library_variable_sets[0].id,
    data.octopusdeploy_library_variable_sets.slack.library_variable_sets[0].id,
  ]
  tenanted_deployment_participation = "Untenanted"

  connectivity_policy {
    allow_deployments_to_no_targets = true
    exclude_unhealthy_targets       = false
    skip_machine_behavior           = "None"
  }

  versioning_strategy {
    template = "#{Octopus.Version.LastMajor}.#{Octopus.Version.LastMinor}.#{Octopus.Version.NextPatch}"
  }
}

resource "octopusdeploy_runbook_process" "runbook_process____create_client_space_create_client_space" {
  runbook_id = octopusdeploy_runbook.runbook____create_client_space_create_client_space.id

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
      worker_pool_id                     = ""
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
until /usr/bin/flock /tmp/spaces.lock docker run --rm -e "PGPASSWORD=terraform" --entrypoint '/bin/bash' postgres -c "echo \"SELECT 'CREATE DATABASE spaces' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'spaces')\gexec\" | /usr/bin/psql -h $${DATABASE} -v ON_ERROR_STOP=1 --username 'terraform'" 2>&1
do
   sleep 5
   [[ counter -eq $max_retry ]] && echo "Failed!" && exit 1
   echo "Trying again. Try #$counter"
   ((counter++))
done

counter=0
until /usr/bin/flock /tmp/tenant_variables.lock docker run --rm -e "PGPASSWORD=terraform" --entrypoint '/bin/bash' postgres -c "echo \"SELECT 'CREATE DATABASE tenant_variables' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'tenant_variables')\gexec\" | /usr/bin/psql -h $${DATABASE} -v ON_ERROR_STOP=1 --username 'terraform'" 2>&1
do
   sleep 5
   [[ counter -eq $max_retry ]] && echo "Failed!" && exit 1
   echo "Trying again. Try #$counter"
   ((counter++))
done

counter=0
until /usr/bin/flock /tmp/var_lib_slack.lock docker run --rm -e "PGPASSWORD=terraform" --entrypoint '/bin/bash' postgres -c "echo \"SELECT 'CREATE DATABASE var_lib_slack' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'var_lib_slack')\gexec\" | /usr/bin/psql -h $${DATABASE} -v ON_ERROR_STOP=1 --username 'terraform'" 2>&1
do
   sleep 5
   [[ counter -eq $max_retry ]] && echo "Failed!" && exit 1
   echo "Trying again. Try #$counter"
   ((counter++))
done

counter=0
until /usr/bin/flock /tmp/scoped_user_role_deployer_variable_editor.lock docker run --rm -e "PGPASSWORD=terraform" --entrypoint '/bin/bash' postgres -c "echo \"SELECT 'CREATE DATABASE scoped_user_role_deployer_variable_editor' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'scoped_user_role_deployer_variable_editor')\gexec\" | /usr/bin/psql -h $${DATABASE} -v ON_ERROR_STOP=1 --username 'terraform'" 2>&1
do
   sleep 5
   [[ counter -eq $max_retry ]] && echo "Failed!" && exit 1
   echo "Trying again. Try #$counter"
   ((counter++))
done

counter=0
until /usr/bin/flock /tmp/scoped_user_role_deployer.lock docker run --rm -e "PGPASSWORD=terraform" --entrypoint '/bin/bash' postgres -c "echo \"SELECT 'CREATE DATABASE scoped_user_role_deployer' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'scoped_user_role_deployer')\gexec\" | /usr/bin/psql -h $${DATABASE} -v ON_ERROR_STOP=1 --username 'terraform'" 2>&1
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
    name                = "Create Client Space"
    package_requirement = "LetOctopusDecide"
    start_trigger       = "StartAfterPrevious"

    action {
      action_type                        = "Octopus.TerraformApply"
      name                               = "Create Client Space"
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
    conn_str = "postgres://terraform:terraform@terraformdb:5432/spaces?sslmode=disable"
  }
}

variable "octopus_server" {
  type = string
}

variable "octopus_apikey" {
  type = string
}

provider "octopusdeploy" {
  address  = var.octopus_server
  api_key  = var.octopus_apikey
  space_id = "Spaces-1"
}

output "space_id" {
  value = octopusdeploy_space.space.id
}

${file("../../../../shared/spaces/octopus/provider.tf")}
${file("../../../../shared/spaces/octopus/terraform.tf")}
EOF
        "Octopus.Action.Terraform.AllowPluginDownloads"  = "True"
        "Octopus.Action.Terraform.GoogleCloudAccount"    = "False"
        "Octopus.Action.GoogleCloud.UseVMServiceAccount" = "True"
        "Octopus.Action.Terraform.TemplateParameters"    = jsonencode({
          "space_name"     = "#{Octopus.Deployment.Tenant.Name}"
          "octopus_server" = "#{ManagedTenant.Octopus.Url}"
          "octopus_apikey" = "#{ManagedTenant.Octopus.ApiKey}"
        })
        "Octopus.Action.Terraform.Workspace"                    = "#{Octopus.Deployment.Tenant.Name | Replace \"[^A-Za-z0-9]\" \"_\"}"
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

  step {
    condition           = "Success"
    name                = "Configure Project Editor Team"
    package_requirement = "LetOctopusDecide"
    start_trigger       = "StartAfterPrevious"

    action {
      action_type                        = "Octopus.TerraformApply"
      name                               = "Configure Project Editor Team"
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
    conn_str = "postgres://terraform:terraform@terraformdb:5432/scoped_user_role_deployer_variable_editor?sslmode=disable"
  }
}

variable "octopus_server" {
  type = string
}

variable "octopus_apikey" {
  type = string
}

provider "octopusdeploy" {
  address  = var.octopus_server
  api_key  = var.octopus_apikey
  space_id = var.octopus_space_id
}

${file("../../../../shared/scoped_user_role/deployer_variable_editor/octopus/provider.tf")}
${file("../../../../shared/scoped_user_role/deployer_variable_editor/octopus/terraform.tf")}
EOF
        "Octopus.Action.Terraform.AllowPluginDownloads"  = "True"
        "Octopus.Action.Terraform.GoogleCloudAccount"    = "False"
        "Octopus.Action.GoogleCloud.UseVMServiceAccount" = "True"
        "Octopus.Action.Terraform.TemplateParameters"    = jsonencode({
          "octopus_server"   = "#{ManagedTenant.Octopus.Url}"
          "octopus_apikey"   = "#{ManagedTenant.Octopus.ApiKey}"
          "octopus_space_id" = "#{Octopus.Action[Create Client Space].Output.TerraformValueOutputs[space_id]}"
        })
        "Octopus.Action.Terraform.Workspace"                    = "#{Octopus.Deployment.Tenant.Name | Replace \"[^A-Za-z0-9]\" \"_\"}"
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

  step {
    condition           = "Success"
    name                = "Configure Project Deployer Team"
    package_requirement = "LetOctopusDecide"
    start_trigger       = "StartWithPrevious"

    action {
      action_type                        = "Octopus.TerraformApply"
      name                               = "Configure Project Deployer Team"
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
    conn_str = "postgres://terraform:terraform@terraformdb:5432/scoped_user_role_deployer?sslmode=disable"
  }
}

variable "octopus_server" {
  type = string
}

variable "octopus_apikey" {
  type = string
}

provider "octopusdeploy" {
  address  = var.octopus_server
  api_key  = var.octopus_apikey
  space_id = var.octopus_space_id
}

${file("../../../../shared/scoped_user_role/deployer/octopus/provider.tf")}
${file("../../../../shared/scoped_user_role/deployer/octopus/terraform.tf")}
EOF
        "Octopus.Action.Terraform.AllowPluginDownloads"  = "True"
        "Octopus.Action.Terraform.GoogleCloudAccount"    = "False"
        "Octopus.Action.GoogleCloud.UseVMServiceAccount" = "True"
        "Octopus.Action.Terraform.TemplateParameters"    = jsonencode({
          "octopus_server"   = "#{ManagedTenant.Octopus.Url}"
          "octopus_apikey"   = "#{ManagedTenant.Octopus.ApiKey}"
          "octopus_space_id" = "#{Octopus.Action[Create Client Space].Output.TerraformValueOutputs[space_id]}"
        })
        "Octopus.Action.Terraform.Workspace"                    = "#{Octopus.Deployment.Tenant.Name | Replace \"[^A-Za-z0-9]\" \"_\"}"
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

  step {
    condition           = "Success"
    name                = "Link Space ID to Tenant"
    package_requirement = "LetOctopusDecide"
    start_trigger       = "StartWithPrevious"

    action {
      action_type                        = "Octopus.TerraformApply"
      name                               = "Link Space ID to Tenant"
      condition                          = "Success"
      run_on_server                      = true
      is_disabled                        = false
      can_be_used_for_project_versioning = false
      is_required                        = false
      worker_pool_id                     = ""
      properties                         = {
        "Octopus.Action.AutoRetry.MaximumCount"          = "3"
        "Octopus.Action.Script.ScriptSource"             = "Inline"
        "Octopus.Action.Terraform.Template"              = "${file("../embedded_terraform/provider.tf")}\n${file("../embedded_terraform/tenant_space_id_variable.tf")}"
        "Octopus.Action.Terraform.AllowPluginDownloads"  = "True"
        "Octopus.Action.Terraform.GoogleCloudAccount"    = "False"
        "Octopus.Action.GoogleCloud.UseVMServiceAccount" = "True"
        "Octopus.Action.Terraform.TemplateParameters"    = jsonencode({
          "tenant"         = "#{Octopus.Deployment.Tenant.Name}"
          "space_id"       = "#{Octopus.Action[Create Client Space].Output.TerraformValueOutputs[space_id]}"
          "octopus_server" = "#{ThisInstance.Server.Url}"
          "octopus_apikey" = "#{ThisInstance.Api.Key}"
        })
        "Octopus.Action.Terraform.Workspace"                    = "#{Octopus.Deployment.Tenant.Name | Replace \"[^A-Za-z0-9]\" \"_\"}"
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

  step {
    condition           = "Success"
    name                = "Deploy Environments"
    package_requirement = "LetOctopusDecide"
    start_trigger       = "StartWithPrevious"

    action {
      action_type                        = "Octopus.TerraformApply"
      name                               = "Deploy Environments"
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
    conn_str = "postgres://terraform:terraform@terraformdb:5432/environments?sslmode=disable"
  }
}

variable "space_id" {
  type = string

  validation {
    condition     = length(var.space_id) > 7 && substr(var.space_id, 0, 7) == "Spaces-"
    error_message = "The space_id value must be a valid Space id, starting with \"Spaces-\"."
  }
}

variable "octopus_server" {
  type = string
}

variable "octopus_apikey" {
  type = string
}

provider "octopusdeploy" {
  address  = var.octopus_server
  api_key  = var.octopus_apikey
  space_id = var.space_id
}

${file("../../../../shared/environments/dev_test_prod/octopus/provider.tf")}
${file("../../../../shared/environments/dev_test_prod/octopus/terraform.tf")}
EOF
        "Octopus.Action.Terraform.AllowPluginDownloads"  = "True"
        "Octopus.Action.Terraform.GoogleCloudAccount"    = "False"
        "Octopus.Action.GoogleCloud.UseVMServiceAccount" = "True"
        "Octopus.Action.Terraform.TemplateParameters"    = jsonencode({
          "space_id"       = "#{Octopus.Action[Create Client Space].Output.TerraformValueOutputs[space_id]}"
          "octopus_server" = "#{ManagedTenant.Octopus.Url}"
          "octopus_apikey" = "#{ManagedTenant.Octopus.ApiKey}"
        })
        "Octopus.Action.Terraform.Workspace"                    = "#{Octopus.Deployment.Tenant.Name | Replace \"[^A-Za-z0-9]\" \"_\"}"
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

  step {
    condition           = "Success"
    name                = "Deploy Sync Environment"
    package_requirement = "LetOctopusDecide"
    start_trigger       = "StartWithPrevious"

    action {
      action_type                        = "Octopus.TerraformApply"
      name                               = "Deploy Sync Environment"
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
    conn_str = "postgres://terraform:terraform@terraformdb:5432/sync_environment?sslmode=disable"
  }
}

variable "space_id" {
  type = string

  validation {
    condition     = length(var.space_id) > 7 && substr(var.space_id, 0, 7) == "Spaces-"
    error_message = "The space_id value must be a valid Space id, starting with \"Spaces-\"."
  }
}

variable "octopus_server" {
  type = string
}

variable "octopus_apikey" {
  type = string
}

provider "octopusdeploy" {
  address  = var.octopus_server
  api_key  = var.octopus_apikey
  space_id = var.space_id
}


${file("../../../../shared/environments/sync/octopus/provider.tf")}
${file("../../../../shared/environments/sync/octopus/terraform.tf")}
EOF
        "Octopus.Action.Terraform.AllowPluginDownloads"  = "True"
        "Octopus.Action.Terraform.GoogleCloudAccount"    = "False"
        "Octopus.Action.GoogleCloud.UseVMServiceAccount" = "True"
        "Octopus.Action.Terraform.TemplateParameters"    = jsonencode({
          "space_id"       = "#{Octopus.Action[Create Client Space].Output.TerraformValueOutputs[space_id]}"
          "octopus_server" = "#{ManagedTenant.Octopus.Url}"
          "octopus_apikey" = "#{ManagedTenant.Octopus.ApiKey}"
        })
        "Octopus.Action.Terraform.Workspace"                    = "#{Octopus.Deployment.Tenant.Name | Replace \"[^A-Za-z0-9]\" \"_\"}"
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

  step {
    condition           = "Success"
    name                = "Deploy Git Creds"
    package_requirement = "LetOctopusDecide"
    start_trigger       = "StartWithPrevious"

    action {
      action_type                        = "Octopus.TerraformApply"
      name                               = "Deploy Git Creds"
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
    conn_str = "postgres://terraform:terraform@terraformdb:5432/gitcreds?sslmode=disable"
  }
}

variable "space_id" {
  type = string

  validation {
    condition     = length(var.space_id) > 7 && substr(var.space_id, 0, 7) == "Spaces-"
    error_message = "The space_id value must be a valid Space id, starting with \"Spaces-\"."
  }
}

variable "octopus_server" {
  type = string
}

variable "octopus_apikey" {
  type = string
}

provider "octopusdeploy" {
  address  = var.octopus_server
  api_key  = var.octopus_apikey
  space_id = var.space_id
}

${file("../../../../shared/gitcreds/gitea/octopus/provider.tf")}
${file("../../../../shared/gitcreds/gitea/octopus/terraform.tf")}
EOF
        "Octopus.Action.Terraform.AllowPluginDownloads"  = "True"
        "Octopus.Action.Terraform.GoogleCloudAccount"    = "False"
        "Octopus.Action.GoogleCloud.UseVMServiceAccount" = "True"
        "Octopus.Action.Terraform.TemplateParameters"    = jsonencode({
          "space_id"       = "#{Octopus.Action[Create Client Space].Output.TerraformValueOutputs[space_id]}"
          "octopus_server" = "#{ManagedTenant.Octopus.Url}"
          "octopus_apikey" = "#{ManagedTenant.Octopus.ApiKey}"
          "cac_password"   = "Password01!"
          "cac_username"   = "octopus"
        })
        "Octopus.Action.Terraform.Workspace"                    = "#{Octopus.Deployment.Tenant.Name | Replace \"[^A-Za-z0-9]\" \"_\"}"
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

  step {
    condition           = "Success"
    name                = "Deploy Maven Feed"
    package_requirement = "LetOctopusDecide"
    start_trigger       = "StartWithPrevious"

    action {
      action_type                        = "Octopus.TerraformApply"
      name                               = "Deploy Maven Feed"
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
    conn_str = "postgres://terraform:terraform@terraformdb:5432/mavenfeed?sslmode=disable"
  }
}

variable "space_id" {
  type = string

  validation {
    condition     = length(var.space_id) > 7 && substr(var.space_id, 0, 7) == "Spaces-"
    error_message = "The space_id value must be a valid Space id, starting with \"Spaces-\"."
  }
}

variable "octopus_server" {
  type = string
}

variable "octopus_apikey" {
  type = string
}

provider "octopusdeploy" {
  address  = var.octopus_server
  api_key  = var.octopus_apikey
  space_id = var.space_id
}

${file("../../../../shared/feeds/maven/octopus/provider.tf")}
${file("../../../../shared/feeds/maven/octopus/terraform.tf")}
EOF
        "Octopus.Action.Terraform.AllowPluginDownloads"  = "True"
        "Octopus.Action.Terraform.GoogleCloudAccount"    = "False"
        "Octopus.Action.GoogleCloud.UseVMServiceAccount" = "True"
        "Octopus.Action.Terraform.TemplateParameters"    = jsonencode({
          "space_id"       = "#{Octopus.Action[Create Client Space].Output.TerraformValueOutputs[space_id]}"
          "octopus_server" = "#{ManagedTenant.Octopus.Url}"
          "octopus_apikey" = "#{ManagedTenant.Octopus.ApiKey}"
        })
        "Octopus.Action.Terraform.Workspace"                    = "#{Octopus.Deployment.Tenant.Name | Replace \"[^A-Za-z0-9]\" \"_\"}"
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

  step {
    condition           = "Success"
    name                = "Deploy DockerHub Feed"
    package_requirement = "LetOctopusDecide"
    start_trigger       = "StartWithPrevious"

    action {
      action_type                        = "Octopus.TerraformApply"
      name                               = "Deploy DockerHub Feed"
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
    conn_str = "postgres://terraform:terraform@terraformdb:5432/dockerhubfeed?sslmode=disable"
  }
}

variable "space_id" {
  type = string

  validation {
    condition     = length(var.space_id) > 7 && substr(var.space_id, 0, 7) == "Spaces-"
    error_message = "The space_id value must be a valid Space id, starting with \"Spaces-\"."
  }
}

variable "octopus_server" {
  type = string
}

variable "octopus_apikey" {
  type = string
}

provider "octopusdeploy" {
  address  = var.octopus_server
  api_key  = var.octopus_apikey
  space_id = var.space_id
}

${file("../../../../shared/feeds/dockerhub/octopus/provider.tf")}
${file("../../../../shared/feeds/dockerhub/octopus/terraform.tf")}
EOF
        "Octopus.Action.Terraform.AllowPluginDownloads"  = "True"
        "Octopus.Action.Terraform.GoogleCloudAccount"    = "False"
        "Octopus.Action.GoogleCloud.UseVMServiceAccount" = "True"
        "Octopus.Action.Terraform.TemplateParameters"    = jsonencode({
          "space_id"        = "#{Octopus.Action[Create Client Space].Output.TerraformValueOutputs[space_id]}"
          "octopus_server"  = "#{ManagedTenant.Octopus.Url}"
          "octopus_apikey"  = "#{ManagedTenant.Octopus.ApiKey}"
          "docker_password" = "#{Tenant.Docker.Password}"
          "docker_username" = "#{Tenant.Docker.Username}"
        })
        "Octopus.Action.Terraform.Workspace"                    = "#{Octopus.Deployment.Tenant.Name | Replace \"[^A-Za-z0-9]\" \"_\"}"
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

  step {
    condition           = "Success"
    name                = "Deploy Hello World Project Group"
    package_requirement = "LetOctopusDecide"
    start_trigger       = "StartWithPrevious"

    action {
      action_type                        = "Octopus.TerraformApply"
      name                               = "Deploy Hello World Project Group"
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
    conn_str = "postgres://terraform:terraform@terraformdb:5432/project_group_hello_world?sslmode=disable"
  }
}

variable "space_id" {
  type = string

  validation {
    condition     = length(var.space_id) > 7 && substr(var.space_id, 0, 7) == "Spaces-"
    error_message = "The space_id value must be a valid Space id, starting with \"Spaces-\"."
  }
}

variable "octopus_server" {
  type = string
}

variable "octopus_apikey" {
  type = string
}

provider "octopusdeploy" {
  address  = var.octopus_server
  api_key  = var.octopus_apikey
  space_id = var.space_id
}

${file("../../../../shared/project_group/hello_world/octopus/provider.tf")}
${file("../../../../shared/project_group/hello_world/octopus/terraform.tf")}
EOF
        "Octopus.Action.Terraform.AllowPluginDownloads"  = "True"
        "Octopus.Action.Terraform.GoogleCloudAccount"    = "False"
        "Octopus.Action.GoogleCloud.UseVMServiceAccount" = "True"
        "Octopus.Action.Terraform.TemplateParameters"    = jsonencode({
          "space_id"       = "#{Octopus.Action[Create Client Space].Output.TerraformValueOutputs[space_id]}"
          "octopus_server" = "#{ManagedTenant.Octopus.Url}"
          "octopus_apikey" = "#{ManagedTenant.Octopus.ApiKey}"
        })
        "Octopus.Action.Terraform.Workspace"                    = "#{Octopus.Deployment.Tenant.Name | Replace \"[^A-Za-z0-9]\" \"_\"}"
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

  step {
    condition           = "Success"
    name                = "Deploy Slack Variable Library"
    package_requirement = "LetOctopusDecide"
    start_trigger       = "StartWithPrevious"

    action {
      action_type                        = "Octopus.TerraformApply"
      name                               = "Deploy Slack Variable Library"
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
    conn_str = "postgres://terraform:terraform@terraformdb:5432/var_lib_slack?sslmode=disable"
  }
}

variable "space_id" {
  type = string

  validation {
    condition     = length(var.space_id) > 7 && substr(var.space_id, 0, 7) == "Spaces-"
    error_message = "The space_id value must be a valid Space id, starting with \"Spaces-\"."
  }
}

variable "octopus_server" {
  type = string
}

variable "octopus_apikey" {
  type = string
}

provider "octopusdeploy" {
  address  = var.octopus_server
  api_key  = var.octopus_apikey
  space_id = var.space_id
}

${file("../../../../shared/variables/slack/octopus/provider.tf")}
${file("../../../../shared/variables/slack/octopus/terraform.tf")}
EOF
        "Octopus.Action.Terraform.AllowPluginDownloads"  = "True"
        "Octopus.Action.Terraform.GoogleCloudAccount"    = "False"
        "Octopus.Action.GoogleCloud.UseVMServiceAccount" = "True"
        "Octopus.Action.Terraform.TemplateParameters"    = jsonencode({
          "space_id"            = "#{Octopus.Action[Create Client Space].Output.TerraformValueOutputs[space_id]}"
          "octopus_server"      = "#{ManagedTenant.Octopus.Url}"
          "octopus_apikey"      = "#{ManagedTenant.Octopus.ApiKey}"
          "slack_bot_token"     = "#{Slack.Bot.Token}"
          "slack_support_users" = "#{Slack.Support.Users}"
        })
        "Octopus.Action.Terraform.Workspace"                    = "#{Octopus.Deployment.Tenant.Name | Replace \"[^A-Za-z0-9]\" \"_\"}"
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

  step {
    condition           = "Success"
    name                = "Deploy Lifecycles"
    package_requirement = "LetOctopusDecide"
    start_trigger       = "StartAfterPrevious"

    action {
      action_type                        = "Octopus.TerraformApply"
      name                               = "Deploy Lifecycles"
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
    conn_str = "postgres://terraform:terraform@terraformdb:5432/lifecycle_simple_dev_test_prod?sslmode=disable"
  }
}

variable "space_id" {
  type = string

  validation {
    condition     = length(var.space_id) > 7 && substr(var.space_id, 0, 7) == "Spaces-"
    error_message = "The space_id value must be a valid Space id, starting with \"Spaces-\"."
  }
}

variable "octopus_server" {
  type = string
}

variable "octopus_apikey" {
  type = string
}

provider "octopusdeploy" {
  address  = var.octopus_server
  api_key  = var.octopus_apikey
  space_id = var.space_id
}

${file("../../../../shared/lifecycles/simple_dev_test_prod/octopus/provider.tf")}
${file("../../../../shared/lifecycles/simple_dev_test_prod/octopus/terraform.tf")}
EOF
        "Octopus.Action.Terraform.AllowPluginDownloads"  = "True"
        "Octopus.Action.Terraform.GoogleCloudAccount"    = "False"
        "Octopus.Action.GoogleCloud.UseVMServiceAccount" = "True"
        "Octopus.Action.Terraform.TemplateParameters"    = jsonencode({
          "space_id"       = "#{Octopus.Action[Create Client Space].Output.TerraformValueOutputs[space_id]}"
          "octopus_server" = "#{ManagedTenant.Octopus.Url}"
          "octopus_apikey" = "#{ManagedTenant.Octopus.ApiKey}"
        })
        "Octopus.Action.Terraform.Workspace"                    = "#{Octopus.Deployment.Tenant.Name | Replace \"[^A-Za-z0-9]\" \"_\"}"
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

data "octopusdeploy_channels" "channel__default" {
  ids          = null
  partial_name = "Default"
  skip         = 0
  take         = 1
}

variable "project_group_client_space_name" {
  type        = string
  nullable    = false
  sensitive   = false
  description = "The name of the project group to lookup"
  default     = "Client Space"
}
data "octopusdeploy_project_groups" "project_group_client_space" {
  ids          = null
  partial_name = var.project_group_client_space_name
  skip         = 0
  take         = 1
}

