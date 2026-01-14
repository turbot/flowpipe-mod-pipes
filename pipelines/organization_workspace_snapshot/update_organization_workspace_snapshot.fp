# CONTRIBUTION: Add to flowpipe-mod-pipes
# Location: pipelines/organization_workspace_snapshot/update_organization_workspace_snapshot.fp
#
# Updates properties of a specific snapshot (title, visibility, tags).
# API: PATCH /api/v0/org/{org_handle}/workspace/{workspace_handle}/snapshot/{snapshot_id}
# Docs: https://pipes.turbot.com/api/latest/docs

pipeline "update_organization_workspace_snapshot" {
  title       = "Update Organization Workspace Snapshot"
  description = "Updates title, visibility, or tags of a snapshot."

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
    description = "The ID of the snapshot to update."
  }

  param "title" {
    type        = string
    description = "New title for the snapshot."
    optional    = true
  }

  param "visibility" {
    type        = string
    description = "New visibility: 'workspace', 'org', or 'anyone'."
    optional    = true
  }

  param "tags" {
    type        = map(string)
    description = "New tags to apply to the snapshot."
    optional    = true
  }

  step "http" "update_organization_workspace_snapshot" {
    method = "patch"
    url    = "https://pipes.turbot.com/api/v0/org/${param.organization_handle}/workspace/${param.workspace_handle}/snapshot/${param.snapshot_id}"

    request_headers = {
      Content-Type  = "application/json"
      Authorization = "Bearer ${param.conn.token}"
    }

    request_body = jsonencode({
      for name, value in {
        title      = param.title
        visibility = param.visibility
        tags       = param.tags
      } : name => value if value != null
    })
  }

  output "snapshot" {
    description = "The updated snapshot details."
    value       = step.http.update_organization_workspace_snapshot.response_body
  }
}
