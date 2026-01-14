# CONTRIBUTION: Add to flowpipe-mod-pipes
# Location: pipelines/organization_workspace_snapshot/delete_organization_workspace_snapshot.fp
#
# Deletes a specific snapshot from an organization workspace.
# API: DELETE /api/v0/org/{org_handle}/workspace/{workspace_handle}/snapshot/{snapshot_id}
# Docs: https://pipes.turbot.com/api/latest/docs

pipeline "delete_organization_workspace_snapshot" {
  title       = "Delete Organization Workspace Snapshot"
  description = "Deletes a specific snapshot from an organization workspace."

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
    description = "The ID of the snapshot to delete."
  }

  step "http" "delete_organization_workspace_snapshot" {
    method = "delete"
    url    = "https://pipes.turbot.com/api/v0/org/${param.organization_handle}/workspace/${param.workspace_handle}/snapshot/${param.snapshot_id}"

    request_headers = {
      Content-Type  = "application/json"
      Authorization = "Bearer ${param.conn.token}"
    }
  }

  output "snapshot" {
    description = "The deleted snapshot details."
    value       = step.http.delete_organization_workspace_snapshot.response_body
  }
}
