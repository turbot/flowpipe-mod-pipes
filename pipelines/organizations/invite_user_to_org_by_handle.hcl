pipeline "invite_user_to_org_by_handle" {
  title       = "Invite user to organization by user handle"
  description = "Invite user to an organization by that user's Pipes handle."
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
  }

  param "user_handle" {
    type    = string
    default = var.pipes_user
  }

  step "http" "invite_user_to_org_by_handle" {
    title              = "Invite member to an org."
    url                = "https://pipes.turbot.com/api/v0/org/${param.org_handle}/member/invite"
    method             = "post"
    insecure           = false
    request_timeout_ms = 2000
    request_headers    = {
      Content-Type  = "application/json"
      Authorization = "Bearer ${param.pipes_token}"
    }
    request_body = jsonencode({
      handle = "${param.user_handle}"
      role   = "${param.role}"
    })
  }

  output "response_body" {
    value = jsondecode(step.http.invite_user_to_org_by_handle.response_body)
  }

  output "status_code" {
    value = step.http.invite_user_to_org_by_handle.status_code
  }
}
