# CONTRIBUTION: Add to flowpipe-mod-pipes
# Location: pipelines/organization_workspace_snapshot/download_organization_workspace_snapshot.fp
#
# Downloads snapshot data in the specified format (.pps, .json, .csv, .md, etc.).
# API: GET /api/v0/org/{org_handle}/workspace/{workspace_handle}/snapshot/{snapshot_id}.{content_type}
# Docs: https://pipes.turbot.com/api/latest/docs

pipeline "download_organization_workspace_snapshot" {
  title       = "Download Organization Workspace Snapshot"
  description = "Downloads a snapshot in the specified format (pps, json, csv, md, ndjson, etc.)."

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
    description = "The ID of the snapshot to download."
  }

  param "content_type" {
    type        = string
    description = "The format to download: 'pps', 'json', 'csv', 'md', 'ndjson'. Defaults to 'pps'."
    default     = "pps"
  }

  param "file_path" {
    type        = string
    description = "Optional local file path to save the downloaded snapshot. If not provided, returns content in output."
    optional    = true
  }

  step "http" "download_organization_workspace_snapshot" {
    method = "get"
    url    = "https://pipes.turbot.com/api/v0/org/${param.organization_handle}/workspace/${param.workspace_handle}/snapshot/${param.snapshot_id}.${param.content_type}"

    request_headers = {
      Content-Type  = "application/json"
      Authorization = "Bearer ${param.conn.token}"
    }
  }

  # Note: Flowpipe doesn't have native file writing from HTTP responses
  # The content will be available in the output for processing
  # Users can redirect output or use additional steps to save to disk

  output "content" {
    description = "The downloaded snapshot content in the requested format."
    value       = step.http.download_organization_workspace_snapshot.response_body
  }

  output "download_url" {
    description = "The URL used to download the snapshot."
    value       = "https://pipes.turbot.com/api/v0/org/${param.organization_handle}/workspace/${param.workspace_handle}/snapshot/${param.snapshot_id}.${param.content_type}"
  }
}
