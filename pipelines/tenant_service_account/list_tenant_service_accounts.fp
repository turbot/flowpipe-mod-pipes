pipeline "list_tenant_service_accounts" {
  title       = "List Tenant Service Accounts"
  description = "List all service accounts in a tenant."

  param "conn" {
    type        = connection.pipes
    description = local.conn_param_description
    default     = connection.pipes.default
  }

  param "tenant_id" {
    type        = string
    description = "Specify the tenant ID."
  }

  step "http" "list_tenant_service_accounts" {
    method = "get"
    url    = "https://${param.tenant_id}.pipes.turbot.com/api/latest/service_account?limit=1"

    request_headers = {
      Content-Type  = "application/json"
      Authorization = "Bearer ${param.conn.token}"
    }

    loop {
      until = lookup(result.response_body, "next_token", null) == null
      url   = "https://${param.tenant_id}.pipes.turbot.com/api/latest/service_account?limit=1&next_token=${result.response_body.next_token}"
    }
  }

  output "tenant_service_accounts" {
    description = "List of tenant service accounts."
    value       = flatten([for page in step.http.list_tenant_service_accounts : page.response_body.items])
  }
}
