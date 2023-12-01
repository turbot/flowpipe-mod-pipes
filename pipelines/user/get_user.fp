pipeline "get_user" {
  title       = "Get User"
  description = "Retrieves information of the specified user."

  param "token" {
    type        = string
    description = local.token_param_description
    default     = var.token
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
      Authorization = "Bearer ${param.token}"
    }
  }

  output "user" {
    description = "User details."
    value       = step.http.get_user.response_body
  }
}
