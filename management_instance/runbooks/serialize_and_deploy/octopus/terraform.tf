terraform {
  required_providers {
    octopusdeploy = { source = "OctopusDeployLabs/octopusdeploy", version = "0.22.0" }
  }
}

locals {
  project_name_sanitized = "#{if Exported.Project.Name}#{Exported.Project.Name | ToLower | Replace \"[^a-zA-Z0-9]\" \"_\"}#{/if}#{unless Exported.Project.Name}#{Octopus.Project.Name | ToLower | Replace \"[^a-zA-Z0-9]\" \"_\"}#{/unless}"
  backend                = "#{Octopus.Project.Name | ToLower | Replace \"[^a-zA-Z0-9]\" \"_\"}"
  workspace              = "#{Octopus.Deployment.Tenant.Name | ToLower | Replace \"[^a-zA-Z0-9]\" \"_\"}_${local.project_name_sanitized}"
  project_name_variable  = "project_#{Octopus.Project.Name | ToLower | Replace \"[^a-zA-Z0-9]\" \"_\"}_name"
}

variable "project_name" {
  type        = string
  nullable    = false
  sensitive   = false
  description = "The name of the project to attach the runbooks to."
}

data "octopusdeploy_worker_pools" "workerpool_default" {
  name = "Default Worker Pool"
  ids  = null
  skip = 0
  take = 1
}

