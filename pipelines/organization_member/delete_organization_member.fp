pipeline "delete_organization_member" {
  title       = "Delete Organization Member"
  description = "Delete the user from the organization."

  tags = {
    type = "featured"
  }

  param "conn" {
    type        = connection.pipes
    description = local.conn_param_description
    default     = connection.pipes.default
  }

  param "org_handle" {
    type        = string
    description = "Specify the handle of the organization where the member exists."
  }

  param "user_handle" {
    type        = string
    description = "Specify the handle of the user which need to be removed."
  }

  step "http" "delete_organization_member" {
    method = "delete"
    url    = "https://pipes.turbot.com/api/v0/org/${param.org_handle}/member/${param.user_handle}"

    request_headers = {
      Content-Type  = "application/json"
      Authorization = "Bearer ${param.conn.token}"
    }
  }

  output "member" {
    description = "The details of the deleted member."
    value       = step.http.delete_organization_member.response_body
  }
}
