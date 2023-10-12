pipeline "delete_orgworkspace" {
  title       = "Delete an organization workspace"
  description = "Delete an organization workspace."
  param "pipes_token" {
    type    = string
    default = var.token
  }
  param "org_handle" {
    type    = string
    default = var.org_handle
  }

  param "workspace_handle" {
    type    = string
    default = var.workspace_handle
  }


  step "http" "delete_orgworkspace" {
    title              = "Delete an organization workspace"
    url                = "https://pipes.turbot.com/api/v0/org/${param.org_handle}/workspace/${param.workspace_handle}"
    method             = "delete"
    insecure           = false
    request_timeout_ms = 2000
    request_headers    = {
      Content-Type  = "application/json"
      Authorization = "Bearer ${param.pipes_token}"
    }
  }

  output "response_body" {
    value = jsondecode(step.http.delete_orgworkspace.response_body)
  }

  output "status_code" {
    value = step.http.delete_orgworkspace.status_code
  }
}