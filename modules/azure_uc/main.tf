data "azurerm_databricks_workspace" "this" {
  name                = local.databricks_workspace_name
  resource_group_name = local.resource_group
}

locals {
  resource_regex            = "(?i)subscriptions/(.+)/resourceGroups/(.+)/providers/Microsoft.Databricks/workspaces/(.+)"
  subscription_id           = regex(local.resource_regex, var.databricks_resource_id)[0]
  resource_group            = regex(local.resource_regex, var.databricks_resource_id)[1]
  databricks_workspace_name = regex(local.resource_regex, var.databricks_resource_id)[2]
  tenant_id                 = data.azurerm_client_config.current.tenant_id
  databricks_workspace_host = data.azurerm_databricks_workspace.this.workspace_url
  databricks_workspace_id   = data.azurerm_databricks_workspace.this.workspace_id
  prefix                    = replace(replace(lower(data.azurerm_resource_group.this.name), "rg", ""), "-", "")
}

data "azurerm_resource_group" "this" {
  name = local.resource_group
}

data "azurerm_client_config" "current" {
}

resource "azurerm_databricks_access_connector" "unity" {
  name                = "${local.prefix}-databricks-mi"
  resource_group_name = data.azurerm_resource_group.this.name
  location            = data.azurerm_resource_group.this.location
  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_storage_account" "unity_catalog" {
  name                     = "${local.prefix}storage"
  resource_group_name      = data.azurerm_resource_group.this.name
  location                 = data.azurerm_resource_group.this.location
  tags                     = data.azurerm_resource_group.this.tags
  account_tier             = "Standard"
  account_replication_type = "GRS"
  is_hns_enabled           = true
}

resource "azurerm_storage_container" "unity_catalog" {
  name                  = "${local.prefix}-container"
  storage_account_name  = azurerm_storage_account.unity_catalog.name
  container_access_type = "private"
}

locals {
  create_metastore = var.metastore_id == null
  metastore_id     = local.create_metastore ? databricks_metastore.this[0].id : var.metastore_id
  uc_storage_url = format("abfss://%s@%s.dfs.core.windows.net/",
    azurerm_storage_container.unity_catalog.name,
  azurerm_storage_account.unity_catalog.name)
}

# The access connector's managed identity needs data-plane access to the UC storage account
resource "azurerm_role_assignment" "unity_storage" {
  scope                = azurerm_storage_account.unity_catalog.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_databricks_access_connector.unity.identity[0].principal_id
}

# Databricks requires the MI to have Reader on its own access connector to register a credential
resource "azurerm_role_assignment" "unity_connector_reader" {
  scope                = azurerm_databricks_access_connector.unity.id
  role_definition_name = "Reader"
  principal_id         = azurerm_databricks_access_connector.unity.identity[0].principal_id
}

# ...and the principal registering the credential needs Contributor directly on the connector
# (inherited Owner is not always recognised, e.g. for guest/MSA accounts)
resource "azurerm_role_assignment" "deployer_connector_contributor" {
  scope                = azurerm_databricks_access_connector.unity.id
  role_definition_name = "Contributor"
  principal_id         = data.azurerm_client_config.current.object_id
}

# Azure RBAC is eventually consistent; Databricks validates these roles immediately
resource "time_sleep" "rbac_propagation" {
  create_duration = "120s"
  depends_on = [
    azurerm_role_assignment.unity_storage,
    azurerm_role_assignment.unity_connector_reader,
    azurerm_role_assignment.deployer_connector_contributor,
  ]
}

resource "databricks_metastore" "this" {
  count = local.create_metastore ? 1 : 0

  name          = "regulated-fins-metastore"
  storage_root  = local.uc_storage_url
  force_destroy = true
}

resource "databricks_metastore_data_access" "first" {
  count = local.create_metastore ? 1 : 0

  metastore_id = databricks_metastore.this[0].id
  name         = "regulated-fins-ms-data-access"
  azure_managed_identity {
    access_connector_id = azurerm_databricks_access_connector.unity.id
  }

  is_default = true
  depends_on = [time_sleep.rbac_propagation]
}

resource "databricks_metastore_assignment" "this" {
  count = local.create_metastore ? length(var.workspaces_to_associate) : 0

  workspace_id = var.workspaces_to_associate[count.index]
  metastore_id = databricks_metastore.this[0].id
}

# When reusing an existing (e.g. auto-provisioned) metastore, expose the module's
# storage account to Unity Catalog as a storage credential + external location.
resource "databricks_storage_credential" "this" {
  count = local.create_metastore ? 0 : 1

  name = "${local.prefix}-uc-credential"
  azure_managed_identity {
    access_connector_id = azurerm_databricks_access_connector.unity.id
  }
  comment    = "Managed by Terraform (lakehouse blueprints)"
  depends_on = [time_sleep.rbac_propagation]
}

resource "databricks_external_location" "this" {
  count = local.create_metastore ? 0 : 1

  name            = "${local.prefix}-uc-location"
  url             = local.uc_storage_url
  credential_name = databricks_storage_credential.this[0].name
  comment         = "Managed by Terraform (lakehouse blueprints)"
}
