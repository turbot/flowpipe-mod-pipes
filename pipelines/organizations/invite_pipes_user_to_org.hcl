pipeline "invite_pipes_user_to_org_by_handle" {

  param "pipes_token" {
    type    = string
    default = var.pipes_token
  }
  param "org_handle" {
    type    = string
    default = var.org_handle
  }

  param "role" {
    type    = string
    default = var.org_role
    # valid values: owner, member
  }

  param "user_handle" {
    type = string
#    default = var.pipes_user
    default = "partha-tppr"
  }


  step "http" "invite_user_to_org" {

    url                = "https://pipes.turbot.com/api/v0/org/${param.org_handle}/member/invite"
    method             = "post"
    insecure           = false
    request_timeout_ms = 2000
    request_headers    = {
      Content-Type  = "application/json"
      Authorization = "Bearer ${param.pipes_token}"
    }
    request_body = jsonencode({
      handle = "${param.user_handle}"
      role   = "${param.role}"
    })
  }

  output "response_body" {
    value = jsondecode(step.http.pipes_get_users.response_body)
  }
  output "response_headers" {
    value = step.http.pipes_get_users.response_headers
  }
  output "status_code" {
    value = step.http.pipes_get_users.status_code
  }
}


pipeline "invite_pipes_user_to_org_by_email" {

  param "pipes_token" {
    type    = string
    default = var.pipes_token
  }
  param "org_handle" {
    type    = string
    default = var.org_handle
  }

  param "role" {
    type    = string
    default = var.org_role
    # valid values: owner, member
  }

  param "email" {
    type    = string
    #    default = var.user_email
    default = "joe+member@turbot.com"
  }


  step "http" "invite_user_to_org" {

    url                = "https://pipes.turbot.com/api/v0/org/${param.org_handle}/member/invite"
    method             = "post"
    insecure           = false
    request_timeout_ms = 2000
    request_headers    = {
      Content-Type  = "application/json"
      Authorization = "Bearer ${param.pipes_token}"
    }
    request_body = jsonencode({
      role  = "${param.role}"
      email = "${param.email}"
    })
  }

  output "response_body" {
    value = jsondecode(step.http.pipes_get_users.response_body)
  }
  output "response_headers" {
    value = step.http.pipes_get_users.response_headers
  }
  output "status_code" {
    value = step.http.pipes_get_users.status_code
  }
}