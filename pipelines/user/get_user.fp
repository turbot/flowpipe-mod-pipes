pipeline "get_user" {
  title       = "Get User"
  description = "Retrieves information of a user by handle."

  param "token" {
    type        = string
    description = local.token_param_description
    default     = var.token
  }

  param "user_handle" {
    type        = string
    description = "The handle of the user to retrieve."
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
