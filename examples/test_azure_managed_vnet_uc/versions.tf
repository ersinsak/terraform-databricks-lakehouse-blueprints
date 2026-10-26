terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.43.0"
    }
    databricks = {
      source  = "databricks/databricks"
      version = ">=1.9.2, <2.0.0"
    }
    time = {
      source  = "hashicorp/time"
      version = ">=0.9.0"
    }
  }
}
