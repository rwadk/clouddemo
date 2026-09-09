terraform {
  required_version = ">= 1.9"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }

  # Partial config. The storage account name carries a random suffix chosen by
  # bootstrap, so it cannot be committed here — CI supplies the rest with
  # -backend-config. See .github/workflows/cd.yml.
  backend "azurerm" {}
}

provider "azurerm" {
  # Deliberately bare. The default "refuse to delete a resource group that
  # still holds resources" is a safety belt this tier wants kept on.
  features {}
}
