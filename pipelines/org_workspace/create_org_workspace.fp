pipeline "create_org_workspace" {
  title       = "Create Org Workspace"
  description = "Creates a new workspace for an organization."

  param "token" {
    type        = string
    description = local.token_param_description
    default     = var.token
  }

  param "org_handle" {
    type        = string
    description = "The handle of the organization where the workspace has to be created."
  }

  param "workspace_handle" {
    type        = string
    description = "The handle name of the workspace to be created."
  }

  param "instance_type" {
    type        = string
    description = "The type of the instance to be created."
  }

  step "http" "create_org_workspace" {
    method = "post"
    url    = "https://pipes.turbot.com/api/v0/org/${param.org_handle}/workspace"

    insecure           = false
    request_timeout_ms = 2000

    request_headers = {
      Content-Type  = "application/json"
      Authorization = "Bearer ${param.token}"
    }

    request_body = jsonencode({
      handle        = "${param.workspace_handle}"
      instance_type = "${param.instance_type}"
    })
  }

  output "org_workspace" {
    value       = step.http.create_org_workspace.response_body
    description = "The created workspace."
  }
}