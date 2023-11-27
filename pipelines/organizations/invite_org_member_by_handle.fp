pipeline "invite_org_member_by_handle" {
  title       = "Invite Org Member by Handle"
  description = "Invite member to an org by user handle."

  param "token" {
    type        = string
    description = local.token_param_description
    default     = var.token
  }

  param "org_handle" {
    type        = string
    description = "The handle of an organization where the member has to be invited."
  }

  param "user_handle" {
    type        = string
    description = "The handle of the user to be invited."
  }

  param "role" {
    type        = string
    description = "The role to be assigned to the member."
  }

  step "http" "invite_org_member_by_handle" {
    method = "post"
    url    = "https://pipes.turbot.com/api/v0/org/${param.org_handle}/member/invite"

    insecure           = false
    request_timeout_ms = 2000

    request_headers = {
      Content-Type  = "application/json"
      Authorization = "Bearer ${param.token}"
    }

    request_body = jsonencode({
      handle = "${param.user_handle}"
      role   = "${param.role}"
    })
  }

  output "invitation_details" {
    value       = step.http.invite_org_member_by_handle.response_body
    description = "The details of the invitation."
  }
}