pipeline "list_tenant_service_account_tokens" {
  title       = "List Tenant Service Account Tokens"
  description = "List all tokens for a service account in a tenant."

  param "conn" {
    type        = connection.pipes
    description = local.conn_param_description
    default     = connection.pipes.default
  }

  param "tenant_id" {
    type        = string
    description = "Specify the tenant ID."
  }

  param "service_account_identifier" {
    type        = string
    description = "Specify the service account identifier."
  }

  step "http" "list_tenant_service_account_tokens" {
    method = "get"
    # Service accounts can have max 2 tokens - fetch all in one request
    url = "https://${param.tenant_id}.pipes.turbot.com/api/latest/service_account/${param.service_account_identifier}/token?limit=10"

    request_headers = {
      Content-Type  = "application/json"
      Authorization = "Bearer ${param.conn.token}"
    }
  }

  output "tenant_service_account_tokens" {
    description = "List of tenant service account tokens."
    value       = step.http.list_tenant_service_account_tokens.response_body.items
  }
}
