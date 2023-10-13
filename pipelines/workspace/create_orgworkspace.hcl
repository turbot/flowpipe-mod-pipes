pipeline "create_orgworkspace" {
  title       = "Create an organization workspace"
  description = "Create an organization workspace."
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
    default = var.instance_handle
  }

  param "instance_type" {
    type    = string
    default = var.instance_type
  }

  step "http" "create_orgworkspace" {
    title              = "Creates a new workspace for an organization. The limit is 10 per organization. If you require more than 10, you must contact support to request an increase."
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

  output "status_code" {
    value = step.http.create_orgworkspace.status_code
  }
}