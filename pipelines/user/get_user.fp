pipeline "get_user" {
  title       = "Get User"
  description = "Retrieves information of the specified user."

  param "cred" {
    type        = string
    description = local.cred_param_description
    default     = "default"
  }

  param "user_handle" {
    type        = string
    description = "Specify the handle of the user whose information you want to retrieve."
  }

  step "http" "get_user" {
    method = "get"
    url    = "https://pipes.turbot.com/api/latest/user/${param.user_handle}"

    request_headers = {
      Content-Type  = "application/json"
      Authorization = "Bearer ${credential.pipes[param.cred].token}"
    }
  }

  output "user" {
    description = "User details."
    value       = step.http.get_user.response_body
  }
}
