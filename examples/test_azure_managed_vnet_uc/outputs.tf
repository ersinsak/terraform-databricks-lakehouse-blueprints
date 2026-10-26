output "resource_group_name" {
  value = azurerm_resource_group.this.name
}

output "workspace_url" {
  value = "https://${azurerm_databricks_workspace.this.workspace_url}"
}

output "managed_resource_group_name" {
  value = azurerm_databricks_workspace.this.managed_resource_group_name
}

output "metastore_id" {
  value = module.unity_catalog.databricks_metastore_id
}

output "external_location_url" {
  value = module.unity_catalog.external_location_url
}

output "cluster_policy_id" {
  value = databricks_cluster_policy.cost_guard.id
}
