# CONTRIBUTION: Add to flowpipe-mod-pipes
# Location: pipelines/organization_workspace_snapshot/create_organization_workspace_snapshot.fp
#
# This pipeline creates a snapshot of a dashboard in an organization workspace.
# API: POST /api/v0/org/{org_handle}/workspace/{workspace_handle}/snapshot
# Docs: https://pipes.turbot.com/api/latest/docs

pipeline "create_organization_workspace_snapshot" {
  title       = "Create Organization Workspace Snapshot"
  description = "Creates a snapshot of a dashboard in an organization workspace."

  tags = {
    recommended = "true"
  }

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

  param "dashboard_name" {
    type        = string
    description = "The name of the dashboard to snapshot (e.g., 'mod.dashboard.my_dashboard')."
  }

  param "visibility" {
    type        = string
    description = "The visibility of the snapshot: 'workspace', 'org', or 'anyone'. Defaults to 'workspace'."
    default     = "workspace"
  }

  param "tags" {
    type        = map(string)
    description = "Optional tags to apply to the snapshot for categorization."
    optional    = true
  }

  param "inputs" {
    type        = map(string)
    description = "Optional input values for dashboard variables."
    optional    = true
  }

  step "http" "create_organization_workspace_snapshot" {
    method = "post"
    url    = "https://pipes.turbot.com/api/v0/org/${param.organization_handle}/workspace/${param.workspace_handle}/snapshot"

    request_headers = {
      Content-Type  = "application/json"
      Authorization = "Bearer ${param.conn.token}"
    }

    request_body = jsonencode({
      dashboard_name = param.dashboard_name
      visibility     = param.visibility
      tags           = param.tags
      inputs         = param.inputs
    })
  }

  output "snapshot" {
    description = "The created snapshot details including ID, state, and dashboard information."
    value       = step.http.create_organization_workspace_snapshot.response_body
  }

  output "snapshot_id" {
    description = "The ID of the created snapshot."
    value       = step.http.create_organization_workspace_snapshot.response_body.id
  }

  output "snapshot_url" {
    description = "The URL to view the snapshot in Turbot Pipes."
    value       = "https://pipes.turbot.com/org/${param.organization_handle}/workspace/${param.workspace_handle}/snapshot/${step.http.create_organization_workspace_snapshot.response_body.id}"
  }
}
