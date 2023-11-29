pipeline "list_organization_members" {
  title       = "List Organization Members"
  description = "Retrieves information about organization members."

  param "token" {
    type        = string
    description = local.token_param_description
    default     = var.token
  }

  param "organization_handle" {
    type        = string
    description = "The handle of the organization where the workspace has to be created."
  }

  step "http" "list_organization_members" {
    method = "get"
    url    = "https://pipes.turbot.com/api/latest/org/${param.organization_handle}/member"

    request_headers = {
      Content-Type  = "application/json"
      Authorization = "Bearer ${param.token}"
    }
  }

  output "members" {
    value       = step.http.list_organization_members.response_body
    description = "List of organization members."
  }
}
