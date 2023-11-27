pipeline "delete_org_workspace" {
  title       = "Delete Org Workspace"
  description = "Deletes the workspace specified in the request."

  param "token" {
    type        = string
    description = local.token_param_description
    default     = var.token
  }

  param "org_handle" {
    type        = string
    description = "The handle of the organization where the workspace exist."
  }

  param "workspace_handle" {
    type        = string
    description = "The handle of the workspace to be deleted."
  }


  step "http" "delete_org_workspace" {
    method = "delete"
    url    = "https://pipes.turbot.com/api/v0/org/${param.org_handle}/workspace/${param.workspace_handle}"

    insecure           = false
    request_timeout_ms = 2000

    request_headers = {
      Content-Type  = "application/json"
      Authorization = "Bearer ${param.token}"
    }
  }

  output "deleted_workspace" {
    value       = step.http.delete_org_workspace.response_body
    description = "The deleted workspace."
  }
}