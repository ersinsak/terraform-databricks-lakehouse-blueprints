provider "azurerm" {
  features {}
}

# Authenticates with the Azure CLI login (az login)
provider "databricks" {
  host = azurerm_databricks_workspace.this.workspace_url
}
