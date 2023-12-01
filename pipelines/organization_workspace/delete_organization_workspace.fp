pipeline "delete_organization_workspace" {
  title       = "Delete Organization Workspace"
  description = "Deletes the workspace specified in the request."

  param "token" {
    type        = string
    description = local.token_param_description
    default     = var.token
  }

  param "organization_handle" {
    type        = string
    description = "The handle of the organization where the workspace exist."
  }

  param "workspace_handle" {
    type        = string
    description = "Provide the handle of the workspace which needs to be deleted."
  }

  step "http" "delete_organization_workspace" {
    method = "delete"
    url    = "https://pipes.turbot.com/api/v0/org/${param.organization_handle}/workspace/${param.workspace_handle}"

    request_headers = {
      Content-Type  = "application/json"
      Authorization = "Bearer ${param.token}"
    }
  }

  output "organization_workspace" {
    description = "The deleted workspace."
    value       = step.http.delete_organization_workspace.response_body
  }
}
