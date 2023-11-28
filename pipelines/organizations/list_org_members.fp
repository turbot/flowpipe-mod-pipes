pipeline "list_org_members" {
  title       = "List Organization Members"
  description = "Retrieves information about rganization members."

  param "token" {
    type        = string
    description = local.token_param_description
    default     = var.token
  }

  param "org_handle" {
    type        = string
    description = "The handle of the organization where the workspace has to be created."
  }

  step "http" "list_org_members" {
    method = "get"
    url    = "https://pipes.turbot.com/api/latest/org/${param.org_handle}/member"

    insecure           = false
    request_timeout_ms = 2000

    request_headers = {
      Content-Type  = "application/json"
      Authorization = "Bearer ${param.token}"
    }
  }

  output "members" {
    value       = step.http.list_org_members.response_body
    description = "The list of members of the organization."
  }
}
