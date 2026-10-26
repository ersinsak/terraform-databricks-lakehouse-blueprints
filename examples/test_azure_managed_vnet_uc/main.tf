resource "azurerm_resource_group" "this" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

# Databricks-managed VNet: no VNet injection, no firewall, no NAT gateway.
# With no_public_ip = false, cluster nodes get a public IP only while running
# (outbound goes through it), so idle networking cost is ~0.
resource "azurerm_databricks_workspace" "this" {
  name                = var.databricks_workspace_name
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  sku                 = "premium" # required for Unity Catalog

  custom_parameters {
    no_public_ip = var.no_public_ip
  }

  tags = var.tags
}

module "unity_catalog" {
  source = "../../modules/azure_uc"

  resource_group_id       = azurerm_resource_group.this.id
  workspaces_to_associate = [tonumber(azurerm_databricks_workspace.this.workspace_id)]
  location                = var.location
  databricks_resource_id  = azurerm_databricks_workspace.this.id
  workspace_url           = azurerm_databricks_workspace.this.workspace_url
  metastore_id            = var.existing_metastore_id
}

# Cost guardrail: small clusters that always auto-terminate
resource "databricks_cluster_policy" "cost_guard" {
  name = "cost-guard"
  definition = jsonencode({
    "autotermination_minutes" : {
      "type" : "range",
      "maxValue" : var.max_autotermination_minutes,
      "defaultValue" : 20
    },
    "num_workers" : {
      "type" : "range",
      "maxValue" : 2,
      "defaultValue" : 0
    },
    "node_type_id" : {
      "type" : "allowlist",
      "values" : var.allowed_node_types,
      "defaultValue" : var.allowed_node_types[0]
    },
    "driver_node_type_id" : {
      "type" : "allowlist",
      "values" : var.allowed_node_types,
      "defaultValue" : var.allowed_node_types[0]
    }
  })
}
