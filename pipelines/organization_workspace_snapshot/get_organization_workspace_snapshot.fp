# CONTRIBUTION: Add to flowpipe-mod-pipes
# Location: pipelines/organization_workspace_snapshot/get_organization_workspace_snapshot.fp
#
# Gets details of a specific snapshot in an organization workspace.
# API: GET /api/v0/org/{org_handle}/workspace/{workspace_handle}/snapshot/{snapshot_id}
# Docs: https://pipes.turbot.com/api/latest/docs

pipeline "get_organization_workspace_snapshot" {
  title       = "Get Organization Workspace Snapshot"
  description = "Gets details of a specific snapshot in an organization workspace."

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

  param "snapshot_id" {
    type        = string
    description = "The ID of the snapshot to retrieve."
  }

  step "http" "get_organization_workspace_snapshot" {
    method = "get"
    url    = "https://pipes.turbot.com/api/v0/org/${param.organization_handle}/workspace/${param.workspace_handle}/snapshot/${param.snapshot_id}"

    request_headers = {
      Content-Type  = "application/json"
      Authorization = "Bearer ${param.conn.token}"
    }
  }

  output "snapshot" {
    description = "The snapshot details including state, dashboard info, and data."
    value       = step.http.get_organization_workspace_snapshot.response_body
  }
}
