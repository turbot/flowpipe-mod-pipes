pipeline "remove_pipes_user_from_org" {

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
  step "http" "create_org_workspace" {
//https://pipes.turbot.com/api/v0/org/{org_handle}/member/{user_handle}
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
    value = jsondecode(step.http.pipes_get_users.response_body)
  }
  output "response_headers" {
    value = step.http.pipes_get_users.response_headers
  }
  output "status_code" {
    value = step.http.pipes_get_users.status_code
  }
}
