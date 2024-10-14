pipeline "list_organization_members" {
  title       = "List Organization Members"
  description = "List all members of an organization who are invited / accepted."

  param "conn" {
    type        = connection.pipes
    description = local.conn_param_description
    default     = connection.pipes.default
  }

  param "org_handle" {
    type        = string
    description = "Specify the organization handle."
  }

  step "http" "list_organization_members" {
    method = "get"
    url    = "https://pipes.turbot.com/api/latest/org/${param.org_handle}/member?limit=1"

    request_headers = {
      Content-Type  = "application/json"
      Authorization = "Bearer ${param.conn.token}"
    }

    loop {
      until = lookup(result.response_body, "next_token", null) == null
      url   = "https://pipes.turbot.com/api/latest/org/${param.org_handle}/member?limit=1&next_token=${result.response_body.next_token}"
    }
  }

  output "members" {
    description = "List of organization members."
    value       = flatten([for page, members in step.http.list_organization_members : members.response_body.items])
  }
}
