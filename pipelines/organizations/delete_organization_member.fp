pipeline "delete_organization_member" {
  title       = "Delete Organization Member"
  description = "Delete the user from the org."

  param "token" {
    type        = string
    description = local.token_param_description
    default     = var.token
  }

  param "organization_handle" {
    type        = string
    description = "The handle of an organization from where the member has to be deleted."
  }

  param "user_handle" {
    type        = string
    description = "The handle of the user to be deleted."
  }

  step "http" "delete_organization_member" {
    method = "delete"
    url    = "https://pipes.turbot.com/api/v0/org/${param.organization_handle}/member/${param.user_handle}"

    request_headers = {
      Content-Type  = "application/json"
      Authorization = "Bearer ${param.token}"
    }
  }

  output "member" {
    value       = step.http.delete_organization_member.response_body
    description = "The details of the deleted member."
  }
}
