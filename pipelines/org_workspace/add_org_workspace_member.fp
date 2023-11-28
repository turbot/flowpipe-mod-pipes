// Usage: fpr add_org_workspace_member --arg role="reader" --arg org_handle="<orgname>" --arg member_handle="<handle-name>" --arg workspace_handle="<workspace-name>"

pipeline "add_org_workspace_member" {
  title       = "Create Org Workspace Member"
  description = "Creates a new member for the workspace in the organization."

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
    description = "The  workspace handle name to be created."
  }

  param "member_handle" {
    type        = string
    description = "The member's login handle to be part of workspace."
  }

  param "role" {
    type        = string
    description = "The workspace role name assigned to the member. It supports reader, operator and owner as role."
  }

  step "http" "add_org_workspace_member" {
    method = "post"
    url    = "https://pipes.turbot.com/api/v0/org/${param.org_handle}/workspace/${param.workspace_handle}/member"

    insecure           = false
    request_timeout_ms = 2000

    request_headers = {
      Content-Type  = "application/json"
      Authorization = "Bearer ${param.token}"
    }

    request_body = jsonencode({
      handle = "${param.member_handle}"
      role   = "${param.role}"
    })
  }

  output "member" {
    value       = step.http.add_org_workspace_member.response_body
    description = "The information about added members to the workspace."
  }
}