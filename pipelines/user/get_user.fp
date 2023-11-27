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
    description = "The handle of the user to retrieve."
  }

  step "http" "get_user" {
    method = "get"
    url    = "https://pipes.turbot.com/api/latest/user/${param.user_handle}"

    insecure           = false
    request_timeout_ms = 2000

    request_headers = {
      Content-Type  = "application/json"
      Authorization = "Bearer ${param.token}"
    }
  }

  output "user" {
    value       = step.http.get_user.response_body
    description = "The user details."
  }
}
