pipeline "create_user_workspace" {
  title       = "Create User Workspace"
  description = "Creates a new workspace for a user."

  param "token" {
    type        = string
    description = local.token_param_description
    default     = var.token
  }

  param "user_handle" {
    type        = string
    description = "The handle of the user where we want to create the workspace."
  }

  param "workspace_handle" {
    type        = string
    description = "The handle name of the workspace to be created."
  }

  param "instance_type" {
    type        = string
    description = "The type of the instance to be created. Expected values are db1.shared and 'db1.small'."
  }

  step "http" "create_user_workspace" {
    method = "post"
    url    = "https://pipes.turbot.com/api/v0/user/${param.user_handle}/workspace"

    request_headers = {
      Content-Type  = "application/json"
      Authorization = "Bearer ${param.token}"
    }

    request_body = jsonencode({
      handle        = param.workspace_handle
      instance_type = param.instance_type
    })
  }

  output "user_workspace" {
    description = "Workspace details."
    value       = step.http.create_user_workspace.response_body
  }
}
