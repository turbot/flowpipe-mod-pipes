variable "token" {
  type = string
  description = "Pipes API Token"
  default     = "tpt_ckj18dg"
}

variable "user" {
  type = string
  description = "Pipes User Handle"
  default     = "some_user"
}

variable "user_email" {
  type = string
  description = "Pipes User Email address"
  default     = "user@company.com"
}

variable "org_handle" {
  type = string
  description = "Org Handle"
  default     = "MyOrganization"
}

variable "workspace_handle" {
  type = string
  description = "Name for a workspace"
  default = "MyWorkspace"
}

variable "org_role" {
  type = string
  description = "Org role assigned to user"
  default = "member"
  # valid values: owner, member
}
