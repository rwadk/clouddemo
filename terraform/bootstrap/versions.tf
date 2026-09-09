terraform {
  required_version = ">= 1.9"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.12"
    }
  }

  # Migrated here after the first apply. On a brand-new subscription this block
  # has to be commented out for one run, because the storage account it names
  # is created by this very stack — see README.md in this directory.
  backend "azurerm" {
    resource_group_name  = "rg-clouddemo-tfstate"
    storage_account_name = "stclouddemotfnrxsl5"
    container_name       = "tfstate-bootstrap"
    key                  = "bootstrap.tfstate"
    use_azuread_auth     = true
  }
}

provider "azurerm" {
  features {}

  subscription_id = var.subscription_id

  # Authenticate to the storage data plane with Entra ID rather than
  # account keys. Required because shared-key auth is disabled below.
  storage_use_azuread = true
}
