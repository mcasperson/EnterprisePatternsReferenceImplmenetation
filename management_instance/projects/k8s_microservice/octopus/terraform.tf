terraform {
  required_providers {
    octopusdeploy = { source = "OctopusDeployLabs/octopusdeploy", version = "0.22.0" }
  }
}

# Look up the "Export Options" library variable set. This variable set is excluded from the Terraform serialization,
# but is used in some of the management runbooks when deploying the template projects. The "Export Options"
# library variable set allows us to keep variables out of the downstream projects because it is trivial to exclude a
# library variable set from serialization. In contrast, project variables for CaC enabled projects are very difficult
# to exclude individual variables as they are automatically written to Git and any forked Git repo automatically
# inherits them.
data "octopusdeploy_library_variable_sets" "export_options" {
  partial_name = "Export Options"
  skip         = 0
  take         = 1
  lifecycle {
    postcondition {
      error_message = "Failed to resolve a library variable set called \"Export Options\". This resource must exist in the space before this Terraform configuration is applied."
      condition     = length(self.library_variable_sets) != 0
    }
  }
}

data "octopusdeploy_project_groups" "project_group_google_microservice_demo" {
  ids          = null
  partial_name = "${var.project_group_google_microservice_demo_name}"
  skip         = 0
  take         = 1
}

data "octopusdeploy_lifecycles" "lifecycle_application" {
  ids          = null
  partial_name = "Simple"
  skip         = 0
  take         = 1
}

data "octopusdeploy_feeds" "feed_docker_hub" {
  feed_type    = "Docker"
  ids          = null
  partial_name = "Docker"
  skip         = 0
  take         = 1
}

data "octopusdeploy_feeds" "maven" {
  feed_type    = "Maven"
  partial_name = "Sales Maven Feed"
  skip         = 0
  take         = 1
}

data "octopusdeploy_worker_pools" "workerpool_default" {
  name = "Default Worker Pool"
  ids  = null
  skip = 0
  take = 1
  lifecycle {
    postcondition {
      error_message = "Failed to resolve a worker pool called \"Default Worker Pool\". This resource must exist in the space before this Terraform configuration is applied."
      condition     = length(self.worker_pools) != 0
    }
  }
}

data "octopusdeploy_library_variable_sets" "octopus_server" {
  partial_name = "Octopus Server"
  skip         = 0
  take         = 1
  lifecycle {
    postcondition {
      error_message = "Failed to resolve a library variable set called \"Octopus Server\". This resource must exist in the space before this Terraform configuration is applied."
      condition     = length(self.library_variable_sets) != 0
    }
  }
}

data "octopusdeploy_library_variable_sets" "variable" {
  partial_name = "This Instance"
  skip         = 0
  take         = 1
  lifecycle {
    postcondition {
      error_message = "Failed to resolve a library variable set called \"This Instance\". This resource must exist in the space before this Terraform configuration is applied."
      condition     = length(self.library_variable_sets) != 0
    }
  }
}

data "octopusdeploy_environments" "development" {
  partial_name = "Development"
  skip         = 0
  take         = 1
  lifecycle {
    postcondition {
      error_message = "Failed to resolve an account called \"Development\". This resource must exist in the space before this Terraform configuration is applied."
      condition     = length(self.environments) != 0
    }
  }
}

data "octopusdeploy_environments" "test" {
  partial_name = "Test"
  skip         = 0
  take         = 1
  lifecycle {
    postcondition {
      error_message = "Failed to resolve an account called \"Test\". This resource must exist in the space before this Terraform configuration is applied."
      condition     = length(self.environments) != 0
    }
  }
}

data "octopusdeploy_environments" "production" {
  partial_name = "Production"
  skip         = 0
  take         = 1
  lifecycle {
    postcondition {
      error_message = "Failed to resolve an account called \"Production\". This resource must exist in the space before this Terraform configuration is applied."
      condition     = length(self.environments) != 0
    }
  }
}

data "octopusdeploy_library_variable_sets" "slack" {
  partial_name = "Shared Slack"
  skip         = 0
  take         = 1
  lifecycle {
    postcondition {
      error_message = "Failed to resolve a library variable set called \"Shared Slack\". This resource must exist in the space before this Terraform configuration is applied."
      condition     = length(self.library_variable_sets) != 0
    }
  }
}

variable "octopusprintvariables_1" {
  type        = string
  nullable    = false
  sensitive   = false
  description = "The value associated with the variable OctopusPrintVariables"
  default     = "False"
}

resource "octopusdeploy_variable" "run_as_group" {
  owner_id     = octopusdeploy_project.project_k8s_microservice.id
  value        = ""
  name         = "Kubernetes.Security.PodSecurityRunAsGroup"
  type         = "String"
  description  = "The non-root group to run the container as. Leave blank to assume the user defined in the Docker image."
  is_sensitive = false
}

resource "octopusdeploy_variable" "run_as_user" {
  owner_id     = octopusdeploy_project.project_k8s_microservice.id
  value        = ""
  name         = "Kubernetes.Security.PodSecurityRunAsUser"
  type         = "String"
  description  = "The non-root user to run the container as. Leave blank to assume the user defined in the Docker image."
  is_sensitive = false
}

resource "octopusdeploy_variable" "namespace" {
  owner_id     = octopusdeploy_project.project_k8s_microservice.id
  value        = "#{Octopus.Space.Name | Replace \"[^A-Za-z0-9]\" \"-\" | ToLower}-#{Kubernetes.Application.Group}-#{Octopus.Environment.Name | Replace \" .*\" \"\" | ToLower}#{if Octopus.Deployment.Tenant.Name}-#{Octopus.Deployment.Tenant.Name | Replace \"[^A-Za-z0-9]\" \"-\" | ToLower}#{/if}"
  name         = "Kubernetes.Deployment.Namespace"
  type         = "String"
  description  = "The namespace is generated from the name of the space, the application group name, and the environment"
  is_sensitive = false
}

resource "octopusdeploy_variable" "base_name" {
  owner_id    = octopusdeploy_project.project_k8s_microservice.id
  value       = "#{Octopus.Action[Deploy App].Package[service].PackageId | Replace \"^.*/\" \"\" | Replace \"[^A-Za-z0-9]\" \"-\" | ToLower}"
  name        = "Kubernetes.Deployment.BaseName"
  type        = "String"
  description = join("", [
    "The base name is based on the name of the package. It is used as the prefix for the Kubernetes deployment name, and is used as a label on the deployment. ",
    "Octostache filters are used to sanitize the package name. ",
    "`Replace \"^.*/\" \"\"`` strips everything up to the first forward slash, for example removing `octopussamples/` from the image name `octopussamples/imagename`. ",
    "`Replace \"[^A-Za-z0-9]\" \"-\"` replaces any non alpha-numeric character with a dash."
  ])
  is_sensitive = false
}

resource "octopusdeploy_variable" "deployment_name" {
  owner_id     = octopusdeploy_project.project_k8s_microservice.id
  value        = "#{Kubernetes.Deployment.BaseName}#{unless Octopus.Release.Channel.Name == \"Mainline\"}-#{Octopus.Release.Channel.Name | Replace \"[^A-Za-z0-9]\" \"-\" | ToLower}#{/unless}"
  name         = "Kubernetes.Deployment.Name"
  type         = "String"
  description  = "The deployment name appends the channel and tenant names to the base name. This creates a value that is unique per application, channel, and tenant."
  is_sensitive = false
}

