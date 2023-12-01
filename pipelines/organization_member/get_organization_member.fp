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
    description = "Specify the organization handle where the member is associated."
  }

  param "organization_handle" {
    type        = string
    description = "Specify the handle of the user whose information you want to retrieve."
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
    description = "The organization user details."
    value       = step.http.get_organization_member
  }
}
