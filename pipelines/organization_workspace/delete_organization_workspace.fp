pipeline "delete_organization_workspace" {
  title       = "Delete Organization Workspace"
  description = "Deletes the workspace specified in the request."

  param "cred" {
    type        = string
    description = local.cred_param_description
    default     = "default"
  }

  param "org_handle" {
    type        = string
    description = "The handle of the organization where the workspace exist."
  }

  param "workspace_handle" {
    type        = string
    description = "Provide the handle of the workspace which needs to be deleted."
  }

  step "http" "delete_organization_workspace" {
    method = "delete"
    url    = "https://pipes.turbot.com/api/v0/org/${param.org_handle}/workspace/${param.workspace_handle}"

    request_headers = {
      Content-Type  = "application/json"
      Authorization = "Bearer ${credential.pipes[param.cred].token}"
    }
  }

  output "organization_workspace" {
    description = "The deleted workspace."
    value       = step.http.delete_organization_workspace.response_body
  }
}
