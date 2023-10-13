pipeline "create_userworkspace" {
  title       = "Create user workspace"
  description = "Creates a new workspace for a user."
  param "token" {
    type    = string
    default = var.token
  }
  param "user_handle" {
    type    = string
    default = var.user
  }

  param "instance_handle" {
    type    = string
    default = var.instance_handle
  }

  param "instance_type" {
    type    = string
    default = var.instance_type
  }

  step "http" "create_userworkspace" {
    title              = "Creates a new workspace for a user."
    url                = "https://pipes.turbot.com/api/v0/user/${param.user_handle}/workspace"
    method             = "post"
    insecure           = false
    request_timeout_ms = 2000
    request_headers    = {
      Content-Type  = "application/json"
      Authorization = "Bearer ${param.pipes_token}"
    }
    request_body = jsonencode({
      handle        = "${param.instance_handle}"
      instance_type = "${param.instance_type}"
    })
  }

  output "response_body" {
    value = jsondecode(step.http.create_userworkspace.response_body)
  }

  output "status_code" {
    value = step.http.create_userworkspace.status_code
  }
}