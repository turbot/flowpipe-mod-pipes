pipeline "create_organization_workspace_member" {
  title       = "Create Organization Workspace Member"
  description = "Add an individual as a member of a workspace in an organization."

  tags = {
    recommended = "true"
  }

  param "conn" {
    type        = connection.pipes
    description = local.conn_param_description
    default     = connection.pipes.default
  }

  param "org_handle" {
    type        = string
    description = "Specify the handle of the organization where the member need to be invited."
  }

  param "workspace_handle" {
    type        = string
    description = "Specify the handle of the workspace where the member need to be invited."
  }

  param "handle" {
    type        = string
    description = "The member's login handle to be part of workspace."
  }

  param "role" {
    type        = string
    description = "The workspace role name assigned to the member. It supports reader, operator and owner as role."
  }

  step "http" "create_organization_workspace_member" {
    method = "post"
    url    = "https://pipes.turbot.com/api/v0/org/${param.org_handle}/workspace/${param.workspace_handle}/member"

    request_headers = {
      Content-Type  = "application/json"
      Authorization = "Bearer ${param.conn.token}"
    }

    request_body = jsonencode({
      for name, value in param : name => value if value != null
    })
  }

  output "member" {
    value       = step.http.create_organization_workspace_member.response_body
    description = "The information about added members to the workspace."
  }
}