resource "octopusdeploy_variable" "k8s_application_group" {
  owner_id     = octopusdeploy_project.project_k8s_microservice.id
  value        = "test"
  name         = "Kubernetes.Application.Group"
  type         = "String"
  description  = "The name of the application group, which is used to construct the namespace the microservices are placed into. Applications with the same group name are therefor placed in the same namespace."
  is_sensitive = false
}

resource "octopusdeploy_variable" "k8s_port" {
  owner_id     = octopusdeploy_project.project_k8s_microservice.id
  value        = "8080"
  name         = "Kubernetes.Application.Port"
  type         = "String"
  description  = "The port exposed by the application."
  is_sensitive = false
}

resource "octopusdeploy_variable" "read_only_fs" {
  owner_id     = octopusdeploy_project.project_k8s_microservice.id
  value        = "False"
  name         = "Kubernetes.Application.ReadOnlyFileSystem"
  type         = "String"
  description  = "Set to True to enable a read-only file system for the container, and false otherwise. Is assumed to be True if no value is set."
  is_sensitive = false
}

resource "octopusdeploy_variable" "k8s_image" {
  owner_id     = octopusdeploy_project.project_k8s_microservice.id
  value        = "octopussamples/octopub-selfcontained"
  name         = "Kubernetes.Application.Image"
  type         = "String"
  description  = "The Docker image deployed by this application."
  is_sensitive = false
}

resource "octopusdeploy_variable" "k8s_env_vars" {
  owner_id     = octopusdeploy_project.project_k8s_microservice.id
  value        = "KEY1: Value1\nKEY2: Value2"
  name         = "Kubernetes.Application.EnvVars"
  type         = "String"
  description  = "Replace this variable with key value pairs that make up the microservice env vars. Leave the variable empty to skip the creation of the environment variables."
  is_sensitive = false
}

resource "octopusdeploy_variable" "octopusprintvariables_1" {
  owner_id     = octopusdeploy_project.project_k8s_microservice.id
  value        = var.octopusprintvariables_1
  name         = "OctopusPrintVariables"
  type         = "String"
  description  = "A debug variable used to print all variables to the logs. See [here](https://octopus.com/docs/support/debug-problems-with-octopus-variables) for more information."
  is_sensitive = false
}

resource "octopusdeploy_channel" "channel__mainline" {
  name        = "Mainline"
  description = "The channel through which mainline releases are deployed"
  project_id  = octopusdeploy_project.project_k8s_microservice.id
  is_default  = true

  rule {

    action_package {
      deployment_action = "Deploy App"
      package_reference = "service"
    }

    tag = "^$"
  }

  tenant_tags = []
  depends_on  = [octopusdeploy_deployment_process.deployment_process_project_k8s_microservice]
}

