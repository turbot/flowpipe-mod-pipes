pipeline "delete_user_workspace" {
  title       = "Delete User Workspace"
  description = "Deletes the workspace specified in the request by the user."

  param "conn" {
    type        = connection.pipes
    description = local.conn_param_description
    default     = connection.pipes.default
  }

  param "user_handle" {
    type        = string
    description = "The handle of the user where the workspace exist."
  }

  param "workspace_handle" {
    type        = string
    description = "Provide the handle of the workspace which needs to be deleted."
  }


  step "http" "delete_user_workspace" {
    method = "delete"
    url    = "https://pipes.turbot.com/api/v0/user/${param.user_handle}/workspace/${param.workspace_handle}"

    request_headers = {
      Content-Type  = "application/json"
      Authorization = "Bearer ${param.conn.token}"
    }
  }

  output "user_workspace" {
    description = "Deleted workspace details."
    value       = step.http.delete_user_workspace.response_body
  }
}
