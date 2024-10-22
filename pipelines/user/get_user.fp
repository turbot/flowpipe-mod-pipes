pipeline "get_user" {
  title       = "Get User"
  description = "Retrieves information of the specified user."

  param "conn" {
    type        = connection.pipes
    description = local.conn_param_description
    default     = connection.pipes.default
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
      Authorization = "Bearer ${param.conn.token}"
    }
  }

  output "user" {
    description = "User details."
    value       = step.http.get_user.response_body
  }
}
