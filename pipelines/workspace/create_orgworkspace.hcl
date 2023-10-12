pipeline "create_orgworkspace" {

  param "pipes_token" {
    type    = string
    default = var.pipes_token
  }
  param "org_handle" {
    type    = string
    default = var.org_handle
  }

  param "instance_handle" {
    type    = string
    default = "taurus2"
  }

  param "instance_type" {
    type = string
    default = "db1.shared"
  }

  step "http" "create_orgworkspace" {
    url                = "https://pipes.turbot.com/api/v0/org/${param.org_handle}/workspace"
    method             = "post"
    insecure           = false
    request_timeout_ms = 2000
    request_headers    = {
      Content-Type  = "application/json"
      Authorization = "Bearer ${param.pipes_token}"
    }
    request_body = jsonencode({
      handle        = "${param.instance_handle}"
      instance_type = "${param.instance_type  }"
    })
  }

  output "response_body" {
    value = jsondecode(step.http.create_orgworkspace.response_body)
  }
  output "response_headers" {
    value = step.http.create_orgworkspace.response_headers
  }
  output "status_code" {
    value = step.http.create_orgworkspace.status_code
  }
}