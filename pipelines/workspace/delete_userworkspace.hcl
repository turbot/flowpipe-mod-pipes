pipeline "delete_userworkspace" {

  param "token" {
    type    = string
    default = var.token
  }
  param "user_handle" {
    type    = string
    default = var.pipes_user
  }

  param "workspace_handle" {
    type    = string
    default = var.workspace_handle
  }


  step "http" "delete_userworkspace" {
    url                = "https://pipes.turbot.com/api/v0/user/${param.user_handle}/workspace/${param.workspace_handle}"
    method             = "delete"
    insecure           = false
    request_timeout_ms = 2000
    request_headers    = {
      Content-Type  = "application/json"
      Authorization = "Bearer ${param.token}"
    }
  }

  output "response_body" {
    value = jsondecode(step.http.delete_userworkspace.response_body)
  }
  output "response_headers" {
    value = step.http.delete_userworkspace.response_headers
  }
  output "status_code" {
    value = step.http.delete_userworkspace.status_code
  }
}