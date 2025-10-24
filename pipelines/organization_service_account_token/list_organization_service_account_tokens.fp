pipeline "list_organization_service_account_tokens" {
  title       = "List Organization Service Account Tokens"
  description = "List all tokens for a service account in an organization."

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

  step "http" "list_organization_service_account_tokens" {
    method = "get"
    url    = "https://pipes.turbot.com/api/latest/org/${param.org_handle}/service_account/${param.service_account_identifier}/token?limit=10"

    request_headers = {
      Content-Type  = "application/json"
      Authorization = "Bearer ${param.conn.token}"
    }
  }

  output "organization_service_account_tokens" {
    description = "List of organization service account tokens."
    value       = step.http.list_organization_service_account_tokens.response_body.items
  }
}
