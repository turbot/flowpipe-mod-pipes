# CONTRIBUTION: Add to flowpipe-mod-pipes
# Location: pipelines/organization_workspace_snapshot/list_organization_workspace_snapshots.fp
#
# Lists all snapshots in an organization workspace with pagination.
# API: GET /api/v0/org/{org_handle}/workspace/{workspace_handle}/snapshot
# Docs: https://pipes.turbot.com/api/latest/docs

pipeline "list_organization_workspace_snapshots" {
  title       = "List Organization Workspace Snapshots"
  description = "Lists all snapshots in an organization workspace."

  param "conn" {
    type        = connection.pipes
    description = local.conn_param_description
    default     = connection.pipes.default
  }

  param "organization_handle" {
    type        = string
    description = "The handle of the organization."
  }

  param "workspace_handle" {
    type        = string
    description = "The handle of the workspace."
  }

  param "limit" {
    type        = number
    description = "The maximum number of items to return per page. Defaults to 50."
    default     = 50
  }

  step "http" "list_organization_workspace_snapshots" {
    method = "get"
    url    = "https://pipes.turbot.com/api/v0/org/${param.organization_handle}/workspace/${param.workspace_handle}/snapshot?limit=${param.limit}"

    request_headers = {
      Content-Type  = "application/json"
      Authorization = "Bearer ${param.conn.token}"
    }

    loop {
      until = lookup(result.response_body, "next_token", null) == null
      url   = "https://pipes.turbot.com/api/v0/org/${param.organization_handle}/workspace/${param.workspace_handle}/snapshot?limit=${param.limit}&next_token=${result.response_body.next_token}"
    }
  }

  output "snapshots" {
    description = "List of snapshots in the workspace."
    value       = flatten([for page, snapshots in step.http.list_organization_workspace_snapshots : snapshots.response_body.items])
  }
}
