pipeline "create_organization_workspace" {
  title       = "Create Organization Workspace"
  description = "Creates a new workspace for an organization."

  tags = {
    type = "featured"
  }

  param "cred" {
    type        = string
    description = local.cred_param_description
    default     = "default"
  }

  param "organization_handle" {
    type        = string
    description = "The handle of the organization where we want to create the workspace."
  }

  param "handle" {
    type        = string
    description = "The handle name of the workspace to be created."
  }

  param "instance_type" {
    type        = string
    description = "The type of the instance to be created. Expected values are 'db1.shared' and 'db1.small'."
  }

  step "http" "create_organization_workspace" {
    method = "post"
    url    = "https://pipes.turbot.com/api/v0/org/${param.organization_handle}/workspace"

    request_headers = {
      Content-Type  = "application/json"
      Authorization = "Bearer ${credential.pipes[param.cred].token}"
    }

    request_body = jsonencode({
      for name, value in param : name => value if value != null
    })
  }

  output "organization_workspace" {
    description = "Workspace details."
    value       = step.http.create_organization_workspace.response_body
  }
}
