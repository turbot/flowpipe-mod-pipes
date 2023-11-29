pipeline "list_organization_workspace_members" {
  title       = "List Organization Workspace Members"
  description = "List members in an organization workspace."

  param "token" {
    type        = string
    description = local.token_param_description
    default     = var.token
  }

  param "organization_handle" {
    type        = string
    description = "The handle of the organization where the workspace has to be created."
  }

  param "workspace_handle" {
    type        = string
    description = "The handle name of the workspace to be created."
  }

  step "http" "list_organization_workspace_members" {
    method = "get"
    url    = "https://pipes.turbot.com/api/v0/org/${param.organization_handle}/workspace/${param.workspace_handle}/member"

    request_headers = {
      Content-Type  = "application/json"
      Authorization = "Bearer ${param.token}"
    }

    request_body = jsonencode({
      handle = param.workspace_handle
    })
  }

  output "members" {
    value       = step.http.list_organization_workspace_members
    description = "The list of members within an organization workspace."
  }
}
