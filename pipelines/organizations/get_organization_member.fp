pipeline "get_organization_member" {
  title       = "Get Organization Member"
  description = "Retrieves information of the specified user in organization."

  param "token" {
    type        = string
    description = local.token_param_description
    default     = var.token
  }

  param "user_handle" {
    type        = string
    description = "The handle of the user to retrieve."
  }

  param "organization_handle" {
    type        = string
    description = "The handle of the organization where the workspace has to be created."
  }

  step "http" "get_organization_member" {
    method = "get"
    url    = "https://pipes.turbot.com/api/latest/org/${param.organization_handle}/member/${param.user_handle}"

    request_headers = {
      Content-Type  = "application/json"
      Authorization = "Bearer ${param.token}"
    }
  }

  output "member" {
    value       = step.http.get_organization_member
    description = "The organization user details."
  }
}
