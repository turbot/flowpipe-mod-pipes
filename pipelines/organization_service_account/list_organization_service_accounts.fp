pipeline "list_organization_service_accounts" {
  title       = "List Organization Service Accounts"
  description = "List all service accounts in an organization."

  param "conn" {
    type        = connection.pipes
    description = local.conn_param_description
    default     = connection.pipes.default
  }

  param "org_handle" {
    type        = string
    description = "Specify the organization handle."
  }

  step "http" "list_organization_service_accounts" {
    method = "get"
    url    = "https://pipes.turbot.com/api/latest/org/${param.org_handle}/service_account?limit=20"

    request_headers = {
      Content-Type  = "application/json"
      Authorization = "Bearer ${param.conn.token}"
    }

    loop {
      until = lookup(result.response_body, "next_token", null) == null
      url   = "https://pipes.turbot.com/api/latest/org/${param.org_handle}/service_account?limit=1&next_token=${result.response_body.next_token}"
    }
  }

  output "organization_service_accounts" {
    description = "List of organization service accounts."
    value       = flatten([for page in step.http.list_organization_service_accounts : page.response_body.items])
  }
}
