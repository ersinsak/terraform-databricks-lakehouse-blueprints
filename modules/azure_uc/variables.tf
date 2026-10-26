variable "resource_group_id" {
  type        = string
  description = "(Required) Resource ID of the pre-existing Resource Group that will house Unity Catalog"
}

variable "workspaces_to_associate" {
  type        = list(number)
  description = "(Optional) List of Databricks Workspace IDs to associate with Unity Catalog"
}

variable "location" {}

variable "databricks_resource_id" {}

variable "workspace_url" {}
variable "metastore_id" {
  type        = string
  description = "(Optional) ID of an existing Unity Catalog metastore to reuse (e.g. the auto-provisioned regional one). If null, a new metastore is created."
  default     = null
}
