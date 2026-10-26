variable "location" {
  type        = string
  description = "(Required) Azure region for all resources"
}

variable "resource_group_name" {
  type        = string
  description = "(Required) Resource group to create. NOTE: azure_uc derives the UC storage account name from it (lowercased, 'rg' and '-' removed, + 'storage'); result must be globally unique and <= 24 chars."
}

variable "databricks_workspace_name" {
  type        = string
  description = "(Required) Name of the Azure Databricks workspace"
}

variable "no_public_ip" {
  type        = bool
  description = "(Optional) Secure cluster connectivity. false = nodes get public IPs while running (no NAT gateway cost). true = no public IPs; Databricks adds a NAT gateway (~$1/day)."
  default     = false
}

variable "existing_metastore_id" {
  type        = string
  description = "(Optional) Reuse an existing Unity Catalog metastore (Azure auto-provisions one per region). If null, a new metastore is created."
  default     = null
}

variable "allowed_node_types" {
  type        = list(string)
  description = "(Optional) VM sizes allowed by the cost-guard cluster policy; first entry is the default"
  default     = ["Standard_D4ds_v5", "Standard_DS3_v2"]
}

variable "max_autotermination_minutes" {
  type        = number
  description = "(Optional) Upper bound for cluster auto-termination in the cost-guard policy"
  default     = 60
}

variable "tags" {
  type        = map(string)
  description = "(Optional) Tags to attach to resources"
  default     = {}
}