data "octopusdeploy_feeds" "feed_octopus_server__built_in_" {
  feed_type    = "BuiltIn"
  ids          = null
  partial_name = ""
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

data "octopusdeploy_projects" "project" {
  cloned_from_project_id = null
  ids                    = []
  is_clone               = false
  name                   = var.project_name
  partial_name           = null
  skip                   = 0
  take                   = 1
}

data "octopusdeploy_environments" "sync" {
  ids          = []
  partial_name = "Sync"
  skip         = 0
  take         = 1
}

variable "compose_project" {
  type        = string
  nullable    = false
  sensitive   = false
  description = "The name of the project containing the runbook required to compose in global resource"
  default     = ""
}

variable "compose_runbook" {
  type        = string
  nullable    = false
  sensitive   = false
  description = "The name of the runbook required to compose in global resource"
  default     = ""
}

variable "create_space_project" {
  type        = string
  nullable    = false
  sensitive   = false
  description = "The name of the project containing the runbook required to create the space"
  default     = ""
}

variable "create_space_runbook" {
  type        = string
  nullable    = false
  sensitive   = false
  description = "The name of the runbook required to create the space"
  default     = ""
}

resource "octopusdeploy_runbook" "runbook_backend_service_deploy_project" {
  name                        = "__ 2. Deploy Project"
  project_id                  = data.octopusdeploy_projects.project.projects[0].id
  environment_scope           = "Specified"
  environments                = [data.octopusdeploy_environments.sync.environments[0].id]
  force_package_download      = false
  default_guided_failure_mode = "EnvironmentDefault"
  description                 = "This project deploys the package created by the Serialize Project runbook to a space."
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
  runbook_id = octopusdeploy_runbook.runbook_backend_service_serialize_project.id

  step {
    condition           = "Success"
    name                = "Serialize Project"
    package_requirement = "LetOctopusDecide"
    start_trigger       = "StartAfterPrevious"

    action {
      action_type                        = "Octopus.Script"
      name                               = "Serialize Project"
      condition                          = "Success"
      run_on_server                      = true
      is_disabled                        = false
      can_be_used_for_project_versioning = true
      is_required                        = false
      worker_pool_id                     = data.octopusdeploy_worker_pools.workerpool_default.worker_pools[0].id
      properties                         = {
        "Octopus.Action.Script.Syntax"       = "Python"
        "Octopus.Action.Script.ScriptBody"   = file("../../shared_scripts/serialize_project.py")
        "Octopus.Action.Script.ScriptSource" = "Inline"
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

resource "octopusdeploy_runbook" "runbook_backend_service_serialize_project" {
  name                        = "__ 1. Serialize Project"
  project_id                  = "${data.octopusdeploy_projects.project.projects[0].id}"
  environment_scope           = "Specified"
  environments                = [data.octopusdeploy_environments.sync.environments[0].id]
  force_package_download      = false
  default_guided_failure_mode = "EnvironmentDefault"
  description                 = "This runbook serializes a project to HCL, packages it up, and pushes the package to Octopus."
  multi_tenancy_mode          = "Untenanted"

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

resource "octopusdeploy_runbook_process" "runbook_process_backend_service_deploy_project" {
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
   [[ counter -eq $max_retry ]] && echo "Failed!" && exit 1
   [[ counter -ne 0 ]] && sleep 5
   echo "Trying again. Try #$counter"
   ((counter++))
done
echo "##octopus[stdout-default]"
DATABASE=$(dig +short terraformdb)

# Creating databases can lead to race conditions in Postrges. We use flock to try and reduce the chances, and then
# a retry loop to ensure the command succeeds successfully.
max_retry=2
counter=0
until /usr/bin/flock /tmp/${local.backend}.lock docker run --rm -e "PGPASSWORD=terraform" --entrypoint '/bin/bash' postgres -c "echo \"SELECT 'CREATE DATABASE ${local.backend}' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '${local.backend}')\gexec\" | /usr/bin/psql -h $${DATABASE} -v ON_ERROR_STOP=1 --username 'terraform'" 2>&1
do
   [[ counter -eq $max_retry ]] && echo "Failed!" && exit 1
   [[ counter -ne 0 ]] && sleep 5
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
    name                = "Trigger Create Space"
    package_requirement = "LetOctopusDecide"
    start_trigger       = "StartAfterPrevious"

    action {
      action_type                        = "Octopus.Script"
      name                               = "Trigger Create Space"
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
if [[ -z "${var.create_space_project}" ]]
then
  echo "No compose project to run"
  exit 0
fi

octo \
  run-runbook \
  --server 'http://octopus:8080' \
  --apiKey 'API-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA' \
  --space 'Default' \
  --project '${var.create_space_project}' \
  --runbook '${var.create_space_runbook}' \
  --environment 'Sync' \
  --tenant '#{Octopus.Deployment.Tenant.Name}' \
  --runTimeout '01:00:00' \
  --waitForRun
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
    name                = "Compose Specialized Resource"
    package_requirement = "LetOctopusDecide"
    start_trigger       = "StartAfterPrevious"

    action {
      action_type                        = "Octopus.Script"
      name                               = "Compose Specialized Resource"
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
if [[ -z "${var.compose_project}" ]]
then
  echo "No compose project to run"
  exit 0
fi

octo \
  run-runbook \
  --server 'http://octopus:8080' \
  --apiKey 'API-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA' \
  --space 'Default' \
  --project '${var.compose_project}' \
  --runbook '${var.compose_runbook}' \
  --environment 'Sync' \
  --tenant '#{Octopus.Deployment.Tenant.Name}' \
  --waitForRun \
  --runTimeout '01:00:00'
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
    name                = "Lookup New Space"
    package_requirement = "LetOctopusDecide"
    start_trigger       = "StartAfterPrevious"

    action {
      action_type                        = "Octopus.Script"
      name                               = "Lookup New Space"
      condition                          = "Success"
      run_on_server                      = true
      is_disabled                        = false
      can_be_used_for_project_versioning = true
      is_required                        = false
      worker_pool_id                     = data.octopusdeploy_worker_pools.workerpool_default.worker_pools[0].id
      properties                         = {
        "Octopus.Action.Script.Syntax"       = "Python"
        "Octopus.Action.Script.ScriptBody"   = file("../../shared_scripts/space_lookup.py")
        "Octopus.Action.Script.ScriptSource" = "Inline"
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
    name                = "Deploy the Project"
    package_requirement = "LetOctopusDecide"
    start_trigger       = "StartAfterPrevious"

    action {
      action_type                        = "Octopus.TerraformApply"
      name                               = "Deploy the Project"
      condition                          = "Success"
      run_on_server                      = true
      is_disabled                        = false
      can_be_used_for_project_versioning = true
      is_required                        = false
      worker_pool_id                     = data.octopusdeploy_worker_pools.workerpool_default.worker_pools[0].id
      properties                         = {
        "Octopus.Action.AutoRetry.MaximumCount"                 = "3"
        "Octopus.Action.Terraform.GoogleCloudAccount"           = "False"
        "Octopus.Action.Terraform.TemplateDirectory"            = "space_population"
        "Octopus.Action.Terraform.AdditionalActionParams"       = "-var=\"octopus_server=#{ManagedTenant.Octopus.Url}\" -var=\"octopus_space_id=#{Octopus.Action[Lookup New Space].Output.SpaceID}\" -var=\"octopus_apikey=#{ManagedTenant.Octopus.ApiKey}\" -var=\"${local.project_name_variable}=#{if Exported.Project.Name}#{Exported.Project.Name}#{/if}#{unless Exported.Project.Name}#{Octopus.Project.Name}#{/unless}\""
        "Octopus.Action.Aws.AssumeRole"                         = "False"
        "Octopus.Action.Aws.Region"                             = ""
        "Octopus.Action.Terraform.AllowPluginDownloads"         = "True"
        "Octopus.Action.Terraform.AzureAccount"                 = "False"
        "Octopus.Action.AwsAccount.Variable"                    = ""
        "Octopus.Action.GoogleCloud.UseVMServiceAccount"        = "True"
        "Octopus.Action.Script.ScriptSource"                    = "Package"
        "Octopus.Action.Terraform.RunAutomaticFileSubstitution" = "False"
        "Octopus.Action.Terraform.AdditionalInitParams"         = "-backend-config=\"conn_str=postgres://terraform:terraform@terraformdb:5432/${local.backend}?sslmode=disable\""
        "Octopus.Action.GoogleCloud.ImpersonateServiceAccount"  = "False"
        "Octopus.Action.Terraform.PlanJsonOutput"               = "False"
        "Octopus.Action.Terraform.ManagedAccount"               = ""
        "OctopusUseBundledTooling"                              = "False"
        "Octopus.Action.AwsAccount.UseInstanceRole"             = "False"
        "Octopus.Action.Terraform.FileSubstitution"             = "**/project_variable_sensitive*.tf"
        "Octopus.Action.Package.DownloadOnTentacle"             = "False"
        "Octopus.Action.Terraform.Workspace"                    = local.workspace
      }

      environments          = []
      excluded_environments = []
      channels              = []
      tenant_tags           = []

      primary_package {
        package_id           = replace(var.project_name, "/[^A-Za-z0-9]/", "_")
        acquisition_location = "Server"
        feed_id              = data.octopusdeploy_feeds.feed_octopus_server__built_in_.feeds[0].id
        properties           = { SelectionMode = "immediate" }
      }

      features = []
    }

    properties   = {}
    target_roles = []
  }
}


resource "octopusdeploy_runbook" "runbook_backend_service_deploy_all_projects" {
  name                        = "__ 4. Update Previous Deployments"
  project_id                  = data.octopusdeploy_projects.project.projects[0].id
  environment_scope           = "Specified"
  environments                = [data.octopusdeploy_environments.sync.environments[0].id]
  force_package_download      = false
  default_guided_failure_mode = "EnvironmentDefault"
  description                 = "This project deploys the package created by the Serialize Project runbook to all downstream projects in a space."
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

resource "octopusdeploy_runbook_process" "runbook_process_backend_service_deploy_all_projects" {
  runbook_id = octopusdeploy_runbook.runbook_backend_service_deploy_all_projects.id

  step {
    condition           = "Success"
    name                = "Reapply Projects"
    package_requirement = "LetOctopusDecide"
    start_trigger       = "StartAfterPrevious"

    action {
      action_type                        = "Octopus.Script"
      name                               = "Reapply Projects"
      condition                          = "Success"
      run_on_server                      = true
      is_disabled                        = false
      can_be_used_for_project_versioning = true
      is_required                        = false
      worker_pool_id                     = data.octopusdeploy_worker_pools.workerpool_default.worker_pools[0].id
      properties                         = {
        "Octopus.Action.Script.Syntax"       = "Python"
        "Octopus.Action.Script.ScriptBody"   = file("../../shared_scripts/apply_all_downstream_projects.py")
        "Octopus.Action.Script.ScriptSource" = "Inline"
      }
      environments          = []
      excluded_environments = []
      channels              = []
      tenant_tags           = []
      features              = []

      package {
        name                      = replace(var.project_name, "/[^A-Za-z0-9]/", "_")
        package_id                = replace(var.project_name, "/[^A-Za-z0-9]/", "_")
        acquisition_location      = "Server"
        feed_id                   = data.octopusdeploy_feeds.feed_octopus_server__built_in_.feeds[0].id
        properties                = { SelectionMode = "immediate" }
        extract_during_deployment = true
      }
    }

    properties   = {}
    target_roles = []
  }
}