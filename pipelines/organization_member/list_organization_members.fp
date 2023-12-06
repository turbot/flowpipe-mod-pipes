pipeline "list_organization_members" {
  title       = "List Organization Members"
  description = "List all members of an organization who are invited / accepted."

  param "cred" {
    type        = string
    description = local.cred_param_description
    default     = "default"
  }

  param "org_handle" {
    type        = string
    description = "Specify the organization handle."
  }

  step "http" "list_organization_members" {
    method = "get"
    url    = "https://pipes.turbot.com/api/latest/org/${param.org_handle}/member?limit=100"

    request_headers = {
      Content-Type  = "application/json"
      Authorization = "Bearer ${credential.pipes[param.cred].token}"
    }

    loop {
      until = lookup(result.response_body, "next_token", null) == null
      url   = "https://pipes.turbot.com/api/latest/org/${param.org_handle}/member?limit=100&next_token=${result.response_body.next_token}"
    }
  }

  output "members" {
    description = "List of organization members."
    value       = step.http.list_organization_members.response_body
  }
}
