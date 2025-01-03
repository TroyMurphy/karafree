variable "tenant_id" {
  description = "Tenant Id"
  type        = string
}

variable "resource_group_name" {
  description = "Resource group name"
  type        = string
}

variable "location" {
  description = "Location"
  type        = string
}

variable "tags" {
  type    = map(any)
  default = {}
}

variable "web_app_name" {
  description = "Name of the web app backend api resource"
  type        = string
  default     = "webapi"
}

variable "web_application_insights_name" {
  description = "Name of the app insights resource"
  type        = string
  default     = "webai"
}
