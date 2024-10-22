pipeline "invite_organization_member_by_email" {
  title       = "Invite Organization Member by Email"
  description = "Invite member to an organization by user email address."

  param "conn" {
    type        = connection.pipes
    description = local.conn_param_description
    default     = connection.pipes.default
  }

  param "org_handle" {
    type        = string
    description = "Specify the handle of an organization where the member need to be invited."
  }

  param "email" {
    type        = string
    description = "The email of the user to be invited."
  }

  param "role" {
    type        = string
    description = "The role to be assigned to the member. Supported values are member and owner."
  }

  step "http" "invite_organization_member_by_email" {
    method = "post"
    url    = "https://pipes.turbot.com/api/v0/org/${param.org_handle}/member/invite"

    request_headers = {
      Content-Type  = "application/json"
      Authorization = "Bearer ${param.conn.token}"
    }

    request_body = jsonencode({
      for name, value in param : name => value if value != null
    })
  }

  output "invitation" {
    description = "The details of the invitation."
    value       = step.http.invite_organization_member_by_email.response_body
  }
}
