pipeline "get_tenant_service_account_token" {
  title       = "Get Tenant Service Account Token"
  description = "Retrieves information of the specified service account token in tenant."

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

  param "token_id" {
    type        = string
    description = "Specify the token id."
  }

  step "http" "get_tenant_service_account_token" {
    method = "get"
    url    = "https://${param.tenant_id}.pipes.turbot.com/api/latest/service_account/${param.service_account_identifier}/token/${param.token_id}"

    request_headers = {
      Content-Type  = "application/json"
      Authorization = "Bearer ${param.conn.token}"
    }
  }

  output "tenant_service_account_token" {
    description = "The tenant service account token details."
    value       = step.http.get_tenant_service_account_token.response_body
  }
}
