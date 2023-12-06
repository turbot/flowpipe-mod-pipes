pipeline "list_organization_workspace_members" {
  title       = "List Organization Workspace Members"
  description = "List all members of a workspace in an organization who has accepted / invited."

  param "cred" {
    type        = string
    description = local.cred_param_description
    default     = "default"
  }

  param "org_handle" {
    type        = string
    description = "Specify the handle of the organization where the member need to be invited."
  }

  param "workspace_handle" {
    type        = string
    description = "Specify the handle of the workspace where the member need to be invited."
  }

  step "http" "list_organization_workspace_members" {
    method = "get"
    url    = "https://pipes.turbot.com/api/v0/org/${param.org_handle}/workspace/${param.workspace_handle}/member?limit=100"

    request_headers = {
      Content-Type  = "application/json"
      Authorization = "Bearer ${credential.pipes[param.cred].token}"
    }

    request_body = jsonencode({
      for name, value in param : name => value if value != null
    })

    loop {
      until = lookup(result.response_body, "next_token", null) == null
      url   = "https://pipes.turbot.com/api/v0/org/${param.org_handle}/workspace/${param.workspace_handle}/member?limit=100&next_token=${result.response_body.next_token}"
    }
  }

  output "members" {
    description = "The list of members within an organization workspace."
    value       = flatten([for page, members in step.http.list_organization_workspace_members : members.response_body.items])
  }
}
