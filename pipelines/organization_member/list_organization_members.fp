pipeline "list_organization_members" {
  title       = "List Organization Members"
  description = "List all members of an organization who are invited / accepted."

  param "token" {
    type        = string
    description = local.token_param_description
    default     = var.token
  }

  param "organization_handle" {
    type        = string
    description = "Specify the organization handle."
  }

  step "http" "list_organization_members" {
    method = "get"
    url    = "https://pipes.turbot.com/api/latest/org/${param.organization_handle}/member?limit=100"

    request_headers = {
      Content-Type  = "application/json"
      Authorization = "Bearer ${param.token}"
    }

    loop {
      until = result.response_body.next_token == null || result.response_body.next_token.length == 0
      url   = "https://pipes.turbot.com/api/latest/org/${param.organization_handle}/member?limit=100&next_token=${result.response_body.next_token}"
    }
  }

  output "members" {
    description = "List of organization members."
    value       = step.http.list_organization_members.response_body
  }
}
