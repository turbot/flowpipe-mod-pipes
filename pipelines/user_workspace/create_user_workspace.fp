pipeline "create_user_workspace" {
  title       = "Create User Workspace"
  description = "Creates a new workspace for a user."

  param "cred" {
    type        = string
    description = local.cred_param_description
    default     = "default"
  }

  param "user_handle" {
    type        = string
    description = "The handle of the user where we want to create the workspace."
  }

  param "handle" {
    type        = string
    description = "The handle name of the workspace to create."
  }

  param "instance_type" {
    type        = string
    description = "The type of the instance to be created. Expected values are 'db1.shared' and 'db1.small'."
  }

  step "http" "create_user_workspace" {
    method = "post"
    url    = "https://pipes.turbot.com/api/v0/user/${param.user_handle}/workspace"

    request_headers = {
      Content-Type  = "application/json"
      Authorization = "Bearer ${credential.pipes[param.cred].token}"
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
