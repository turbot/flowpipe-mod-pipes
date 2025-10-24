pipeline "get_organization_service_account" {
  title       = "Get Organization Service Account"
  description = "Retrieves information of the specified service account in organization."

  param "conn" {
    type        = connection.pipes
    description = local.conn_param_description
    default     = connection.pipes.default
  }

  param "org_handle" {
    type        = string
    description = "Specify the organization handle."
  }

  param "service_account_handle" {
    type        = string
    description = "Specify the service account handle."
  }

  step "http" "get_organization_service_account" {
    method = "get"
    url    = "https://pipes.turbot.com/api/latest/org/${param.org_handle}/service_account/${param.service_account_handle}"

    request_headers = {
      Content-Type  = "application/json"
      Authorization = "Bearer ${param.conn.token}"
    }
  }

  output "organization_service_account" {
    description = "The organization service account details."
    value       = step.http.get_organization_service_account.response_body
  }
}
