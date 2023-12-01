pipeline "invite_organization_member_by_handle" {
  title       = "Invite Organization Member by Handle"
  description = "Invite member to an organization by user handle."

  param "token" {
    type        = string
    description = local.token_param_description
    default     = var.token
  }

  param "organization_handle" {
    type        = string
    description = "Specify the handle of an organization where the member need to be invited."
  }

  param "user_handle" {
    type        = string
    description = "The handle of the user to be invited."
  }

  param "role" {
    type        = string
    description = "The role to be assigned to the member."
  }

  step "http" "invite_organization_member_by_handle" {
    method = "post"
    url    = "https://pipes.turbot.com/api/v0/org/${param.organization_handle}/member/invite"

    request_headers = {
      Content-Type  = "application/json"
      Authorization = "Bearer ${param.token}"
    }

    request_body = jsonencode({
      handle = param.user_handle
      role   = param.role
    })
  }

  output "invitation" {
    description = "The details of the invitation."
    value       = step.http.invite_organization_member_by_handle.response_body
  }
}
