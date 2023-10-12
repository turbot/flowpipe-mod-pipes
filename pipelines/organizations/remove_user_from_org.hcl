pipeline "remove_user_from_org" {
  title       = "Remove user from organization"
  description = "Remove user from organization."
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
  param "user_handle" {
    type = string
#    default = var.pipes_user
#      default = "partha-tppr"
  }
  step "http" "remove_user_from_org" {
      title       = "Remove user from organization"

    url                = "https://pipes.turbot.com/api/v0/org/${param.org_handle}/member/${param.user_handle}"
    method             = "delete"
    insecure           = false
    request_timeout_ms = 2000
    request_headers    = {
      Content-Type  = "application/json"
      Authorization = "Bearer ${param.pipes_token}"
    }
  }

  output "response_body" {
    value = jsondecode(step.http.remove_user_from_org.response_body)
  }

  output "status_code" {
    value = step.http.remove_user_from_org.status_code
  }
}
