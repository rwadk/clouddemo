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

  # Enabled after the first apply — see README.md in this directory.
  # backend "azurerm" {}
}

provider "azurerm" {
  features {}

  subscription_id = var.subscription_id

  # Authenticate to the storage data plane with Entra ID rather than
  # account keys. Required because shared-key auth is disabled below.
  storage_use_azuread = true
}
