pipeline "list_organization_workspace_members" {
  title       = "List Organization Workspace Members"
  description = "List all members of a workspace in an organization who has accepted / invited."

  param "token" {
    type        = string
    description = local.token_param_description
    default     = var.token
  }

  param "organization_handle" {
    type        = string
    description = "Specify the handle of the organization where the member need to be invited."
  }

  param "workspace_handle" {
    type        = string
    description = "Specify the handle of the workspace where the member need to be invited."
  }

  step "http" "list_organization_workspace_members" {
    method = "get"
    url    = "https://pipes.turbot.com/api/v0/org/${param.organization_handle}/workspace/${param.workspace_handle}/member?limit=100"

    request_headers = {
      Content-Type  = "application/json"
      Authorization = "Bearer ${param.token}"
    }

    request_body = jsonencode({
      handle = param.workspace_handle
    })

    loop {
      until = result.response_body.next_token == null || result.response_body.next_token.length == 0
      url   = "https://pipes.turbot.com/api/v0/org/${param.organization_handle}/workspace/${param.workspace_handle}/member?limit=100&next_token=${result.response_body.next_token}"
    }
  }

  output "members" {
    value       = step.http.list_organization_workspace_members
    description = "The list of members within an organization workspace."
  }
}
