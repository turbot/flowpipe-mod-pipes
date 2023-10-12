pipeline "describe_pipes_user" {

  param "pipes_token" {
    type    = string
    default = var.pipes_token
  }

  param "pipes_user" {
    type    = string
    default = var.pipes_user
  }

  step "echo" "lookup_url" {
    text = "https://pipes.turbot.com/api/latest/user/${param.pipes_user}"
  }
  # curl https://pipes.turbot.com/api/v0/user
  step "http" "pipes_get_user" {
    url                = "https://pipes.turbot.com/api/latest/user/${param.pipes_user}"
    method             = "get"
    insecure           = false
    request_timeout_ms = 2000
    request_headers    = {
      Content-Type  = "application/json"
      Authorization = "Bearer ${param.pipes_token}"
    }
  }

  output "response_body" {
    value = step.http.pipes_get_users.response_body
  }
  output "response_headers" {
    value = step.http.pipes_get_users.response_headers
  }
  output "status_code" {
    value = step.http.pipes_get_users.status_code
  }

}