resource "octopusdeploy_deployment_process" "deployment_process_project_k8s_microservice" {
  project_id = octopusdeploy_project.project_k8s_microservice.id

  step {
    condition            = "Variable"
    condition_expression = "#{if Kubernetes.Application.EnvVars}True#{/if}#{unless Kubernetes.Application.EnvVars}False#{/unless}"
    name                 = "Deploy Env Var ConfigMap"
    package_requirement  = "LetOctopusDecide"
    start_trigger        = "StartAfterPrevious"

    action {
      action_type                        = "Octopus.KubernetesDeployRawYaml"
      name                               = "Deploy Env Var ConfigMap"
      condition                          = "Success"
      run_on_server                      = true
      is_disabled                        = false
      can_be_used_for_project_versioning = false
      is_required                        = false
      worker_pool_id                     = ""
      worker_pool_variable               = ""
      properties                         = {
        "Octopus.Action.KubernetesContainers.CustomResourceYaml" = <<EOT
apiVersion: v1
kind: ConfigMap
metadata:
  name: "#{Kubernetes.Deployment.Name}"
  namespace: "#{Kubernetes.Deployment.Namespace}"
data:
#{Kubernetes.Application.EnvVars | Indent 2}
EOT
        "Octopus.Action.Script.ScriptSource"                     = "Inline"
        "Octopus.Action.KubernetesContainers.Namespace"          = "#{Kubernetes.Deployment.Namespace}"
      }
      environments          = []
      excluded_environments = []
      channels              = []
      tenant_tags           = []
      features              = []
    }

    properties   = {}
    target_roles = ["k8s"]
  }

  step {
    condition           = "Success"
    name                = "Deploy App"
    package_requirement = "LetOctopusDecide"
    start_trigger       = "StartAfterPrevious"

    action {
      action_type                        = "Octopus.KubernetesDeployContainers"
      name                               = "Deploy App"
      condition                          = "Success"
      run_on_server                      = true
      is_disabled                        = false
      can_be_used_for_project_versioning = true
      is_required                        = false
      worker_pool_id                     = data.octopusdeploy_worker_pools.workerpool_default.worker_pools[0].id
      properties                         = {
        "Octopus.Action.KubernetesContainers.ServiceNameType"               = "External"
        "Octopus.Action.KubernetesContainers.PersistentVolumeClaims"        = jsonencode([])
        "Octopus.Action.KubernetesContainers.DeploymentAnnotations"         = jsonencode([])
        "Octopus.Action.KubernetesContainers.TerminationGracePeriodSeconds" = "5"
        "Octopus.Action.KubernetesContainers.PodSecuritySysctls"            = jsonencode([])
        "Octopus.Action.KubernetesContainers.PodServiceAccountName"         = "default"
        "Octopus.Action.KubernetesContainers.PodSecurityRunAsNonRoot"       = "false"
        "Octopus.Action.KubernetesContainers.ServiceType"                   = "LoadBalancer"
        "Octopus.Action.KubernetesContainers.DeploymentResourceType"        = "Deployment"
        "Octopus.Action.KubernetesContainers.PodSecurityRunAsGroup"         = "#{if Kubernetes.Security.PodSecurityRunAsGroup}#{Kubernetes.Security.PodSecurityRunAsGroup}#{/if}"
        "Octopus.Action.KubernetesContainers.PodSecurityRunAsUser"          = "#{if Kubernetes.Security.PodSecurityRunAsUser}#{Kubernetes.Security.PodSecurityRunAsUser}#{/if}"
        "Octopus.Action.Kubernetes.ResourceStatusCheck"                     = "False"
        "Octopus.Action.KubernetesContainers.DeploymentWait"                = "Wait"
        "Octopus.Action.KubernetesContainers.DeploymentStyle"               = "RollingUpdate"
        "Octopus.Action.KubernetesContainers.Namespace"                     = "#{Kubernetes.Deployment.Namespace}"
        "Octopus.Action.KubernetesContainers.PodAntiAffinity"               = jsonencode([])
        "OctopusUseBundledTooling"                                          = "False"
        "Octopus.Action.KubernetesContainers.CombinedVolumes"               = jsonencode([])
        "Octopus.Action.KubernetesContainers.NodeAffinity"                  = jsonencode([])
        "Octopus.Action.KubernetesContainers.Tolerations"                   = jsonencode([])
        "Octopus.Action.KubernetesContainers.PodAnnotations"                = jsonencode([])
        "Octopus.Action.KubernetesContainers.DeploymentName"                = "#{Kubernetes.Deployment.Name}"
        "Octopus.Action.KubernetesContainers.PodAffinity"                   = jsonencode([])
        "Octopus.Action.KubernetesContainers.IngressAnnotations"            = jsonencode([])
        "Octopus.Action.KubernetesContainers.Containers"                    = jsonencode([
          {
            "AcquisitionLocation"    = "NotAcquired"
            "Args"                   = []
            "ConfigMapEnvFromSource" = [
              {
                "key" = "#{if Kubernetes.Application.EnvVars}#{Kubernetes.Deployment.Name}#{/if}"
              },
            ]
            "ConfigMapEnvironmentVariables" = []
            "EnvironmentVariables"          = [
              {
                "key"   = "PORT"
                "value" = "#{Kubernetes.Application.Port}"
              }
            ]
            "FeedId"       = data.octopusdeploy_feeds.feed_docker_hub.feeds[0].id
            "IsNew"        = "true"
            "StartupProbe" = {
              "failureThreshold"    = ""
              "initialDelaySeconds" = ""
              "timeoutSeconds"      = ""
              "type"                = "\u003cnil\u003e"
              "exec"                = {
                "command" = []
              }
              "httpGet" = {
                "host"        = ""
                "httpHeaders" = []
                "path"        = ""
                "port"        = ""
                "scheme"      = ""
              }
              "periodSeconds"    = ""
              "successThreshold" = ""
              "tcpSocket"        = {
                "host" = ""
                "port" = ""
              }
            }
            "VolumeMounts"  = []
            "LivenessProbe" = {
              "timeoutSeconds" = ""
              "exec"           = {
                "command" = []
              }
              "successThreshold"    = ""
              "initialDelaySeconds" = "20"
              "periodSeconds"       = "15"
              "tcpSocket"           = {
                "host" = ""
                "port" = ""
              }
              "type"             = "HttpGet"
              "failureThreshold" = ""
              "httpGet"          = {
                "port"        = "#{Kubernetes.Application.Port}"
                "scheme"      = "HTTP"
                "host"        = ""
                "httpHeaders" = []
                "path"        = "/"
              }
            }
            "Properties" = {}
            "Resources"  = {
              "limits" = {
                "nvidiaGpu"        = ""
                "amdGpu"           = ""
                "cpu"              = "500m"
                "ephemeralStorage" = ""
                "memory"           = "512Mi"
              }
              "requests" = {
                "ephemeralStorage" = ""
                "memory"           = "256Mi"
                "cpu"              = "250m"
              }
            }
            "SecretEnvironmentVariables" = []
            "SecurityContext"            = {
              "runAsUser"      = ""
              "seLinuxOptions" = {
                "type"  = ""
                "user"  = ""
                "level" = ""
                "role"  = ""
              }
              "allowPrivilegeEscalation" = "false"
              "capabilities"             = {
                "add"  = []
                "drop" = [
                  "all",
                ]
              }
              "privileged"             = "false"
              "readOnlyRootFilesystem" = "#{if Kubernetes.Application.ReadOnlyFileSystem != \"\"}#{Kubernetes.Application.ReadOnlyFileSystem}#{/if}#{if Kubernetes.Application.ReadOnlyFileSystem == \"\"}True#{/if}"
              "runAsGroup"             = ""
              "runAsNonRoot"           = ""
            }
            "Name"           = "service"
            "ReadinessProbe" = {
              "exec" = {
                "command" = [
                  "/bin/grpc_health_probe",
                  "-addr=:#{Kubernetes.Application.Port}",
                ]
              }
              "initialDelaySeconds" = "20"
              "successThreshold"    = ""
              "tcpSocket"           = {
                "host" = ""
                "port" = ""
              }
              "timeoutSeconds"   = ""
              "failureThreshold" = ""
              "httpGet"          = {
                "port"        = "#{Kubernetes.Application.Port}"
                "scheme"      = "HTTP"
                "host"        = ""
                "httpHeaders" = []
                "path"        = "/"
              }
              "periodSeconds" = "15"
              "type"          = "HttpGet"
            }
            "Command"                      = []
            "FieldRefEnvironmentVariables" = []
            "InitContainer"                = "False"
            "Lifecycle"                    = {}
            "PackageId"                    = "#{Kubernetes.Application.Image}"
            "Ports"                        = [
              {
                "name"  = "Port"
                "value" = "#{Kubernetes.Application.Port}"
              },
            ]
            "SecretEnvFromSource" = []
          },
        ])
        "Octopus.Action.KubernetesContainers.DnsConfigOptions" = jsonencode([])
        "Octopus.Action.KubernetesContainers.ServicePorts"     = jsonencode([
          {
            "port"       = "#{Kubernetes.Application.Port}"
            "targetPort" = "#{Kubernetes.Application.Port}"
            "name"       = "http"
          },
        ])
        "Octopus.Action.KubernetesContainers.DeploymentLabels" = jsonencode({
          "app" = "#{Kubernetes.Deployment.BaseName}"
        })
        "Octopus.Action.KubernetesContainers.PodSecurityFsGroup"      = ""
        "Octopus.Action.KubernetesContainers.Replicas"                = "1"
        "Octopus.Action.KubernetesContainers.ServiceName"             = "#{Kubernetes.Deployment.Name}"
        "Octopus.Action.KubernetesContainers.LoadBalancerAnnotations" = jsonencode([])
      }

      environments          = []
      excluded_environments = []
      channels              = []
      tenant_tags           = []

      package {
        name                      = "service"
        package_id                = "#{Kubernetes.Application.Image}"
        acquisition_location      = "NotAcquired"
        extract_during_deployment = false
        feed_id                   = data.octopusdeploy_feeds.feed_docker_hub.feeds[0].id
        properties                = { Extract = "False" }
      }
      features = ["Octopus.Features.KubernetesService"]
    }

    properties   = {}
    target_roles = ["k8s"]
  }
}

variable "project_group_google_microservice_demo_name" {
  type        = string
  nullable    = false
  sensitive   = false
  description = "The name of the project group to lookup"
  default     = "Kubernetes"
}

variable "octopusprintevaluatedvariables_1" {
  type        = string
  nullable    = false
  sensitive   = false
  description = "The value associated with the variable OctopusPrintEvaluatedVariables"
  default     = "False"
}

resource "octopusdeploy_variable" "octopusprintevaluatedvariables_1" {
  owner_id     = octopusdeploy_project.project_k8s_microservice.id
  value        = var.octopusprintevaluatedvariables_1
  name         = "OctopusPrintEvaluatedVariables"
  type         = "String"
  description  = "A debug variable used to print all variables to the logs. See [here](https://octopus.com/docs/support/debug-problems-with-octopus-variables) for more information."
  is_sensitive = false
}


variable "project_k8s_microservice_template_name" {
  type        = string
  nullable    = false
  sensitive   = false
  description = "The name of the microservice project"
  default     = "K8S Microservice Template"
}

