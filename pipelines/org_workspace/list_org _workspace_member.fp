pipeline "list_org_workspace_member" {
  title       = "List Workspace Members of Organization"
  description = "List members in a workspace for an organization."

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

  step "http" "list_org_workspace_member" {
    method = "get"
    url    = "https://pipes.turbot.com/api/v0/org/${param.org_handle}/workspace/${param.workspace_handle}/member"

    insecure           = false
    request_timeout_ms = 2000

    request_headers = {
      Content-Type  = "application/json"
      Authorization = "Bearer ${param.token}"
    }

    request_body = jsonencode({
      handle = "${param.workspace_handle}"
    })

  }

  output "members" {
    value       = step.http.list_org_workspace_member
    description = "The list of workspace members within an organization."
  }
}