pipeline "get_organization_service_account_token" {
  title       = "Get Organization Service Account Token"
  description = "Retrieves information of the specified service account token in organization."

  param "conn" {
    type        = connection.pipes
    description = local.conn_param_description
    default     = connection.pipes.default
  }

  param "org_handle" {
    type        = string
    description = "Specify the organization handle."
  }

  param "service_account_identifier" {
    type        = string
    description = "Specify the service account identifier."
  }

  param "token_id" {
    type        = string
    description = "Specify the token id."
  }

  step "http" "get_organization_service_account_token" {
    method = "get"
    url    = "https://pipes.turbot.com/api/latest/org/${param.org_handle}/service_account/${param.service_account_identifier}/token/${param.token_id}"

    request_headers = {
      Content-Type  = "application/json"
      Authorization = "Bearer ${param.conn.token}"
    }
  }

  output "organization_service_account_token" {
    description = "The organization service account token details."
    value       = step.http.get_organization_service_account_token.response_body
  }
}