resource "octopusdeploy_project" "project_k8s_microservice" {
  name                                 = var.project_k8s_microservice_template_name
  auto_create_release                  = false
  default_guided_failure_mode          = "EnvironmentDefault"
  default_to_skip_if_already_installed = false
  description                          = "Deploys a standard microservice."
  discrete_channel_release             = false
  is_disabled                          = false
  is_version_controlled                = false
  lifecycle_id                         = data.octopusdeploy_lifecycles.lifecycle_application.lifecycles[0].id
  project_group_id                     = data.octopusdeploy_project_groups.project_group_google_microservice_demo.project_groups[0].id
  included_library_variable_sets       = [
    data.octopusdeploy_library_variable_sets.variable.library_variable_sets[0].id,
    data.octopusdeploy_library_variable_sets.octopus_server.library_variable_sets[0].id,
    data.octopusdeploy_library_variable_sets.slack.library_variable_sets[0].id,
    data.octopusdeploy_library_variable_sets.export_options.library_variable_sets[0].id
  ]
  tenanted_deployment_participation = "Untenanted"

  connectivity_policy {
    allow_deployments_to_no_targets = false
    exclude_unhealthy_targets       = false
    skip_machine_behavior           = "SkipUnavailableMachines"
  }

  versioning_strategy {
    template = "#{Octopus.Version.LastMajor}.#{Octopus.Version.LastMinor}.#{Octopus.Version.LastPatch}.#{Octopus.Version.NextRevision}"
  }
}

resource "octopusdeploy_runbook_process" "runbook_process_k8s_get_service" {
  runbook_id = octopusdeploy_runbook.runbook_k8s_get_service.id

  step {
    condition           = "Success"
    name                = "Get Pod"
    package_requirement = "LetOctopusDecide"
    start_trigger       = "StartAfterPrevious"

    action {
      action_type                        = "Octopus.KubernetesRunScript"
      name                               = "Describe Pod"
      condition                          = "Success"
      run_on_server                      = true
      is_disabled                        = false
      can_be_used_for_project_versioning = false
      is_required                        = false
      worker_pool_id                     = ""
      worker_pool_variable               = ""
      properties                         = {
        "Octopus.Action.Script.ScriptSource"            = "Inline"
        "Octopus.Action.Script.Syntax"                  = "PowerShell"
        "Octopus.Action.Script.ScriptBody"              = "\u003c#\n    This script provides a general purpose method for querying Kubernetes resources. It supports common operations\n    like get, describe, logs and output formats like yaml and json. Output can be captured as artifacts.\n#\u003e\n\n\u003c#\n.Description\nExecute an application, capturing the output. Based on https://stackoverflow.com/a/33652732/157605\n#\u003e\nFunction Execute-Command ($commandPath, $commandArguments)\n{\n  Write-Host \"Executing: $commandPath $($commandArguments -join \" \")\"\n  \n  Try {\n    $pinfo = New-Object System.Diagnostics.ProcessStartInfo\n    $pinfo.FileName = $commandPath\n    $pinfo.RedirectStandardError = $true\n    $pinfo.RedirectStandardOutput = $true\n    $pinfo.UseShellExecute = $false\n    $pinfo.Arguments = $commandArguments\n    $p = New-Object System.Diagnostics.Process\n    $p.StartInfo = $pinfo\n    $p.Start() | Out-Null\n    [pscustomobject]@{\n        stdout = $p.StandardOutput.ReadToEnd()\n        stderr = $p.StandardError.ReadToEnd()\n        ExitCode = $p.ExitCode\n    }\n    $p.WaitForExit()\n  }\n  Catch {\n     exit\n  }\n}\n\n\u003c#\n.Description\nFind any resource names that match a wildcard input if one was specified\n#\u003e\nfunction Get-Resources() \n{\n    $names = $OctopusParameters[\"K8SInspectNames\"] -Split \"`n\" | % {$_.Trim()}\n    \n    if ($OctopusParameters[\"K8SInspectNames\"] -match '\\*' )\n    {\n        return Execute-Command kubectl (@(\"-o\", \"json\", \"get\", $OctopusParameters[\"K8SInspectResource\"])) |\n            # Select the stdout property from the execution\n            Select-Object -ExpandProperty stdout |\n            # Convert the output from JSON\n            ConvertFrom-JSON | \n            # Get the items object from the kubectl response\n            % {if ((Get-Member -InputObject $_ -Name items).Count -ne 0) {Select-Object -InputObject $_ -ExpandProperty items} else {$_}} |\n            # Extract the name\n            % {$_.metadata.name} |\n            # Find any matching resources\n            ? {$k8sName = $_; ($names | ? {$k8sName -like $_}).Count -ne 0}\n    }\n    else\n    {\n        return $names\n    }\n}\n\n\u003c#\n.Description\nGet the kubectl arguments for a given action\n#\u003e\nfunction Get-KubectlVerb() \n{\n    switch($OctopusParameters[\"K8SInspectKubectlVerb\"])\n    {\n        \"get json\" {return ,@(\"-o\", \"json\", \"get\")}\n        \"get yaml\" {return ,@(\"-o\", \"yaml\", \"get\")}\n        \"describe\" {return ,@(\"describe\")}\n        \"logs\" {return ,@(\"logs\")}\n        \"logs tail\" {return ,@(\"logs\", \"--tail\", \"100\")}\n        \"previous logs\" {return ,@(\"logs\", \"--previous\")}\n        \"previous logs tail\" {return ,@(\"logs\", \"--previous\", \"--tail\", \"100\")}\n        default {return ,@(\"get\")}\n    }\n}\n\n\u003c#\n.Description\nGet an appropiate file extension based on the selected action\n#\u003e\nfunction Get-ArtifactExtension() \n{\n   switch($OctopusParameters[\"K8SInspectKubectlVerb\"])\n    {\n        \"get json\" {\"json\"}\n        \"get yaml\" {\"yaml\"}\n        default {\"txt\"}\n    }\n}\n\nif ($OctopusParameters[\"K8SInspectKubectlVerb\"] -like \"*logs*\") \n{\n    if ( -not @($OctopusParameters[\"K8SInspectResource\"]) -like \"pod*\")\n    {\n        Write-Error \"Logs can only be returned for pods, not $($OctopusParameters[\"K8SInspectResource\"])\"\n    }\n    else\n    {\n        Execute-Command kubectl (@(\"-o\", \"json\", \"get\", \"pods\") + (Get-Resources)) |\n            # Select the stdout property from the execution\n            Select-Object -ExpandProperty stdout |\n            # Convert the output from JSON\n            ConvertFrom-JSON | \n            # Get the items object from the kubectl response\n            % {if ((Get-Member -InputObject $_ -Name items).Count -ne 0) {Select-Object -InputObject $_ -ExpandProperty items} else {$_}} |\n            # Get the pod logs for each container\n            % {\n                $podDetails = $_\n                @{\n                    logs=$podDetails.spec.containers | % {$logs=\"\"} {$logs += (Select-Object -InputObject (Execute-Command kubectl ((Get-KubectlVerb) + @($podDetails.metadata.name, \"-c\", $_.name))) -ExpandProperty stdout)} {$logs}; \n                    name=$podDetails.metadata.name\n                }                \n            } |\n            # Write the output\n            % {Write-Host $_.logs; $_} |\n            # Optionally capture the artifact\n            % {\n                if ($OctopusParameters[\"K8SInspectCreateArtifact\"] -ieq \"true\") \n                {\n                    Set-Content -Path \"$($_.name).$(Get-ArtifactExtension)\" -Value $_.logs\n                    New-OctopusArtifact \"$($_.name).$(Get-ArtifactExtension)\"\n                }\n            }\n    }      \n}\nelse\n{\n    Execute-Command kubectl ((Get-KubectlVerb) + @($OctopusParameters[\"K8SInspectResource\"]) + (Get-Resources)) |\n        % {Select-Object -InputObject $_ -ExpandProperty stdout} |\n        % {Write-Host $_; $_} |\n        % {\n            if ($OctopusParameters[\"K8SInspectCreateArtifact\"] -ieq \"true\") \n            {\n                Set-Content -Path \"output.$(Get-ArtifactExtension)\" -Value $_\n                New-OctopusArtifact \"output.$(Get-ArtifactExtension)\"\n            }\n        }\n}\n"
        "K8SInspectNames"                               = "#{Kubernetes.Deployment.Name}*"
        "K8SInspectKubectlVerb"                         = "get"
        "K8SInspectCreateArtifact"                      = "False"
        "K8SInspectResource"                            = "service"
        "Octopus.Action.KubernetesContainers.Namespace" = "#{Kubernetes.Deployment.Namespace}"
      }
      environments          = []
      excluded_environments = []
      channels              = []
      tenant_tags           = []
      features              = []
    }

    properties   = {}
    target_roles = ["k8s"]
  }
}

