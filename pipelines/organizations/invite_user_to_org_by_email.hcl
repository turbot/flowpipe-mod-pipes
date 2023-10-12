pipeline "invite_pipes_user_to_org_by_email" {
  title       = "Invite user to organization by user email address"
  description = "Invite user to an organization by that user's email address."
  param "pipes_token" {
    type    = string
    default = var.pipes_token
  }
  param "org_handle" {
    type    = string
    default = var.org_handle
  }

  param "role" {
    type    = string
    default = var.org_role
    # valid values: owner, member
  }

  param "email" {
    type    = string
    default = var.user_email
  }

  step "http" "invite_pipes_user_to_org_by_email" {
    title              = "Invite user to organization by user email address"
    url                = "https://pipes.turbot.com/api/v0/org/${param.org_handle}/member/invite"
    method             = "post"
    insecure           = false
    request_timeout_ms = 2000
    request_headers    = {
      Content-Type  = "application/json"
      Authorization = "Bearer ${param.pipes_token}"
    }
    request_body = jsonencode({
      role  = "${param.role}"
      email = "${param.email}"
    })
  }

  output "response_body" {
    value = jsondecode(step.http.invite_pipes_user_to_org_by_email.response_body)
  }

  output "status_code" {
    value = step.http.invite_pipes_user_to_org_by_email.status_code
  }
}