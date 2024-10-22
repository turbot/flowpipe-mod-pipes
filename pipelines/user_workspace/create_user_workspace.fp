pipeline "create_user_workspace" {
  title       = "Create User Workspace"
  description = "Creates a new workspace for a user."

  tags = {
    recommended = "true"
  }

  param "conn" {
    type        = connection.pipes
    description = local.conn_param_description
    default     = connection.pipes.default
  }

  param "user_handle" {
    type        = string
    description = "The handle of the user where we want to create the workspace."
  }

  param "handle" {
    type        = string
    description = "The handle name of the workspace to create."
  }

  step "http" "create_user_workspace" {
    method = "post"
    url    = "https://pipes.turbot.com/api/v0/user/${param.user_handle}/workspace"

    request_headers = {
      Content-Type  = "application/json"
      Authorization = "Bearer ${param.conn.token}"
    }

    request_body = jsonencode({
      for name, value in param : name => value if value != null
    })
  }

  output "user_workspace" {
    description = "Workspace details."
    value       = step.http.create_user_workspace.response_body
  }
}