resource "octopusdeploy_runbook" "runbook_k8s_get_service" {
  name              = "Get Service"
  project_id        = octopusdeploy_project.project_k8s_microservice.id
  environment_scope = "Specified"
  environments      = [
    data.octopusdeploy_environments.development.environments[0].id,
    data.octopusdeploy_environments.test.environments[0].id,
    data.octopusdeploy_environments.production.environments[0].id
  ]
  force_package_download      = false
  default_guided_failure_mode = "EnvironmentDefault"
  description                 = "Gets the services in the namespace representing an environment. This runbook is safe to run at any time."
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

resource "octopusdeploy_runbook_process" "runbook_process_k8s_get_pod" {
  runbook_id = octopusdeploy_runbook.runbook_k8s_get_pod.id

  step {
    condition           = "Success"
    name                = "Get Pod"
    package_requirement = "LetOctopusDecide"
    start_trigger       = "StartAfterPrevious"

    action {
      action_type                        = "Octopus.KubernetesRunScript"
      name                               = "Describe Pod"
      condition                          = "Success"
      run_on_server                      = true
      is_disabled                        = false
      can_be_used_for_project_versioning = false
      is_required                        = false
      worker_pool_id                     = ""
      worker_pool_variable               = ""
      properties                         = {
        "Octopus.Action.Script.ScriptSource"            = "Inline"
        "Octopus.Action.Script.Syntax"                  = "PowerShell"
        "Octopus.Action.Script.ScriptBody"              = "\u003c#\n    This script provides a general purpose method for querying Kubernetes resources. It supports common operations\n    like get, describe, logs and output formats like yaml and json. Output can be captured as artifacts.\n#\u003e\n\n\u003c#\n.Description\nExecute an application, capturing the output. Based on https://stackoverflow.com/a/33652732/157605\n#\u003e\nFunction Execute-Command ($commandPath, $commandArguments)\n{\n  Write-Host \"Executing: $commandPath $($commandArguments -join \" \")\"\n  \n  Try {\n    $pinfo = New-Object System.Diagnostics.ProcessStartInfo\n    $pinfo.FileName = $commandPath\n    $pinfo.RedirectStandardError = $true\n    $pinfo.RedirectStandardOutput = $true\n    $pinfo.UseShellExecute = $false\n    $pinfo.Arguments = $commandArguments\n    $p = New-Object System.Diagnostics.Process\n    $p.StartInfo = $pinfo\n    $p.Start() | Out-Null\n    [pscustomobject]@{\n        stdout = $p.StandardOutput.ReadToEnd()\n        stderr = $p.StandardError.ReadToEnd()\n        ExitCode = $p.ExitCode\n    }\n    $p.WaitForExit()\n  }\n  Catch {\n     exit\n  }\n}\n\n\u003c#\n.Description\nFind any resource names that match a wildcard input if one was specified\n#\u003e\nfunction Get-Resources() \n{\n    $names = $OctopusParameters[\"K8SInspectNames\"] -Split \"`n\" | % {$_.Trim()}\n    \n    if ($OctopusParameters[\"K8SInspectNames\"] -match '\\*' )\n    {\n        return Execute-Command kubectl (@(\"-o\", \"json\", \"get\", $OctopusParameters[\"K8SInspectResource\"])) |\n            # Select the stdout property from the execution\n            Select-Object -ExpandProperty stdout |\n            # Convert the output from JSON\n            ConvertFrom-JSON | \n            # Get the items object from the kubectl response\n            % {if ((Get-Member -InputObject $_ -Name items).Count -ne 0) {Select-Object -InputObject $_ -ExpandProperty items} else {$_}} |\n            # Extract the name\n            % {$_.metadata.name} |\n            # Find any matching resources\n            ? {$k8sName = $_; ($names | ? {$k8sName -like $_}).Count -ne 0}\n    }\n    else\n    {\n        return $names\n    }\n}\n\n\u003c#\n.Description\nGet the kubectl arguments for a given action\n#\u003e\nfunction Get-KubectlVerb() \n{\n    switch($OctopusParameters[\"K8SInspectKubectlVerb\"])\n    {\n        \"get json\" {return ,@(\"-o\", \"json\", \"get\")}\n        \"get yaml\" {return ,@(\"-o\", \"yaml\", \"get\")}\n        \"describe\" {return ,@(\"describe\")}\n        \"logs\" {return ,@(\"logs\")}\n        \"logs tail\" {return ,@(\"logs\", \"--tail\", \"100\")}\n        \"previous logs\" {return ,@(\"logs\", \"--previous\")}\n        \"previous logs tail\" {return ,@(\"logs\", \"--previous\", \"--tail\", \"100\")}\n        default {return ,@(\"get\")}\n    }\n}\n\n\u003c#\n.Description\nGet an appropiate file extension based on the selected action\n#\u003e\nfunction Get-ArtifactExtension() \n{\n   switch($OctopusParameters[\"K8SInspectKubectlVerb\"])\n    {\n        \"get json\" {\"json\"}\n        \"get yaml\" {\"yaml\"}\n        default {\"txt\"}\n    }\n}\n\nif ($OctopusParameters[\"K8SInspectKubectlVerb\"] -like \"*logs*\") \n{\n    if ( -not @($OctopusParameters[\"K8SInspectResource\"]) -like \"pod*\")\n    {\n        Write-Error \"Logs can only be returned for pods, not $($OctopusParameters[\"K8SInspectResource\"])\"\n    }\n    else\n    {\n        Execute-Command kubectl (@(\"-o\", \"json\", \"get\", \"pods\") + (Get-Resources)) |\n            # Select the stdout property from the execution\n            Select-Object -ExpandProperty stdout |\n            # Convert the output from JSON\n            ConvertFrom-JSON | \n            # Get the items object from the kubectl response\n            % {if ((Get-Member -InputObject $_ -Name items).Count -ne 0) {Select-Object -InputObject $_ -ExpandProperty items} else {$_}} |\n            # Get the pod logs for each container\n            % {\n                $podDetails = $_\n                @{\n                    logs=$podDetails.spec.containers | % {$logs=\"\"} {$logs += (Select-Object -InputObject (Execute-Command kubectl ((Get-KubectlVerb) + @($podDetails.metadata.name, \"-c\", $_.name))) -ExpandProperty stdout)} {$logs}; \n                    name=$podDetails.metadata.name\n                }                \n            } |\n            # Write the output\n            % {Write-Host $_.logs; $_} |\n            # Optionally capture the artifact\n            % {\n                if ($OctopusParameters[\"K8SInspectCreateArtifact\"] -ieq \"true\") \n                {\n                    Set-Content -Path \"$($_.name).$(Get-ArtifactExtension)\" -Value $_.logs\n                    New-OctopusArtifact \"$($_.name).$(Get-ArtifactExtension)\"\n                }\n            }\n    }      \n}\nelse\n{\n    Execute-Command kubectl ((Get-KubectlVerb) + @($OctopusParameters[\"K8SInspectResource\"]) + (Get-Resources)) |\n        % {Select-Object -InputObject $_ -ExpandProperty stdout} |\n        % {Write-Host $_; $_} |\n        % {\n            if ($OctopusParameters[\"K8SInspectCreateArtifact\"] -ieq \"true\") \n            {\n                Set-Content -Path \"output.$(Get-ArtifactExtension)\" -Value $_\n                New-OctopusArtifact \"output.$(Get-ArtifactExtension)\"\n            }\n        }\n}\n"
        "K8SInspectNames"                               = "#{Kubernetes.Deployment.Name}*"
        "K8SInspectKubectlVerb"                         = "get"
        "K8SInspectCreateArtifact"                      = "False"
        "K8SInspectResource"                            = "pod"
        "Octopus.Action.KubernetesContainers.Namespace" = "#{Kubernetes.Deployment.Namespace}"
      }
      environments          = []
      excluded_environments = []
      channels              = []
      tenant_tags           = []
      features              = []
    }

    properties   = {}
    target_roles = ["k8s"]
  }
}

resource "octopusdeploy_runbook" "runbook_k8s_get_pod" {
  name              = "Get Pod"
  project_id        = octopusdeploy_project.project_k8s_microservice.id
  environment_scope = "Specified"
  environments      = [
    data.octopusdeploy_environments.development.environments[0].id,
    data.octopusdeploy_environments.test.environments[0].id,
    data.octopusdeploy_environments.production.environments[0].id
  ]
  force_package_download      = false
  default_guided_failure_mode = "EnvironmentDefault"
  description                 = "Gets the pods in the namespace representing an environment. This runbook is safe to run at any time."
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

resource "octopusdeploy_runbook_process" "runbook_process_k8s_describe_pod" {
  runbook_id = octopusdeploy_runbook.runbook_k8s_describe_pod.id

  step {
    condition           = "Success"
    name                = "Describe Pod"
    package_requirement = "LetOctopusDecide"
    start_trigger       = "StartAfterPrevious"

    action {
      action_type                        = "Octopus.KubernetesRunScript"
      name                               = "Describe Pod"
      condition                          = "Success"
      run_on_server                      = true
      is_disabled                        = false
      can_be_used_for_project_versioning = false
      is_required                        = false
      worker_pool_id                     = ""
      worker_pool_variable               = ""
      properties                         = {
        "Octopus.Action.Script.ScriptSource"            = "Inline"
        "Octopus.Action.Script.Syntax"                  = "PowerShell"
        "Octopus.Action.Script.ScriptBody"              = "\u003c#\n    This script provides a general purpose method for querying Kubernetes resources. It supports common operations\n    like get, describe, logs and output formats like yaml and json. Output can be captured as artifacts.\n#\u003e\n\n\u003c#\n.Description\nExecute an application, capturing the output. Based on https://stackoverflow.com/a/33652732/157605\n#\u003e\nFunction Execute-Command ($commandPath, $commandArguments)\n{\n  Write-Host \"Executing: $commandPath $($commandArguments -join \" \")\"\n  \n  Try {\n    $pinfo = New-Object System.Diagnostics.ProcessStartInfo\n    $pinfo.FileName = $commandPath\n    $pinfo.RedirectStandardError = $true\n    $pinfo.RedirectStandardOutput = $true\n    $pinfo.UseShellExecute = $false\n    $pinfo.Arguments = $commandArguments\n    $p = New-Object System.Diagnostics.Process\n    $p.StartInfo = $pinfo\n    $p.Start() | Out-Null\n    [pscustomobject]@{\n        stdout = $p.StandardOutput.ReadToEnd()\n        stderr = $p.StandardError.ReadToEnd()\n        ExitCode = $p.ExitCode\n    }\n    $p.WaitForExit()\n  }\n  Catch {\n     exit\n  }\n}\n\n\u003c#\n.Description\nFind any resource names that match a wildcard input if one was specified\n#\u003e\nfunction Get-Resources() \n{\n    $names = $OctopusParameters[\"K8SInspectNames\"] -Split \"`n\" | % {$_.Trim()}\n    \n    if ($OctopusParameters[\"K8SInspectNames\"] -match '\\*' )\n    {\n        return Execute-Command kubectl (@(\"-o\", \"json\", \"get\", $OctopusParameters[\"K8SInspectResource\"])) |\n            # Select the stdout property from the execution\n            Select-Object -ExpandProperty stdout |\n            # Convert the output from JSON\n            ConvertFrom-JSON | \n            # Get the items object from the kubectl response\n            % {if ((Get-Member -InputObject $_ -Name items).Count -ne 0) {Select-Object -InputObject $_ -ExpandProperty items} else {$_}} |\n            # Extract the name\n            % {$_.metadata.name} |\n            # Find any matching resources\n            ? {$k8sName = $_; ($names | ? {$k8sName -like $_}).Count -ne 0}\n    }\n    else\n    {\n        return $names\n    }\n}\n\n\u003c#\n.Description\nGet the kubectl arguments for a given action\n#\u003e\nfunction Get-KubectlVerb() \n{\n    switch($OctopusParameters[\"K8SInspectKubectlVerb\"])\n    {\n        \"get json\" {return ,@(\"-o\", \"json\", \"get\")}\n        \"get yaml\" {return ,@(\"-o\", \"yaml\", \"get\")}\n        \"describe\" {return ,@(\"describe\")}\n        \"logs\" {return ,@(\"logs\")}\n        \"logs tail\" {return ,@(\"logs\", \"--tail\", \"100\")}\n        \"previous logs\" {return ,@(\"logs\", \"--previous\")}\n        \"previous logs tail\" {return ,@(\"logs\", \"--previous\", \"--tail\", \"100\")}\n        default {return ,@(\"get\")}\n    }\n}\n\n\u003c#\n.Description\nGet an appropiate file extension based on the selected action\n#\u003e\nfunction Get-ArtifactExtension() \n{\n   switch($OctopusParameters[\"K8SInspectKubectlVerb\"])\n    {\n        \"get json\" {\"json\"}\n        \"get yaml\" {\"yaml\"}\n        default {\"txt\"}\n    }\n}\n\nif ($OctopusParameters[\"K8SInspectKubectlVerb\"] -like \"*logs*\") \n{\n    if ( -not @($OctopusParameters[\"K8SInspectResource\"]) -like \"pod*\")\n    {\n        Write-Error \"Logs can only be returned for pods, not $($OctopusParameters[\"K8SInspectResource\"])\"\n    }\n    else\n    {\n        Execute-Command kubectl (@(\"-o\", \"json\", \"get\", \"pods\") + (Get-Resources)) |\n            # Select the stdout property from the execution\n            Select-Object -ExpandProperty stdout |\n            # Convert the output from JSON\n            ConvertFrom-JSON | \n            # Get the items object from the kubectl response\n            % {if ((Get-Member -InputObject $_ -Name items).Count -ne 0) {Select-Object -InputObject $_ -ExpandProperty items} else {$_}} |\n            # Get the pod logs for each container\n            % {\n                $podDetails = $_\n                @{\n                    logs=$podDetails.spec.containers | % {$logs=\"\"} {$logs += (Select-Object -InputObject (Execute-Command kubectl ((Get-KubectlVerb) + @($podDetails.metadata.name, \"-c\", $_.name))) -ExpandProperty stdout)} {$logs}; \n                    name=$podDetails.metadata.name\n                }                \n            } |\n            # Write the output\n            % {Write-Host $_.logs; $_} |\n            # Optionally capture the artifact\n            % {\n                if ($OctopusParameters[\"K8SInspectCreateArtifact\"] -ieq \"true\") \n                {\n                    Set-Content -Path \"$($_.name).$(Get-ArtifactExtension)\" -Value $_.logs\n                    New-OctopusArtifact \"$($_.name).$(Get-ArtifactExtension)\"\n                }\n            }\n    }      \n}\nelse\n{\n    Execute-Command kubectl ((Get-KubectlVerb) + @($OctopusParameters[\"K8SInspectResource\"]) + (Get-Resources)) |\n        % {Select-Object -InputObject $_ -ExpandProperty stdout} |\n        % {Write-Host $_; $_} |\n        % {\n            if ($OctopusParameters[\"K8SInspectCreateArtifact\"] -ieq \"true\") \n            {\n                Set-Content -Path \"output.$(Get-ArtifactExtension)\" -Value $_\n                New-OctopusArtifact \"output.$(Get-ArtifactExtension)\"\n            }\n        }\n}\n"
        "K8SInspectNames"                               = "#{Kubernetes.Deployment.Name}*"
        "K8SInspectKubectlVerb"                         = "describe"
        "K8SInspectCreateArtifact"                      = "False"
        "K8SInspectResource"                            = "pod"
        "Octopus.Action.KubernetesContainers.Namespace" = "#{Kubernetes.Deployment.Namespace}"
      }
      environments          = []
      excluded_environments = []
      channels              = []
      tenant_tags           = []
      features              = []
    }

    properties   = {}
    target_roles = ["k8s"]
  }
}

resource "octopusdeploy_runbook" "runbook_k8s_describe_pod" {
  name              = "Describe Pod"
  project_id        = octopusdeploy_project.project_k8s_microservice.id
  environment_scope = "Specified"
  environments      = [
    data.octopusdeploy_environments.development.environments[0].id,
    data.octopusdeploy_environments.test.environments[0].id,
    data.octopusdeploy_environments.production.environments[0].id
  ]
  force_package_download      = false
  default_guided_failure_mode = "EnvironmentDefault"
  description                 = "Describes the pods in the namespace representing an environment. This runbook is safe to run at any time."
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

resource "octopusdeploy_runbook_process" "runbook_process_k8s_pod_logs" {
  runbook_id = octopusdeploy_runbook.runbook_k8s_pod_logs.id

  step {
    condition           = "Success"
    name                = "Describe Pod"
    package_requirement = "LetOctopusDecide"
    start_trigger       = "StartAfterPrevious"

    action {
      action_type                        = "Octopus.KubernetesRunScript"
      name                               = "Describe Pod"
      condition                          = "Success"
      run_on_server                      = true
      is_disabled                        = false
      can_be_used_for_project_versioning = false
      is_required                        = false
      worker_pool_id                     = ""
      worker_pool_variable               = ""
      properties                         = {
        "Octopus.Action.Script.ScriptSource"            = "Inline"
        "Octopus.Action.Script.Syntax"                  = "PowerShell"
        "Octopus.Action.Script.ScriptBody"              = "\u003c#\n    This script provides a general purpose method for querying Kubernetes resources. It supports common operations\n    like get, describe, logs and output formats like yaml and json. Output can be captured as artifacts.\n#\u003e\n\n\u003c#\n.Description\nExecute an application, capturing the output. Based on https://stackoverflow.com/a/33652732/157605\n#\u003e\nFunction Execute-Command ($commandPath, $commandArguments)\n{\n  Write-Host \"Executing: $commandPath $($commandArguments -join \" \")\"\n  \n  Try {\n    $pinfo = New-Object System.Diagnostics.ProcessStartInfo\n    $pinfo.FileName = $commandPath\n    $pinfo.RedirectStandardError = $true\n    $pinfo.RedirectStandardOutput = $true\n    $pinfo.UseShellExecute = $false\n    $pinfo.Arguments = $commandArguments\n    $p = New-Object System.Diagnostics.Process\n    $p.StartInfo = $pinfo\n    $p.Start() | Out-Null\n    [pscustomobject]@{\n        stdout = $p.StandardOutput.ReadToEnd()\n        stderr = $p.StandardError.ReadToEnd()\n        ExitCode = $p.ExitCode\n    }\n    $p.WaitForExit()\n  }\n  Catch {\n     exit\n  }\n}\n\n\u003c#\n.Description\nFind any resource names that match a wildcard input if one was specified\n#\u003e\nfunction Get-Resources() \n{\n    $names = $OctopusParameters[\"K8SInspectNames\"] -Split \"`n\" | % {$_.Trim()}\n    \n    if ($OctopusParameters[\"K8SInspectNames\"] -match '\\*' )\n    {\n        return Execute-Command kubectl (@(\"-o\", \"json\", \"get\", $OctopusParameters[\"K8SInspectResource\"])) |\n            # Select the stdout property from the execution\n            Select-Object -ExpandProperty stdout |\n            # Convert the output from JSON\n            ConvertFrom-JSON | \n            # Get the items object from the kubectl response\n            % {if ((Get-Member -InputObject $_ -Name items).Count -ne 0) {Select-Object -InputObject $_ -ExpandProperty items} else {$_}} |\n            # Extract the name\n            % {$_.metadata.name} |\n            # Find any matching resources\n            ? {$k8sName = $_; ($names | ? {$k8sName -like $_}).Count -ne 0}\n    }\n    else\n    {\n        return $names\n    }\n}\n\n\u003c#\n.Description\nGet the kubectl arguments for a given action\n#\u003e\nfunction Get-KubectlVerb() \n{\n    switch($OctopusParameters[\"K8SInspectKubectlVerb\"])\n    {\n        \"get json\" {return ,@(\"-o\", \"json\", \"get\")}\n        \"get yaml\" {return ,@(\"-o\", \"yaml\", \"get\")}\n        \"describe\" {return ,@(\"describe\")}\n        \"logs\" {return ,@(\"logs\")}\n        \"logs tail\" {return ,@(\"logs\", \"--tail\", \"100\")}\n        \"previous logs\" {return ,@(\"logs\", \"--previous\")}\n        \"previous logs tail\" {return ,@(\"logs\", \"--previous\", \"--tail\", \"100\")}\n        default {return ,@(\"get\")}\n    }\n}\n\n\u003c#\n.Description\nGet an appropiate file extension based on the selected action\n#\u003e\nfunction Get-ArtifactExtension() \n{\n   switch($OctopusParameters[\"K8SInspectKubectlVerb\"])\n    {\n        \"get json\" {\"json\"}\n        \"get yaml\" {\"yaml\"}\n        default {\"txt\"}\n    }\n}\n\nif ($OctopusParameters[\"K8SInspectKubectlVerb\"] -like \"*logs*\") \n{\n    if ( -not @($OctopusParameters[\"K8SInspectResource\"]) -like \"pod*\")\n    {\n        Write-Error \"Logs can only be returned for pods, not $($OctopusParameters[\"K8SInspectResource\"])\"\n    }\n    else\n    {\n        Execute-Command kubectl (@(\"-o\", \"json\", \"get\", \"pods\") + (Get-Resources)) |\n            # Select the stdout property from the execution\n            Select-Object -ExpandProperty stdout |\n            # Convert the output from JSON\n            ConvertFrom-JSON | \n            # Get the items object from the kubectl response\n            % {if ((Get-Member -InputObject $_ -Name items).Count -ne 0) {Select-Object -InputObject $_ -ExpandProperty items} else {$_}} |\n            # Get the pod logs for each container\n            % {\n                $podDetails = $_\n                @{\n                    logs=$podDetails.spec.containers | % {$logs=\"\"} {$logs += (Select-Object -InputObject (Execute-Command kubectl ((Get-KubectlVerb) + @($podDetails.metadata.name, \"-c\", $_.name))) -ExpandProperty stdout)} {$logs}; \n                    name=$podDetails.metadata.name\n                }                \n            } |\n            # Write the output\n            % {Write-Host $_.logs; $_} |\n            # Optionally capture the artifact\n            % {\n                if ($OctopusParameters[\"K8SInspectCreateArtifact\"] -ieq \"true\") \n                {\n                    Set-Content -Path \"$($_.name).$(Get-ArtifactExtension)\" -Value $_.logs\n                    New-OctopusArtifact \"$($_.name).$(Get-ArtifactExtension)\"\n                }\n            }\n    }      \n}\nelse\n{\n    Execute-Command kubectl ((Get-KubectlVerb) + @($OctopusParameters[\"K8SInspectResource\"]) + (Get-Resources)) |\n        % {Select-Object -InputObject $_ -ExpandProperty stdout} |\n        % {Write-Host $_; $_} |\n        % {\n            if ($OctopusParameters[\"K8SInspectCreateArtifact\"] -ieq \"true\") \n            {\n                Set-Content -Path \"output.$(Get-ArtifactExtension)\" -Value $_\n                New-OctopusArtifact \"output.$(Get-ArtifactExtension)\"\n            }\n        }\n}\n"
        "K8SInspectNames"                               = "#{Kubernetes.Deployment.Name}*"
        "K8SInspectKubectlVerb"                         = "logs"
        "K8SInspectCreateArtifact"                      = "False"
        "K8SInspectResource"                            = "pod"
        "Octopus.Action.KubernetesContainers.Namespace" = "#{Kubernetes.Deployment.Namespace}"
      }
      environments          = []
      excluded_environments = []
      channels              = []
      tenant_tags           = []
      features              = []
    }

    properties   = {}
    target_roles = ["k8s"]
  }
}

resource "octopusdeploy_runbook" "runbook_k8s_pod_logs" {
  name              = "Pod Logs"
  project_id        = octopusdeploy_project.project_k8s_microservice.id
  environment_scope = "Specified"
  environments      = [
    data.octopusdeploy_environments.development.environments[0].id,
    data.octopusdeploy_environments.test.environments[0].id,
    data.octopusdeploy_environments.production.environments[0].id
  ]
  force_package_download      = false
  default_guided_failure_mode = "EnvironmentDefault"
  description                 = "Gets the pod logs in the namespace representing an environment. This runbook is safe to run at any time."
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

resource "octopusdeploy_runbook" "create_incident_channel" {
  name                        = "Create Incident Channel"
  project_id                  = octopusdeploy_project.project_k8s_microservice.id
  environment_scope           = "Specified"
  environments                = [data.octopusdeploy_environments.production.environments[0].id]
  force_package_download      = false
  default_guided_failure_mode = "EnvironmentDefault"
  description                 = "Create an incident channel to support production issues with this app."
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

resource "octopusdeploy_runbook_process" "create_incident_channel" {
  runbook_id = octopusdeploy_runbook.create_incident_channel.id

  step {
    condition           = "Success"
    name                = "Create Incident Channel"
    package_requirement = "LetOctopusDecide"
    start_trigger       = "StartAfterPrevious"

    action {

      action_type                        = "Octopus.Script"
      name                               = "Create Incident Channel"
      condition                          = "Success"
      run_on_server                      = true
      is_disabled                        = false
      can_be_used_for_project_versioning = false
      is_required                        = true
      worker_pool_id                     = data.octopusdeploy_worker_pools.workerpool_default.worker_pools[0].id
      properties                         = {
        "Octopus.Action.Script.ScriptSource" = "Inline"
        "Octopus.Action.Script.ScriptBody"   = file("../../scripts/create_channel.py")
        "Octopus.Action.Script.Syntax"       = "Python"
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

resource "octopusdeploy_runbook" "runbook_k8s_microservice_template_scan_pod_logs_for_errors" {
  name                        = "Scan Pod Logs for Errors"
  project_id                  = octopusdeploy_project.project_k8s_microservice.id
  environment_scope           = "Specified"
  environments      = [
    data.octopusdeploy_environments.development.environments[0].id,
    data.octopusdeploy_environments.test.environments[0].id,
    data.octopusdeploy_environments.production.environments[0].id
  ]
  force_package_download      = false
  default_guided_failure_mode = "EnvironmentDefault"
  description                 = "Downloads the pod logs and runs them through a script that scans for known issues. This runbook is safe to run at any time."
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

resource "octopusdeploy_runbook_process" "runbook_process_k8s_microservice_template_scan_pod_logs_for_errors" {
  runbook_id = octopusdeploy_runbook.runbook_k8s_microservice_template_scan_pod_logs_for_errors.id

  step {
    condition           = "Success"
    name                = "Scan Log Files"
    package_requirement = "LetOctopusDecide"
    start_trigger       = "StartAfterPrevious"

    action {
      action_type                        = "Octopus.KubernetesRunScript"
      name                               = "Scan Log Files"
      condition                          = "Success"
      run_on_server                      = true
      is_disabled                        = false
      can_be_used_for_project_versioning = true
      is_required                        = false
      worker_pool_id                     = ""
      properties                         = {
        "Octopus.Action.Script.ScriptSource"            = "Inline"
        "Octopus.Action.Script.Syntax"                  = "Bash"
        "Octopus.Action.KubernetesContainers.Namespace" = "#{Kubernetes.Deployment.Namespace}"
        "Octopus.Action.Script.ScriptBody"              = "cd octopub-log-scanner\nPODS=$(kubectl get pods -o json | jq -r '.items[] | .metadata.name')\n\nif [[ -z \"$PODS\" ]]\nthen\n\techo \"No pods found\"\n    exit 0\nfi\n\nfor pod in $PODS\ndo\n\tkubectl logs $pod \u003e $pod.txt\n\techo \"--------------\"\n\tpython3 octopub-log-scanner.py $pod.txt\ndone"
      }
      environments          = []
      excluded_environments = []
      channels              = []
      tenant_tags           = []

      package {
        name                      = "octopub-log-scanner"
        package_id                = "com.octopus:octopub-log-scanner"
        acquisition_location      = "Server"
        extract_during_deployment = false
        feed_id                   = data.octopusdeploy_feeds.maven.feeds[0].id
        properties                = { Extract = "True", Purpose = "", SelectionMode = "immediate" }
      }
      features = []
    }

    properties   = {}
    target_roles = ["k8s"]
  }
}