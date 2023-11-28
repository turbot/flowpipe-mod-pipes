pipeline "invite_org_member_by_email" {
  title       = "Invite Org Member by Email"
  description = "Invite member to an org by user email address."

  param "token" {
    type        = string
    description = local.token_param_description
    default     = var.token
  }

  param "org_handle" {
    type        = string
    description = "The handle of an organization where the member has to be invited."
  }

  param "email" {
    type        = string
    description = "The email of the user to be invited."
  }

  param "role" {
    type        = string
    description = "The role to be assigned to the member."
  }

  step "http" "invite_org_member_by_email" {
    method = "post"
    url    = "https://pipes.turbot.com/api/v0/org/${param.org_handle}/member/invite"

    insecure           = false
    request_timeout_ms = 2000

    request_headers = {
      Content-Type  = "application/json"
      Authorization = "Bearer ${param.token}"
    }

    request_body = jsonencode({
      role  = "${param.role}"
      email = "${param.email}"
    })
  }

  output "invitation_details" {
    value       = step.http.invite_org_member_by_email.response_body
    description = "The details of the invitation."
  }
}