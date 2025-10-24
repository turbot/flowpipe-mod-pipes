pipeline "get_tenant_service_account" {
  title       = "Get Tenant Service Account"
  description = "Retrieves information of the specified service account in tenant."

  param "conn" {
    type        = connection.pipes
    description = local.conn_param_description
    default     = connection.pipes.default
  }

  param "tenant_id" {
    type        = string
    description = "Specify the tenant ID."
  }

  param "service_account_handle" {
    type        = string
    description = "Specify the service account identifier."
  }

  step "http" "get_tenant_service_account" {
    method = "get"
    url    = "https://${param.tenant_id}.pipes.turbot.com/api/latest/service_account/${param.service_account_handle}"

    request_headers = {
      Content-Type  = "application/json"
      Authorization = "Bearer ${param.conn.token}"
    }
  }

  output "tenant_service_account" {
    description = "The tenant service account details."
    value       = step.http.get_tenant_service_account.response_body
  }
}
