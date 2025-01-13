terraform {
  required_providers {
    octopusdeploy = { source = "OctopusDeployLabs/octopusdeploy", version = "0.22.0" }
  }
}

locals {
  project_name           = "#{if Exported.Project.Name}#{Exported.Project.Name}#{/if}#{unless Exported.Project.Name}#{Octopus.Project.Name}#{/unless}"
  project_name_sanitized = "#{if Exported.Project.Name}#{Exported.Project.Name | ToLower | Replace \"[^a-zA-Z0-9]\" \"_\"}#{/if}#{unless Exported.Project.Name}#{Octopus.Project.Name | ToLower | Replace \"[^a-zA-Z0-9]\" \"_\"}#{/unless}"
  workspace              = "#{Octopus.Deployment.Tenant.Name | ToLower | Replace \"[^a-zA-Z0-9]\" \"_\"}_${local.project_name_sanitized}"
  new_repo               = "#{Octopus.Deployment.Tenant.Name | ToLower | Replace \"[^a-zA-Z0-9]\" \"_\"}_${local.project_name_sanitized}"
  cac_org                = "octopuscac"
  cac_password           = "Password01!"
  cac_username           = "octopus"
  cac_host               = "gitea:3000"
  cac_proto              = "http"
  template_repo          = "#{Octopus.Project.Name | ToLower | Replace \"[^a-zA-Z0-9]\" \"_\"}"
  project_dir            = ".octopus/project"
  backend                = "#{Octopus.Project.Name | ToLower | Replace \"[^a-zA-Z0-9]\" \"_\"}"
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

resource "octopusdeploy_runbook" "runbook_merge_git" {
  name                        = "__ 5. Merge with Downstream Project"
  project_id                  = data.octopusdeploy_projects.project.projects[0].id
  environment_scope           = "Specified"
  environments                = [data.octopusdeploy_environments.sync.environments[0].id]
  force_package_download      = false
  default_guided_failure_mode = "EnvironmentDefault"
  description                 = "This project merges the changes from an upstream CaC repo into the downstream CaC repo."
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

resource "octopusdeploy_runbook_process" "runbook_process_merge_git" {
  runbook_id = octopusdeploy_runbook.runbook_merge_git.id

  step {
    condition           = "Success"
    name                = "Merge Deployment Process"
    package_requirement = "LetOctopusDecide"
    start_trigger       = "StartAfterPrevious"

    action {
      action_type                        = "Octopus.Script"
      name                               = "Merge Deployment Process"
      condition                          = "Success"
      run_on_server                      = true
      is_disabled                        = false
      can_be_used_for_project_versioning = true
      is_required                        = false
      worker_pool_id                     = data.octopusdeploy_worker_pools.workerpool_default.worker_pools[0].id
      properties                         = {
        "Octopus.Action.Script.ScriptSource" = "Inline"
        "Octopus.Action.Script.Syntax"       = "Python"
        "Octopus.Action.Script.ScriptBody"   = file("../../shared_scripts/merge_repo.py")
        "OctopusUseBundledTooling" = "False"
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


resource "octopusdeploy_runbook" "runbook_merge_all_git" {
  name                        = "__ 6. Merge All Downstream Projects"
  project_id                  = data.octopusdeploy_projects.project.projects[0].id
  environment_scope           = "Specified"
  environments                = [data.octopusdeploy_environments.sync.environments[0].id]
  force_package_download      = false
  default_guided_failure_mode = "EnvironmentDefault"
  description                 = "This project merges the changes from an upstream CaC repo into all non-conflicting downstream CaC repos."
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

resource "octopusdeploy_runbook_process" "runbook_process_merge_all_git" {
  runbook_id = octopusdeploy_runbook.runbook_merge_all_git.id

  step {
    condition           = "Success"
    name                = "Merge Deployment Process"
    package_requirement = "LetOctopusDecide"
    start_trigger       = "StartAfterPrevious"

    action {
      action_type                        = "Octopus.Script"
      name                               = "Merge Deployment Process"
      condition                          = "Success"
      run_on_server                      = true
      is_disabled                        = false
      can_be_used_for_project_versioning = true
      is_required                        = false
      worker_pool_id                     = data.octopusdeploy_worker_pools.workerpool_default.worker_pools[0].id
      properties                         = {
        "Octopus.Action.Script.ScriptSource" = "Inline"
        "Octopus.Action.Script.Syntax"       = "Python"
        "Octopus.Action.Script.ScriptBody"   = file("../../shared_scripts/merge_all_downstream_projects.py")
        "OctopusUseBundledTooling" = "False"
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
