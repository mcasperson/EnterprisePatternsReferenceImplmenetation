terraform {
  required_providers {
    octopusdeploy = { source = "OctopusDeployLabs/octopusdeploy", version = "0.12.0" }
  }
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


variable "runbook_backend_service_deploy_project_name" {
  type        = string
  nullable    = false
  sensitive   = false
  description = "The name of the project exported from Deploy Project"
  default     = "2. Deploy Project"
}

resource "octopusdeploy_runbook" "runbook_backend_service_deploy_project" {
  name                        = "${var.runbook_backend_service_deploy_project_name}"
  project_id                  = "${data.octopusdeploy_projects.project.projects[0].id}"
  environment_scope           = "All"
  environments                = [data.octopusdeploy_environments.sync.environments[0].id]
  force_package_download      = false
  default_guided_failure_mode = "EnvironmentDefault"
  description                 = "This project deploys the package created by the Serialize Project runbook. Typically you do not run this runbook manually, as it is triggered by the Serialize Project runbook."
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

resource "octopusdeploy_runbook_process" "runbook_process_backend_service_serialize_project" {
  runbook_id = "${octopusdeploy_runbook.runbook_backend_service_serialize_project.id}"

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
      worker_pool_id                     = "${data.octopusdeploy_worker_pools.workerpool_default.worker_pools[0].id}"
      properties                         = {
        "Octopus.Action.Script.Syntax"       = "Bash"
        "Octopus.Action.Script.ScriptBody"   = file("../../shared_scripts/serialize_project.sh")
        "Octopus.Action.Script.ScriptSource" = "Inline"
      }
      environments          = []
      excluded_environments = []
      channels              = []
      tenant_tags           = []

      package {
        name                      = "OctopusTools"
        package_id                = "OctopusTools"
        acquisition_location      = "Server"
        extract_during_deployment = false
        feed_id                   = "${data.octopusdeploy_feeds.feed_octopus_server__built_in_.feeds[0].id}"
        properties                = { Extract = "True", Purpose = "", SelectionMode = "immediate" }
      }
      features = []
    }

    properties   = {}
    target_roles = []
  }
  step {
    condition           = "Success"
    name                = "Run Octopus Deploy Runbook"
    package_requirement = "LetOctopusDecide"
    start_trigger       = "StartAfterPrevious"

    action {
      action_type                        = "Octopus.Script"
      name                               = "Run Octopus Deploy Runbook"
      condition                          = "Success"
      run_on_server                      = true
      is_disabled                        = false
      can_be_used_for_project_versioning = false
      is_required                        = false
      worker_pool_id                     = "${data.octopusdeploy_worker_pools.workerpool_default.worker_pools[0].id}"
      properties                         = {
        "Run.Runbook.Space.Name"                          = "#{Octopus.Space.Name}"
        "Run.Runbook.Name"                                = "Deploy project"
        "Run.Runbook.DateTime"                            = "N/A"
        "Run.Runbook.ManualIntervention.EnvironmentToUse" = "#{Octopus.Environment.Name}"
        "Run.Runbook.Environment.Name"                    = "#{Octopus.Environment.Name}"
        "Octopus.Action.Script.Syntax"                    = "PowerShell"
        "Run.Runbook.Machines"                            = "N/A"
        "Run.Runbook.Base.Url"                            = "#{Octopus.Web.ServerUri}"
        "Run.Runbook.AutoApproveManualInterventions"      = "No"
        "Run.Runbook.CancelInSeconds"                     = "1800"
        "Octopus.Action.Script.ScriptBody"                = "[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12\n\n# Octopus Variables\n$octopusSpaceId = $OctopusParameters[\"Octopus.Space.Id\"]\n$parentTaskId = $OctopusParameters[\"Octopus.Task.Id\"]\n$parentReleaseId = $OctopusParameters[\"Octopus.Release.Id\"]\n$parentChannelId = $OctopusParameters[\"Octopus.Release.Channel.Id\"]\n$parentEnvironmentId = $OctopusParameters[\"Octopus.Environment.Id\"]\n$parentRunbookId = $OctopusParameters[\"Octopus.Runbook.Id\"]\n$parentEnvironmentName = $OctopusParameters[\"Octopus.Environment.Name\"]\n$parentReleaseNumber = $OctopusParameters[\"Octopus.Release.Number\"]\n\n# Step Template Parameters\n$runbookRunName = $OctopusParameters[\"Run.Runbook.Name\"]\n$runbookBaseUrl = $OctopusParameters[\"Run.Runbook.Base.Url\"]\n$runbookApiKey = $OctopusParameters[\"Run.Runbook.Api.Key\"]\n$runbookEnvironmentName = $OctopusParameters[\"Run.Runbook.Environment.Name\"]\n$runbookTenantName = $OctopusParameters[\"Run.Runbook.Tenant.Name\"]\n$runbookWaitForFinish = $OctopusParameters[\"Run.Runbook.Waitforfinish\"]\n$runbookUseGuidedFailure = $OctopusParameters[\"Run.Runbook.UseGuidedFailure\"]\n$runbookUsePublishedSnapshot = $OctopusParameters[\"Run.Runbook.UsePublishedSnapShot\"]\n$runbookPromptedVariables = $OctopusParameters[\"Run.Runbook.PromptedVariables\"]\n$runbookCancelInSeconds = $OctopusParameters[\"Run.Runbook.CancelInSeconds\"]\n$runbookProjectName = $OctopusParameters[\"Run.Runbook.Project.Name\"]\n\n$runbookSpaceName = $OctopusParameters[\"Run.Runbook.Space.Name\"]\n$runbookFutureDeploymentDate = $OctopusParameters[\"Run.Runbook.DateTime\"]\n$runbookMachines = $OctopusParameters[\"Run.Runbook.Machines\"]\n$autoApproveRunbookRunManualInterventions = $OctopusParameters[\"Run.Runbook.AutoApproveManualInterventions\"]\n$approvalEnvironmentName = $OctopusParameters[\"Run.Runbook.ManualIntervention.EnvironmentToUse\"]\n\nfunction Write-OctopusVerbose\n{\n    param($message)\n    \n    Write-Verbose $message  \n}\n\nfunction Write-OctopusInformation\n{\n    param($message)\n    \n    Write-Host $message  \n}\n\nfunction Write-OctopusSuccess\n{\n    param($message)\n\n    Write-Highlight $message \n}\n\nfunction Write-OctopusWarning\n{\n    param($message)\n\n    Write-Warning \"$message\" \n}\n\nfunction Write-OctopusCritical\n{\n    param ($message)\n\n    Write-Error \"$message\" \n}\n\nfunction Invoke-OctopusApi\n{\n    param\n    (\n        $octopusUrl,\n        $endPoint,\n        $spaceId,\n        $apiKey,\n        $method,\n        $item     \n    )\n\n    if ([string]::IsNullOrWhiteSpace($SpaceId))\n    {\n        $url = \"$OctopusUrl/api/$EndPoint\"\n    }\n    else\n    {\n        $url = \"$OctopusUrl/api/$spaceId/$EndPoint\"    \n    }  \n\n    try\n    {\n        if ($null -eq $item)\n        {\n            Write-Verbose \"No data to post or put, calling bog standard invoke-restmethod for $url\"\n            return Invoke-RestMethod -Method $method -Uri $url -Headers @{\"X-Octopus-ApiKey\" = \"$ApiKey\" } -ContentType 'application/json; charset=utf-8'\n        }\n\n        $body = $item | ConvertTo-Json -Depth 10\n        Write-Verbose $body\n\n        Write-Host \"Invoking $method $url\"\n        return Invoke-RestMethod -Method $method -Uri $url -Headers @{\"X-Octopus-ApiKey\" = \"$ApiKey\" } -Body $body -ContentType 'application/json; charset=utf-8'\n    }\n    catch\n    {\n        if ($null -ne $_.Exception.Response)\n        {\n            if ($_.Exception.Response.StatusCode -eq 401)\n            {\n                Write-Error \"Unauthorized error returned from $url, please verify API key and try again\"\n            }\n            elseif ($_.Exception.Response.statusCode -eq 403)\n            {\n                Write-Error \"Forbidden error returned from $url, please verify API key and try again\"\n            }\n            else\n            {                \n                Write-Error -Message \"Error calling $url $($_.Exception.Message) StatusCode: $($_.Exception.Response.StatusCode )\"\n            }            \n        }\n        else\n        {\n            Write-Verbose $_.Exception\n        }\n    }\n\n    Throw \"There was an error calling the Octopus API please check the log for more details\"\n}\n\nfunction Test-RequiredValues\n{\n\tparam (\n    \t$variableToCheck,\n        $variableName\n    )\n    \n    if ([string]::IsNullOrWhiteSpace($variableToCheck) -eq $true)\n    {\n    \tWrite-OctopusCritical \"$variableName is required.\"\n        return $false\n    }\n    \n    return $true\n}\n\nfunction GetCheckBoxBoolean\n{\n\tparam (\n    \t[string]$Value\n    )\n    \n    if ([string]::IsNullOrWhiteSpace($value) -eq $true)\n    {\n    \treturn $false\n    }\n    \n    return $value -eq \"True\"\n}\n\nfunction Get-FilteredOctopusItem\n{\n    param(\n        $itemList,\n        $itemName\n    )\n\n    if ($itemList.Items.Count -eq 0)\n    {\n        Write-OctopusCritical \"Unable to find $itemName.  Exiting with an exit code of 1.\"\n        Exit 1\n    }  \n\n    $item = $itemList.Items | Where-Object { $_.Name -eq $itemName}      \n\n    if ($null -eq $item)\n    {\n        Write-OctopusCritical \"Unable to find $itemName.  Exiting with an exit code of 1.\"\n        exit 1\n    }\n    \n    if ($item -is [array])\n    {\n    \tWrite-OctopusCritical \"More than one item exists with the name $itemName.  Exiting with an exit code of 1.\"\n        exit 1\n    }\n\n    return $item\n}\n\nfunction Get-OctopusItemFromListEndpoint\n{\n    param(\n        $endpoint,\n        $itemNameToFind,\n        $itemType,\n        $defaultUrl,\n        $octopusApiKey,\n        $spaceId,\n        $defaultValue\n    )\n    \n    if ([string]::IsNullOrWhiteSpace($itemNameToFind))\n    {\n    \treturn $defaultValue\n    }\n    \n    Write-OctopusInformation \"Attempting to find $itemType with the name of $itemNameToFind\"\n    \n    $itemList = Invoke-OctopusApi -octopusUrl $DefaultUrl -endPoint \"$($endpoint)?partialName=$([uri]::EscapeDataString($itemNameToFind))\u0026skip=0\u0026take=100\" -spaceId $spaceId -apiKey $octopusApiKey -method \"GET\"    \n    $item = Get-FilteredOctopusItem -itemList $itemList -itemName $itemNameToFind\n\n    Write-OctopusInformation \"Successfully found $itemNameToFind with id of $($item.Id)\"\n\n    return $item\n}\n\nfunction Get-MachineIdsFromMachineNames\n{\n    param (\n        $targetMachines,\n        $defaultUrl,\n        $spaceId,\n        $octopusApiKey\n    )\n\n    $targetMachineList = $targetMachines -split \",\"\n    $translatedList = @()\n\n    foreach ($machineName in $targetMachineList)\n    {\n        Write-OctopusVerbose \"Translating $machineName to an Id.  First checking to see if it is already an Id.\"\n    \tif ($machineName.Trim() -like \"Machines*\")\n        {\n            Write-OctopusVerbose \"$machineName is already an Id, no need to look that up.\"\n        \t$translatedList += $machineName\n            continue\n        }\n        \n        $machineObject = Get-OctopusItemFromListEndpoint -itemNameToFind $machineName.Trim() -itemType \"Deployment Target\" -endpoint \"machines\" -defaultValue $null -spaceId $spaceId -defaultUrl $defaultUrl -octopusApiKey $octopusApiKey\n\n        $translatedList += $machineObject.Id\n    }\n\n    return $translatedList\n}\n\nfunction Get-RunbookSnapshotIdToRun\n{\n    param (\n        $runbookToRun,\n        $runbookUsePublishedSnapshot,\n        $defaultUrl,\n        $octopusApiKey,\n        $spaceId\n    )\n\n    $runbookSnapShotIdToUse = $runbookToRun.PublishedRunbookSnapshotId\n    Write-OctopusInformation \"The last published snapshot for $runbookRunName is $runbookSnapShotIdToUse\"\n\n    if ($null -eq $runbookSnapShotIdToUse -and $runbookUsePublishedSnapshot -eq $true)\n    {\n        Write-OctopusCritical \"Use Published Snapshot was set; yet the runbook doesn't have a published snapshot.  Exiting.\"\n        Exit 1\n    }\n\n    if ($runbookUsePublishedSnapshot -eq $true)\n    {\n        Write-OctopusInformation \"Use published snapshot set to true, using the published runbook snapshot.\"\n        return $runbookSnapShotIdToUse\n    }\n\n    if ($null -eq $runbookToRun.PublishedRunbookSnapshotId)\n    {\n        Write-OctopusInformation \"There have been no published runbook snapshots, going to create a new snapshot.\"\n        return New-RunbookUnpublishedSnapshot -runbookToRun $runbookToRun -defaultUrl $defaultUrl -octopusApiKey $octopusApiKey -spaceId $spaceId\n    }\n\n    $runbookSnapShotTemplate = Invoke-OctopusApi -octopusUrl $defaultUrl -apiKey $octopusApiKey -spaceId $spaceId -endPoint \"runbookSnapshots/$($runbookToRun.PublishedRunbookSnapshotId)/runbookRuns/template\" -method \"Get\" -item $null\n\n    if ($runbookSnapShotTemplate.IsRunbookProcessModified -eq $false -and $runbookSnapShotTemplate.IsVariableSetModified -eq $false -and $runbookSnapShotTemplate.IsLibraryVariableSetModified -eq $false)\n    {        \n        Write-OctopusInformation \"The runbook has not been modified since the published snapshot was created.  Checking to see if any of the packages have a new version.\"    \n        $runbookSnapShot = Invoke-OctopusApi -octopusUrl $defaultUrl -apiKey $octopusApiKey -spaceId $spaceId -endPoint \"runbookSnapshots/$($runbookToRun.PublishedRunbookSnapshotId)\" -method \"Get\" -item $null\n        $snapshotTemplate = Invoke-OctopusApi -octopusUrl $defaultUrl -apiKey $octopusApiKey -spaceId $spaceId -endPoint \"runbooks/$($runbookToRun.Id)/runbookSnapShotTemplate\" -method \"Get\" -item $null\n\n        foreach ($package in $runbookSnapShot.SelectedPackages)\n        {\n            foreach ($templatePackage in $snapshotTemplate.Packages)\n            {\n                if ($package.StepName -eq $templatePackage.StepName -and $package.ActionName -eq $templatePackage.ActionName -and $package.PackageReferenceName -eq $templatePackage.PackageReferenceName)\n                {\n                    $packageVersion = Invoke-OctopusApi -octopusUrl $defaultUrl -apiKey $octopusApiKey -spaceId $spaceId -endPoint \"feeds/$($templatePackage.FeedId)/packages/versions?packageId=$($templatePackage.PackageId)\u0026take=1\" -method \"Get\" -item $null\n\n                    if ($packageVersion -ne $package.Version)\n                    {\n                        Write-OctopusInformation \"A newer version of a package was found, going to use that and create a new snapshot.\"\n                        return New-RunbookUnpublishedSnapshot -runbookToRun $runbookToRun -defaultUrl $defaultUrl -octopusApiKey $octopusApiKey -spaceId $spaceId                    \n                    }\n                }\n            }\n        }\n\n        Write-OctopusInformation \"No new package versions have been found, using the published snapshot.\"\n        return $runbookToRun.PublishedRunbookSnapshotId\n    }\n    \n    Write-OctopusInformation \"The runbook has been modified since the snapshot was created, creating a new one.\"\n    return New-RunbookUnpublishedSnapshot -runbookToRun $runbookToRun -defaultUrl $defaultUrl -octopusApiKey $octopusApiKey -spaceId $spaceId\n}\n\nfunction New-RunbookUnpublishedSnapshot\n{\n    param (\n        $runbookToRun,\n        $defaultUrl,\n        $octopusApiKey,\n        $spaceId\n    )\n\n    $octopusProject = Invoke-OctopusApi -octopusUrl $defaultUrl -apiKey $octopusApiKey -spaceId $spaceId -endPoint \"projects/$($runbookToRun.ProjectId)\" -method \"Get\" -item $null\n    $snapshotTemplate = Invoke-OctopusApi -octopusUrl $defaultUrl -apiKey $octopusApiKey -spaceId $spaceId -endPoint \"runbooks/$($runbookToRun.Id)/runbookSnapShotTemplate\" -method \"Get\" -item $null\n\n    $runbookPackages = @()\n    foreach ($package in $snapshotTemplate.Packages)\n    {\n        $packageVersion = Invoke-OctopusApi -octopusUrl $defaultUrl -apiKey $octopusApiKey -spaceId $spaceId -endPoint \"feeds/$($package.FeedId)/packages/versions?packageId=$($package.PackageId)\u0026take=1\" -method \"Get\" -item $null\n\n        if ($packageVersion.TotalResults -le 0)\n        {\n            Write-Error \"Unable to find a package version for $($package.PackageId).  This is required to create a new unpublished snapshot.  Exiting.\"\n            exit 1\n        }\n\n        $runbookPackages += @{\n            StepName = $package.StepName\n            ActionName = $package.ActionName\n            Version = $packageVersion.Items[0].Version\n            PackageReferenceName = $package.PackageReferenceName\n        }\n    }\n\n    $runbookSnapShotRequest = @{\n        FrozenProjectVariableSetId = \"variableset-$($runbookToRun.ProjectId)\"\n        FrozenRunbookProcessId = $($runbookToRun.RunbookProcessId)\n        LibraryVariableSetSnapshotIds = @($octopusProject.IncludedLibraryVariableSetIds)\n        Name = $($snapshotTemplate.NextNameIncrement)\n        ProjectId = $($runbookToRun.ProjectId)\n        ProjectVariableSetSnapshotId = \"variableset-$($runbookToRun.ProjectId)\"\n        RunbookId = $($runbookToRun.Id)\n        SelectedPackages = $runbookPackages\n    }\n\n    $newSnapShot = Invoke-OctopusApi -octopusUrl $defaultUrl -apiKey $octopusApiKey -spaceId $spaceId -endPoint \"runbookSnapshots\" -method \"POST\" -item $runbookSnapShotRequest\n\n    return $($newSnapShot.Id)\n}\n\nfunction Get-ProjectSlug\n{\n    param\n    (\n        $runbookToRun,\n        $projectToUse,\n        $defaultUrl,\n        $spaceId,\n        $octopusApiKey\n    )\n\n    if ($null -ne $projectToUse)\n    {\n        return $projectToUse.Slug\n    }\n\n    $project = Invoke-OctopusApi -octopusUrl $defaultUrl -spaceId $spaceId -apiKey $octopusApiKey -endPoint \"projects/$($runbookToRun.ProjectId)\" -method \"GET\" -item $null\n\n    return $project.Slug\n}\n\nfunction Get-RunbookFormValues\n{\n    param (\n        $runbookPreview,\n        $runbookPromptedVariables        \n    )\n\n    $runbookFormValues = @{}\n\n    if ([string]::IsNullOrWhiteSpace($runbookPromptedVariables) -eq $true)\n    {\n        return $runbookFormValues\n    }    \n    \n    $promptedValueList = @(($runbookPromptedVariables -Split \"`n\").Trim())\n    Write-OctopusInformation $promptedValueList.Length\n    \n    foreach($element in $runbookPreview.Form.Elements)\n    {\n    \t$nameToSearchFor = $element.Control.Name\n        $uniqueName = $element.Name\n        $isRequired = $element.Control.Required\n        \n        $promptedVariablefound = $false\n        \n        Write-OctopusInformation \"Looking for the prompted variable value for $nameToSearchFor\"\n    \tforeach ($promptedValue in $promptedValueList)\n        {\n        \t$splitValue = $promptedValue -Split \"::\"\n            Write-OctopusInformation \"Comparing $nameToSearchFor with provided prompted variable $($promptedValue[0])\"\n            if ($splitValue.Length -gt 1)\n            {\n            \tif ($nameToSearchFor -eq $splitValue[0])\n                {\n                \tWrite-OctopusInformation \"Found the prompted variable value $nameToSearchFor\"\n                \t$runbookFormValues[$uniqueName] = $splitValue[1]\n                    $promptedVariableFound = $true\n                    break\n                }\n            }\n        }\n        \n        if ($promptedVariableFound -eq $false -and $isRequired -eq $true)\n        {\n        \tWrite-OctopusCritical \"Unable to find a value for the required prompted variable $nameToSearchFor, exiting\"\n            Exit 1\n        }\n    }\n\n    return $runbookFormValues\n}\n\nfunction Invoke-OctopusDeployRunbook\n{\n    param (\n        $runbookBody,\n        $runbookWaitForFinish,\n        $runbookCancelInSeconds,\n        $projectNameForUrl,        \n        $defaultUrl,\n        $octopusApiKey,\n        $spaceId,\n        $parentTaskApprovers,\n        $autoApproveRunbookRunManualInterventions,\n        $parentProjectName,\n        $parentReleaseNumber,\n        $approvalEnvironmentName,\n        $parentRunbookId,\n        $parentTaskId\n    )\n\n    $runbookResponse = Invoke-OctopusApi -octopusUrl $defaultUrl -spaceId $spaceId -apiKey $octopusApiKey -item $runbookBody -method \"POST\" -endPoint \"runbookRuns\"\n\n    $runbookServerTaskId = $runBookResponse.TaskId\n    Write-OctopusInformation \"The task id of the new task is $runbookServerTaskId\"\n\n    $runbookRunId = $runbookResponse.Id\n    Write-OctopusInformation \"The runbook run id is $runbookRunId\"\n\n    Write-OctopusSuccess \"Runbook was successfully invoked, you can access the launched runbook [here]($defaultUrl/app#/$spaceId/projects/$projectNameForUrl/operations/runbooks/$($runbookBody.RunbookId)/snapshots/$($runbookBody.RunbookSnapShotId)/runs/$runbookRunId)\"\n\n    if ($runbookWaitForFinish -eq $false)\n    {\n        Write-OctopusInformation \"The wait for finish setting is set to no, exiting step\"\n        return\n    }\n    \n    if ($null -ne $runbookBody.QueueTime)\n    {\n    \tWrite-OctopusInformation \"The runbook queue time is set.  Exiting step\"\n        return\n    }\n\n    Write-OctopusSuccess \"The setting to wait for completion was set, waiting until task has finished\"\n    $startTime = Get-Date\n    $currentTime = Get-Date\n    $dateDifference = $currentTime - $startTime\n\t\n    $taskStatusUrl = \"tasks/$runbookServerTaskId\"\n    $numberOfWaits = 0    \n    \n    While ($dateDifference.TotalSeconds -lt $runbookCancelInSeconds)\n    {\n        Write-OctopusInformation \"Waiting 5 seconds to check status\"\n        Start-Sleep -Seconds 5\n        $taskStatusResponse = Invoke-OctopusApi -octopusUrl $defaultUrl -spaceId $spaceId -apiKey $octopusApiKey -endPoint $taskStatusUrl -method \"GET\" -item $null\n        $taskStatusResponseState = $taskStatusResponse.State\n\n        if ($taskStatusResponseState -eq \"Success\")\n        {\n            Write-OctopusSuccess \"The task has finished with a status of Success\"\n            exit 0            \n        }\n        elseif($taskStatusResponseState -eq \"Failed\" -or $taskStatusResponseState -eq \"Canceled\")\n        {\n            Write-OctopusSuccess \"The task has finished with a status of $taskStatusResponseState status, stopping the run/deployment\"\n            exit 1            \n        }\n        elseif($taskStatusResponse.HasPendingInterruptions -eq $true)\n        {\n            if ($autoApproveRunbookRunManualInterventions -eq \"Yes\")\n            {\n                Submit-RunbookRunForAutoApproval -createdRunbookRun $createdRunbookRun -parentTaskApprovers $parentTaskApprovers -defaultUrl $DefaultUrl -octopusApiKey $octopusApiKey -spaceId $spaceId -parentProjectName $parentProjectName -parentReleaseNumber $parentReleaseNumber -parentEnvironmentName $approvalEnvironmentName -parentRunbookId $parentRunbookId -parentTaskId $parentTaskId\n            }\n            else\n            {\n                if ($numberOfWaits -ge 10)\n                {\n                    Write-OctopusSuccess \"The child project has pending manual intervention(s).  Unless you approve it, this task will time out.\"\n                }\n                else\n                {\n                    Write-OctopusInformation \"The child project has pending manual intervention(s).  Unless you approve it, this task will time out.\"                        \n                }\n            }\n        }\n        \n        $numberOfWaits += 1\n        if ($numberOfWaits -ge 10)\n        {\n        \tWrite-OctopusSuccess \"The task state is currently $taskStatusResponseState\"\n        \t$numberOfWaits = 0\n        }\n        else\n        {\n        \tWrite-OctopusInformation \"The task state is currently $taskStatusResponseState\"\n        }  \n        \n        $startTime = $taskStatusResponse.StartTime\n        if ($startTime -eq $null -or [string]::IsNullOrWhiteSpace($startTime) -eq $true)\n        {        \n        \tWrite-OctopusInformation \"The task is still queued, let's wait a bit longer\"\n        \t$startTime = Get-Date\n        }\n        $startTime = [DateTime]$startTime\n        \n        $currentTime = Get-Date\n        $dateDifference = $currentTime - $startTime        \n    }\n    \n    Write-OctopusSuccess \"The cancel timeout has been reached, cancelling the runbook run\"\n    $cancelResponse = Invoke-RestMethod \"$runbookBaseUrl/api/tasks/$runbookServerTaskId/cancel\" -Headers $header -Method Post\n    Write-OctopusSuccess \"Exiting with an error code of 1 because we reached the timeout\"\n    exit 1\n}\n\nfunction Get-QueueDate\n{\n\tparam ( \n    \t$futureDeploymentDate\n    )\n    \n    if ([string]::IsNullOrWhiteSpace($futureDeploymentDate) -or $futureDeploymentDate -eq \"N/A\")\n    {\n    \treturn $null\n    }\n    \n    $addOneDay = $false\n    $textToParse = $futureDeploymentDate.ToLower()\n    if ($textToParse -like \"tomorrow*\")\n    {\n    \tWrite-Host \"The future date $futureDeploymentDate supplied contains tomorrow, will add one day to whatever the parsed result is.\"\n    \t$addOneDay = $true\n        $textToParse = $textToParse -replace \"tomorrow\", \"\"\n    }\n    \n    [datetime]$outputDate = New-Object DateTime\n    $currentDate = Get-Date\n    $currentDate = $currentDate.AddMinutes(2)\n\n    if ([datetime]::TryParse($textToParse, [ref]$outputDate) -eq $false)\n    {\n        Write-OctopusCritical \"The suppplied date $textToParse cannot be parsed by DateTime.TryParse.  Please verify format and try again.  Please [refer to Microsoft's Documentation](https://docs.microsoft.com/en-us/dotnet/api/system.datetime.tryparse) on supported formats.\"\n        exit 1\n    }\n    \n    Write-Host \"The proposed date is $outputDate.  Checking to see if this will occur in the past.\"\n    \n    if ($addOneDay -eq $true)\n    {\n    \t$outputDate = $outputDate.AddDays(1)\n    \tWrite-host \"The text supplied included tomorrow, adding one day.  The new proposed date is $outputDate.\"\n    }\n    \n    if ($currentDate -gt $outputDate)\n    {\n    \tWrite-OctopusCritical \"The supplied date $futureDeploymentDate is set for the past.  All queued deployments must be in the future.\"\n        exit 1\n    }\n    \n    return $outputDate\n}\n\nfunction Get-QueueExpiryDate\n{\n\tparam (\n    \t$queueDate\n    )\n    \n    if ($null -eq $queueDate)\n    {\n    \treturn $null\n    }\n    \n    return $queueDate.AddHours(1)\n}\n\nfunction Get-RunbookSpecificMachines\n{\n    param (\n        $runbookPreview,\n        $runbookMachines,        \n        $runbookRunName        \n    )\n\n    if ($runbookMachines -eq \"N/A\")\n    {\n        return @()\n    }\n\n    if ([string]::IsNullOrWhiteSpace($runbookMachines) -eq $true)\n    {\n        return @()\n    }\n\n    $translatedList = Get-MachineIdsFromMachineNames -defaultUrl $defaultUrl -octopusApiKey $octopusApiKey -spaceId $spaceId -targetMachines $runbookMachines\n\n    $filteredList = @()    \n    foreach ($runbookMachine in $translatedList)\n    {    \t\n    \t$runbookMachineId = $runbookMachine.Trim().ToLower()\n    \tWrite-OctopusVerbose \"Checking if $runbookMachineId is set to run on any of the runbook steps\"\n        \n        foreach ($step in $runbookPreview.StepsToExecute)\n        {\n            foreach ($machine in $step.Machines)\n            {\n            \tWrite-OctopusVerbose \"Checking if $runbookMachineId matches $($machine.Id) and it isn't already in the $($filteredList -join \",\")\"\n                if ($runbookMachineId -eq $machine.Id.Trim().ToLower() -and $filteredList -notcontains $machine.Id)\n                {\n                \tWrite-OctopusInformation \"Adding $($machine.Id) to the list\"\n                    $filteredList += $machine.Id\n                }\n            }\n        }\n    }\n\n    if ($filteredList.Length -le 0)\n    {\n        Write-OctopusSuccess \"The current task is targeting specific machines, but the runbook $runBookRunName does not run against any of these machines $runbookMachines. Skipping this run.\"\n        exit 0\n    }\n\n    return $filteredList\n}\n\nfunction Get-ParentTaskApprovers\n{\n    param (\n        $parentTaskId,\n        $spaceId,\n        $defaultUrl,\n        $octopusApiKey\n    )\n    \n    $approverList = @()\n    if ($null -eq $parentTaskId)\n    {\n    \tWrite-OctopusInformation \"The deployment task id to pull the approvers from is null, return an empty approver list\"\n    \treturn $approverList\n    }\n\n    Write-OctopusInformation \"Getting all the events from the parent project\"\n    $parentEvents = Invoke-OctopusApi -octopusUrl $DefaultUrl -endPoint \"events?regardingAny=$parentTaskId\u0026spaces=$spaceId\u0026includeSystem=true\" -apiKey $octopusApiKey -method \"GET\"\n    \n    foreach ($parentEvent in $parentEvents.Items)\n    {\n        Write-OctopusVerbose \"Checking $($parentEvent.Message) for manual intervention\"\n        if ($parentEvent.Message -like \"Submitted interruption*\")\n        {\n            Write-OctopusVerbose \"The event $($parentEvent.Id) is a manual intervention approval event which was approved by $($parentEvent.Username).\"\n\n            $approverExists = $approverList | Where-Object {$_.Id -eq $parentEvent.UserId}        \n\n            if ($null -eq $approverExists)\n            {\n                $approverInformation = @{\n                    Id = $parentEvent.UserId;\n                    Username = $parentEvent.Username;\n                    Teams = @()\n                }\n\n                $approverInformation.Teams = Invoke-OctopusApi -octopusUrl $DefaultUrl -endPoint \"teammembership?userId=$($approverInformation.Id)\u0026spaces=$spaceId\u0026includeSystem=true\" -apiKey $octopusApiKey -method \"GET\"            \n\n                Write-OctopusVerbose \"Adding $($approverInformation.Id) to the approval list\"\n                $approverList += $approverInformation\n            }        \n        }\n    }\n\n    return $approverList\n}\n\nfunction Get-ApprovalTaskIdFromDeployment\n{\n    param (\n        $parentReleaseId,\n        $approvalEnvironment,\n        $parentChannelId,    \n        $parentEnvironmentId,\n        $defaultUrl,\n        $spaceId,\n        $octopusApiKey \n    )\n\n    $releaseDeploymentList = Invoke-OctopusApi -octopusUrl $DefaultUrl -endPoint \"releases/$parentReleaseId/deployments\" -method \"GET\" -apiKey $octopusApiKey -spaceId $spaceId\n    \n    $lastDeploymentTime = $(Get-Date).AddYears(-50)\n    $approvalTaskId = $null\n    foreach ($deployment in $releaseDeploymentList.Items)\n    {\n        if ($deployment.EnvironmentId -ne $approvalEnvironment.Id)\n        {\n            Write-OctopusInformation \"The deployment $($deployment.Id) deployed to $($deployment.EnvironmentId) which doesn't match $($approvalEnvironment.Id).\"\n            continue\n        }\n        \n        Write-OctopusInformation \"The deployment $($deployment.Id) was deployed to the approval environment $($approvalEnvironment.Id).\"\n\n        $deploymentTask = Invoke-OctopusApi -octopusUrl $defaultUrl -spaceId $null -endPoint \"tasks/$($deployment.TaskId)\" -apiKey $octopusApiKey -Method \"Get\"\n        if ($deploymentTask.IsCompleted -eq $true -and $deploymentTask.FinishedSuccessfully -eq $false)\n        {\n            Write-Information \"The deployment $($deployment.Id) was deployed to the approval environment, but it encountered a failure, moving onto the next deployment.\"\n            continue\n        }\n\n        if ($deploymentTask.StartTime -gt $lastDeploymentTime)\n        {\n            $approvalTaskId = $deploymentTask.Id\n            $lastDeploymentTime = $deploymentTask.StartTime\n        }\n    }        \n\n    if ($null -eq $approvalTaskId)\n    {\n    \tWrite-OctopusVerbose \"Unable to find a deployment to the environment, determining if it should've happened already.\"\n        $channelInformation = Invoke-OctopusApi -octopusUrl $defaultUrl -endPoint \"channels/$parentChannelId\" -method \"GET\" -apiKey $octopusApiKey -spaceId $spaceId\n        $lifecycle = Get-OctopusLifeCycle -channel $channelInformation -defaultUrl $defaultUrl -spaceId $spaceId -OctopusApiKey $octopusApiKey\n        $lifecyclePhases = Get-LifecyclePhases -lifecycle $lifecycle -defaultUrl $defaultUrl -spaceId $spaceid -OctopusApiKey $octopusApiKey\n        \n        $foundDestinationFirst = $false\n        $foundApprovalFirst = $false\n        \n        foreach ($phase in $lifecyclePhases.Phases)\n        {\n        \tif ($phase.AutomaticDeploymentTargets -contains $parentEnvironmentId -or $phase.OptionalDeploymentTargets -contains $parentEnvironmentId)\n            {\n            \tif ($foundApprovalFirst -eq $false)\n                {\n                \t$foundDestinationFirst = $true\n                }\n            }\n            \n            if ($phase.AutomaticDeploymentTargets -contains $approvalEnvironment.Id -or $phase.OptionalDeploymentTargets -contains $approvalEnvironment.Id)\n            {\n            \tif ($foundDestinationFirst -eq $false)\n                {\n                \t$foundApprovalFirst = $true\n                }\n            }\n        }\n        \n        $messageToLog = \"Unable to find a deployment for the environment $approvalEnvironmentName.  Auto approvals are disabled.\"\n        if ($foundApprovalFirst -eq $true)\n        {\n        \tWrite-OctopusWarning $messageToLog\n        }\n        else\n        {\n        \tWrite-OctopusInformation $messageToLog\n        }\n        \n        return $null\n    }\n\n    return $approvalTaskId\n}\n\nfunction Get-ApprovalTaskIdFromRunbook\n{\n    param (\n        $parentRunbookId,\n        $approvalEnvironment,\n        $defaultUrl,\n        $spaceId,\n        $octopusApiKey \n    )\n}\n\nfunction Get-ApprovalTaskId\n{\n\tparam (\n    \t$autoApproveRunbookRunManualInterventions,\n        $parentTaskId,\n        $parentReleaseId,\n        $parentRunbookId,\n        $parentEnvironmentName,\n        $approvalEnvironmentName,\n        $parentChannelId,    \n        $parentEnvironmentId,\n        $defaultUrl,\n        $spaceId,\n        $octopusApiKey        \n    )\n    \n    if ($autoApproveRunbookRunManualInterventions -eq $false)\n    {\n    \tWrite-OctopusInformation \"Auto approvals are disabled, skipping pulling the approval deployment task id\"\n        return $null\n    }\n    \n    if ([string]::IsNullOrWhiteSpace($approvalEnvironmentName) -eq $true)\n    {\n    \tWrite-OctopusInformation \"Approval environment not supplied, using the current environment id for approvals.\"\n        return $parentTaskId\n    }\n    \n    if ($approvalEnvironmentName.ToLower().Trim() -eq $parentEnvironmentName.ToLower().Trim())\n    {\n        Write-OctopusInformation \"The approval environment is the same as the current environment, using the current task id $parentTaskId\"\n        return $parentTaskId\n    }\n    \n    $approvalEnvironment = Get-OctopusItemFromListEndpoint -itemNameToFind $approvalEnvironmentName -itemType \"Environment\" -defaultUrl $DefaultUrl -spaceId $spaceId -octopusApiKey $octopusApiKey -defaultValue $null -endpoint \"environments\"\n    \n    if ([string]::IsNullOrWhiteSpace($parentReleaseId) -eq $false)\n    {\n        return Get-ApprovalTaskIdFromDeployment -parentReleaseId $parentReleaseId -approvalEnvironment $approvalEnvironment -parentChannelId $parentChannelId -parentEnvironmentId $parentEnvironmentId -defaultUrl $defaultUrl -octopusApiKey $octopusApiKey -spaceId $spaceId\n    }\n\n    return Get-ApprovalTaskIdFromRunbook -parentRunbookId $parentRunbookId -approvalEnvironment $approvalEnvironment -defaultUrl $defaultUrl -spaceId $spaceId -octopusApiKey $octopusApiKey\n}\n\nfunction Get-OctopusLifecycle\n{\n    param (\n        $channel,        \n        $defaultUrl,\n        $spaceId,\n        $octopusApiKey\n    )\n\n    Write-OctopusInformation \"Attempting to find the lifecycle information $($channel.Name)\"\n    if ($null -eq $channel.LifecycleId)\n    {\n        $lifecycleName = \"Default Lifecycle\"\n        $lifecycleList = Invoke-OctopusApi -octopusUrl $DefaultUrl -endPoint \"lifecycles?partialName=$([uri]::EscapeDataString($lifecycleName))\u0026skip=0\u0026take=1\" -spaceId $spaceId -apiKey $octopusApiKey -method \"GET\"\n        $lifecycle = $lifecycleList.Items[0]\n    }\n    else\n    {\n        $lifecycle = Invoke-OctopusApi -octopusUrl $DefaultUrl -endPoint \"lifecycles/$($channel.LifecycleId)\" -spaceId $spaceId -apiKey $octopusApiKey -method \"GET\"\n    }\n\n    Write-Host \"Successfully found the lifecycle $($lifecycle.Name) to use for this channel.\"\n\n    return $lifecycle\n}\n\nfunction Get-LifecyclePhases\n{\n    param (\n        $lifecycle,        \n        $defaultUrl,\n        $spaceId,\n        $octopusApiKey\n    )\n\n    Write-OctopusInformation \"Attempting to find the phase in the lifecycle $($lifecycle.Name) with the environment $environmentName to find the previous phase.\"\n    if ($lifecycle.Phases.Count -eq 0)\n    {\n        Write-OctopusInformation \"The lifecycle $($lifecycle.Name) has no set phases, calling the preview endpoint.\"\n        $lifecyclePreview = Invoke-OctopusApi -octopusUrl $DefaultUrl -endPoint \"lifecycles/$($lifecycle.Id)/preview\" -spaceId $spaceId -apiKey $octopusApiKey -method \"GET\"\n        $phases = $lifecyclePreview.Phases\n    }\n    else\n    {\n        Write-OctopusInformation \"The lifecycle $($lifecycle.Name) has set phases, using those.\"\n        $phases = $lifecycle.Phases    \n    }\n\n    Write-OctopusInformation \"Found $($phases.Length) phases in this lifecycle.\"\n    return $phases\n}\n\nfunction Submit-RunbookRunForAutoApproval\n{\n    param (\n        $createdRunbookRun,\n        $parentTaskApprovers,\n        $defaultUrl,\n        $octopusApiKey,\n        $spaceId,\n        $parentProjectName,\n        $parentReleaseNumber,\n        $parentRunbookId,\n        $parentEnvironmentName,\n        $parentTaskId        \n    )\n\n    Write-OctopusSuccess \"The task has a pending manual intervention.  Checking parent approvals.\"    \n    $manualInterventionInformation = Invoke-OctopusApi -octopusUrl $DefaultUrl -endPoint \"interruptions?regarding=$($createdRunbookRun.TaskId)\" -method \"GET\" -apiKey $octopusApiKey -spaceId $spaceId\n    foreach ($manualIntervention in $manualInterventionInformation.Items)\n    {\n        if ($manualIntervention.IsPending -eq $false)\n        {\n            Write-OctopusInformation \"This manual intervention has already been approved.  Proceeding onto the next one.\"\n            continue\n        }\n\n        if ($manualIntervention.CanTakeResponsibility -eq $false)\n        {\n            Write-OctopusSuccess \"The user associated with the API key doesn't have permissions to take responsibility for the manual intervention.\"\n            Write-OctopusSuccess \"If you wish to leverage the auto-approval functionality give the user permissions.\"\n            continue\n        }        \n\n        $automaticApprover = $null\n        Write-OctopusVerbose \"Checking to see if one of the parent project approvers is assigned to one of the manual intervention teams $($manualIntervention.ResponsibleTeamIds)\"\n        foreach ($approver in $parentTaskApprovers)\n        {\n            foreach ($approverTeam in $approver.Teams)\n            {\n                Write-OctopusVerbose \"Checking to see if $($manualIntervention.ResponsibleTeamIds) contains $($approverTeam.TeamId)\"\n                if ($manualIntervention.ResponsibleTeamIds -contains $approverTeam.TeamId)\n                {\n                    $automaticApprover = $approver\n                    break\n                }\n            }\n\n            if ($null -ne $automaticApprover)\n            {\n                break\n            }\n        }\n\n        if ($null -ne $automaticApprover)\n        {\n        \tWrite-OctopusSuccess \"Matching approver found auto-approving.\"\n            if ($manualIntervention.HasResponsibility -eq $false)\n            {\n                Write-OctopusInformation \"Taking over responsibility for this manual intervention.\"\n                $takeResponsiblilityResponse = Invoke-OctopusApi -octopusUrl $DefaultUrl -endPoint \"interruptions/$($manualIntervention.Id)/responsible\" -method \"PUT\" -apiKey $octopusApiKey -spaceId $spaceId\n                Write-OctopusVerbose \"Response from taking responsibility $($takeResponsiblilityResponse.Id)\"\n            }\n            \n            if ([string]::IsNullOrWhiteSpace($parentReleaseNumber) -eq $false)\n            {\n                $notes = \"Auto-approving this runbook run.  Parent project $parentProjectName release $parentReleaseNumber to $parentEnvironmentName with the task id $parentTaskId was approved by $($automaticApprover.UserName).  That user is a member of one of the teams this manual intervention requires.  You can view that deployment $defaultUrl/app#/$spaceId/tasks/$parentTaskId\"\n            }\n            else \n            {\n                $notes = \"Auto-approving this runbook run.  Parent project $parentProjectName runbook run $parentRunbookId to $parentEnvironmentName with the task id $parentTaskId was approved by $($automaticApprover.UserName).  That user is a member of one of the teams this manual intervention requires.  You can view that runbook run $defaultUrl/app#/$spaceId/tasks/$parentTaskId\"\n            }\n\n            $submitApprovalBody = @{\n                Instructions = $null;\n                Notes = $notes\n                Result = \"Proceed\"\n            }\n            $submitResult = Invoke-OctopusApi -octopusUrl $DefaultUrl -endPoint \"interruptions/$($manualIntervention.Id)/submit\" -method \"POST\" -apiKey $octopusApiKey -item $submitApprovalBody -spaceId $spaceId\n            Write-OctopusSuccess \"Successfully auto approved the manual intervention $($submitResult.Id)\"\n        }\n        else\n        {\n            Write-OctopusSuccess \"Couldn't find an approver to auto-approve the child project.  Waiting until timeout or child project is approved.\"    \n        }\n    }\n}\n\n\n$runbookWaitForFinish = GetCheckboxBoolean -Value $runbookWaitForFinish\n$runbookUseGuidedFailure = GetCheckboxBoolean -Value $runbookUseGuidedFailure\n$runbookUsePublishedSnapshot = GetCheckboxBoolean -Value $runbookUsePublishedSnapshot\n$runbookCancelInSeconds = [int]$runbookCancelInSeconds\n\nWrite-OctopusInformation \"Wait for Finish Before Check: $runbookWaitForFinish\"\nWrite-OctopusInformation \"Use Guided Failure Before Check: $runbookUseGuidedFailure\"\nWrite-OctopusInformation \"Use Published Snapshot Before Check: $runbookUsePublishedSnapshot\"\nWrite-OctopusInformation \"Runbook Name $runbookRunName\"\nWrite-OctopusInformation \"Runbook Base Url: $runbookBaseUrl\"\nWrite-OctopusInformation \"Runbook Space Name: $runbookSpaceName\"\nWrite-OctopusInformation \"Runbook Environment Name: $runbookEnvironmentName\"\nWrite-OctopusInformation \"Runbook Tenant Name: $runbookTenantName\"\nWrite-OctopusInformation \"Wait for Finish: $runbookWaitForFinish\"\nWrite-OctopusInformation \"Use Guided Failure: $runbookUseGuidedFailure\"\nWrite-OctopusInformation \"Cancel run in seconds: $runbookCancelInSeconds\"\nWrite-OctopusInformation \"Use Published Snapshot: $runbookUsePublishedSnapshot\"\nWrite-OctopusInformation \"Auto Approve Runbook Run Manual Interventions: $autoApproveRunbookRunManualInterventions\"\nWrite-OctopusInformation \"Auto Approve environment name to pull approvals from: $approvalEnvironmentName\"\n\nWrite-OctopusInformation \"Octopus runbook run machines: $runbookMachines\"\nWrite-OctopusInformation \"Parent Task Id: $parentTaskId\"\nWrite-OctopusInformation \"Parent Release Id: $parentReleaseId\"\nWrite-OctopusInformation \"Parent Channel Id: $parentChannelId\"\nWrite-OctopusInformation \"Parent Environment Id: $parentEnvironmentId\"\nWrite-OctopusInformation \"Parent Runbook Id: $parentRunbookId\"\nWrite-OctopusInformation \"Parent Environment Name: $parentEnvironmentName\"\nWrite-OctopusInformation \"Parent Release Number: $parentReleaseNumber\"\n\n$verificationPassed = @()\n$verificationPassed += Test-RequiredValues -variableToCheck $runbookRunName -variableName \"Runbook Name\"\n$verificationPassed += Test-RequiredValues -variableToCheck $runbookBaseUrl -variableName \"Base Url\"\n$verificationPassed += Test-RequiredValues -variableToCheck $runbookApiKey -variableName \"Api Key\"\n$verificationPassed += Test-RequiredValues -variableToCheck $runbookEnvironmentName -variableName \"Environment Name\"\n\nif ($verificationPassed -contains $false)\n{\n\tWrite-OctopusInformation \"Required values missing\"\n\tExit 1\n}\n\n$runbookSpace = Get-OctopusItemFromListEndpoint -itemNameToFind $runbookSpaceName -endpoint \"spaces\" -spaceId $null -octopusApiKey $runbookApiKey -defaultUrl $runbookBaseUrl -itemType \"Space\" -defaultValue $octopusSpaceId\n$runbookSpaceId = $runbookSpace.Id\n\n$projectToUse = Get-OctopusItemFromListEndpoint -itemNameToFind $runbookProjectName -endpoint \"projects\" -spaceId $runbookSpaceId -defaultValue $null -itemType \"Project\" -octopusApiKey $runbookApiKey -defaultUrl $runbookBaseUrl\nif ($null -ne $projectToUse)\n{\t    \n    $runbookEndPoint = \"projects/$($projectToUse.Id)/runbooks\"\n}\nelse\n{\n\t$runbookEndPoint = \"runbooks\"\n}\n\n$environmentToUse = Get-OctopusItemFromListEndpoint -itemNameToFind $runbookEnvironmentName -itemType \"Environment\" -defaultUrl $runbookBaseUrl -spaceId $runbookSpaceId -octopusApiKey $runbookApiKey -defaultValue $null -endpoint \"environments\"\n\n$runbookToRun = Get-OctopusItemFromListEndpoint -itemNameToFind $runbookRunName -itemType \"Runbook\" -defaultUrl $runbookBaseUrl -spaceId $runbookSpaceId -endpoint $runbookEndPoint -octopusApiKey $runbookApiKey -defaultValue $null\n\n$runbookSnapShotIdToUse = Get-RunbookSnapshotIdToRun -runbookToRun $runbookToRun -runbookUsePublishedSnapshot $runbookUsePublishedSnapshot -defaultUrl $runbookBaseUrl -octopusApiKey $runbookApiKey -spaceId $octopusSpaceId\n$projectNameForUrl = Get-ProjectSlug -projectToUse $projectToUse -runbookToRun $runbookToRun -defaultUrl $runbookBaseUrl -octopusApiKey $runbookApiKey -spaceId $runbookSpaceId\n\n$tenantToUse = Get-OctopusItemFromListEndpoint -itemNameToFind $runbookTenantName -itemType \"Tenant\" -defaultValue $null -spaceId $runbookSpaceId -octopusApiKey $runbookApiKey -endpoint \"tenants\" -defaultUrl $runbookBaseUrl\nif ($null -ne $tenantToUse)\n{\t\n    $tenantIdToUse = $tenantToUse.Id  \n    $runBookPreview = Invoke-OctopusApi -octopusUrl $runbookBaseUrl -spaceId $runbookSpaceId -apiKey $runbookApiKey -endPoint \"runbooks/$($runbookToRun.Id)/runbookRuns/preview/$($environmentToUse.Id)/$($tenantIdToUse)\" -method \"GET\" -item $null\n}\nelse\n{\n\ttry\n    {\n    \tWrite-Host \"Trying the new preview step\"\n    \t$runBookPreview = Invoke-OctopusApi -octopusUrl $runbookBaseUrl -spaceId $runbookSpaceId -apiKey $runbookApiKey -endPoint \"runbookSnapshots/$($runbookSnapShotIdToUse)/runbookRuns/preview/$($environmentToUse.Id)?includeDisabledSteps=true\" -method \"GET\" -item $null\n    }\n    catch\n    {\n    \tWrite-Host \"The current version of Octopus Deploy doesn't support Runbook Snapshot Preview\"\n    \t$runBookPreview = Invoke-OctopusApi -octopusUrl $runbookBaseUrl -spaceId $runbookSpaceId -apiKey $runbookApiKey -endPoint \"runbooks/$($runbookToRun.Id)/runbookRuns/preview/$($environmentToUse.Id)\" -method \"GET\" -item $null\n   \t}\n}\n\n$childRunbookRunSpecificMachines = Get-RunbookSpecificMachines -runbookPreview $runBookPreview -runbookMachines $runbookMachines -runbookRunName $runbookRunName\n$runbookFormValues = Get-RunbookFormValues -runbookPreview $runBookPreview -runbookPromptedVariables $runbookPromptedVariables\n\n$queueDate = Get-QueueDate -futureDeploymentDate $runbookFutureDeploymentDate\n$queueExpiryDate = Get-QueueExpiryDate -queueDate $queueDate\n\n$runbookBody = @{\n    RunbookId = $($runbookToRun.Id);\n    RunbookSnapShotId = $runbookSnapShotIdToUse;\n    FrozenRunbookProcessId = $null;\n    EnvironmentId = $($environmentToUse.Id);\n    TenantId = $tenantIdToUse;\n    SkipActions = @();\n    QueueTime = $queueDate;\n    QueueTimeExpiry = $queueExpiryDate;\n    FormValues = $runbookFormValues;\n    ForcePackageDownload = $false;\n    ForcePackageRedeployment = $true;\n    UseGuidedFailure = $runbookUseGuidedFailure;\n    SpecificMachineIds = @($childRunbookRunSpecificMachines);\n    ExcludedMachineIds = @()\n}\n\n$approvalTaskId = Get-ApprovalTaskId -autoApproveRunbookRunManualInterventions $autoApproveRunbookRunManualInterventions -parentTaskId $parentTaskId -parentReleaseId $parentReleaseId -parentRunbookId $parentRunbookId -parentEnvironmentName $parentEnvironmentName -approvalEnvironmentName $approvalEnvironmentName -parentChannelId $parentChannelId -parentEnvironmentId $parentEnvironmentId -defaultUrl $runbookBaseUrl -spaceId $runbookSpaceId -octopusApiKey $runbookApiKey\n$parentTaskApprovers = Get-ParentTaskApprovers -parentTaskId $approvalTaskId -spaceId $runbookSpaceId -defaultUrl $runbookBaseUrl -octopusApiKey $runbookApiKey\n\nInvoke-OctopusDeployRunbook -runbookBody $runbookBody -runbookWaitForFinish $runbookWaitForFinish -runbookCancelInSeconds $runbookCancelInSeconds -projectNameForUrl $projectNameForUrl -defaultUrl $runbookBaseUrl -octopusApiKey $runbookApiKey -spaceId $runbookSpaceId -parentTaskApprovers $parentTaskApprovers -autoApproveRunbookRunManualInterventions $autoApproveRunbookRunManualInterventions -parentProjectName $projectNameForUrl -parentReleaseNumber $parentReleaseNumber -approvalEnvironmentName $approvalEnvironmentName -parentRunbookId $parentRunbookId -parentTaskId $approvalTaskId"
        "Run.Runbook.UsePublishedSnapShot"                = "False"
        "Run.Runbook.Waitforfinish"                       = "False"
        "Run.Runbook.Api.Key"                             = "#{ThisInstance.Api.Key}"
        "Run.Runbook.Project.Name"                        = "#{Octopus.Project.Name}"
        "Octopus.Action.Script.ScriptSource"              = "Inline"
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

variable "runbook_backend_service_serialize_project_name" {
  type        = string
  nullable    = false
  sensitive   = false
  description = "The name of the project exported from Serialize Project"
  default     = "1. Serialize Project"
}

resource "octopusdeploy_runbook" "runbook_backend_service_serialize_project" {
  name                        = "${var.runbook_backend_service_serialize_project_name}"
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
  runbook_id = "${octopusdeploy_runbook.runbook_backend_service_deploy_project.id}"

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
        "Octopus.Action.Script.ScriptBody"   = "docker exec terraformdb sh -c '/usr/bin/psql -v ON_ERROR_STOP=1 --username \"$POSTGRES_USER\" -c \"CREATE DATABASE project_hello_world_#{Octopus.Deployment.Tenant.Name | ToLower}\"'\nexit 0"
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
        "Octopus.Action.Terraform.GoogleCloudAccount"           = "False"
        "Octopus.Action.Terraform.TemplateDirectory"            = "space_population"
        "Octopus.Action.Terraform.AdditionalActionParams"       = "-var=\"octopus_server=http://localhost:18080\" -var=\"octopus_space_id=Spaces-2\" -var=\"octopus_apikey=#{ThisInstance.Api.Key}\""
        "Octopus.Action.Aws.AssumeRole"                         = "False"
        "Octopus.Action.Aws.Region"                             = ""
        "Octopus.Action.Terraform.AllowPluginDownloads"         = "True"
        "Octopus.Action.Terraform.AzureAccount"                 = "False"
        "Octopus.Action.AwsAccount.Variable"                    = ""
        "Octopus.Action.GoogleCloud.UseVMServiceAccount"        = "True"
        "Octopus.Action.Script.ScriptSource"                    = "Package"
        "Octopus.Action.Terraform.RunAutomaticFileSubstitution" = "False"
        "Octopus.Action.Terraform.AdditionalInitParams"         = "-backend-config=\"conn_str=postgres://terraform:terraform@localhost:15432/project_hello_world_#{Octopus.Deployment.Tenant.Name | ToLower}?sslmode=disable\""
        "Octopus.Action.GoogleCloud.ImpersonateServiceAccount"  = "False"
        "Octopus.Action.Terraform.PlanJsonOutput"               = "False"
        "Octopus.Action.Terraform.ManagedAccount"               = ""
        "OctopusUseBundledTooling"                              = "False"
        "Octopus.Action.AwsAccount.UseInstanceRole"             = "False"
        "Octopus.Action.Terraform.FileSubstitution"             = "**/project_variable_sensitive*.tf"
        "Octopus.Action.Package.DownloadOnTentacle"             = "False"
      }

      container {
        feed_id = "${data.octopusdeploy_feeds.feed_docker.feeds[0].id}"
        image   = "octopusdeploy/worker-tools:4.0.0-ubuntu.18.04"
      }

      environments          = []
      excluded_environments = []
      channels              = []
      tenant_tags           = []

      primary_package {
        package_id           = "Backend_Service"
        acquisition_location = "Server"
        feed_id              = "${data.octopusdeploy_feeds.feed_octopus_server__built_in_.feeds[0].id}"
        properties           = { SelectionMode = "immediate" }
      }

      features = []
    }

    properties   = {}
    target_roles = []
  }
}
