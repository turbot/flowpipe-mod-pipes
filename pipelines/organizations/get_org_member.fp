pipeline "get_org_member" {
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

  param "org_handle" {
    type        = string
    description = "The handle of the organization where the workspace has to be created."
    default     = "fastfolloworg"
  }

  step "http" "get_org_member" {
    method = "get"
    url    = "https://pipes.turbot.com/api/latest/org/${param.org_handle}/member/${param.user_handle}"

    insecure           = false
    request_timeout_ms = 2000

    request_headers = {
      Content-Type  = "application/json"
      Authorization = "Bearer ${param.token}"
    }
  }

  output "member" {
    value       = step.http.get_org_member
    description = "The organization user details."
  }
}
