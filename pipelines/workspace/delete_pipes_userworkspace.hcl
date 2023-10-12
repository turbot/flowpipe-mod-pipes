pipeline "delete_pipes_userworkspace" {

  param "pipes_token" {
    type    = string
    default = var.pipes_token
  }
  param "user_handle" {
    type    = string
    default = var.pipes_user
  }

  param "workspace_handle" {
    type    = string
    default = "virgo"
  }


  step "http" "delete_org_workspace" {
    url                = "https://pipes.turbot.com/api/v0/user/${param.user_handle}/workspace/${param.workspace_handle}"
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