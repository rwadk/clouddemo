terraform {
  required_version = ">= 1.9"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }

  # Partial config — CI supplies the rest with -backend-config.
  backend "azurerm" {}
}

provider "azurerm" {
  features {
    # This whole stack exists to be destroyed and rebuilt, so every Azure
    # feature that quietly retains a name after deletion has to be turned off
    # here. Each of these is a re-deploy failure waiting to happen otherwise.
    key_vault {
      # A destroyed vault lingers soft-deleted and holds its name. The next
      # deploy then fails on a name collision with an invisible resource.
      purge_soft_delete_on_destroy    = true
      recover_soft_deleted_key_vaults = true
    }

    log_analytics_workspace {
      # Same problem: the workspace name stays reserved for 14 days.
      permanently_delete_on_destroy = true
    }

    resource_group {
      # AKS can leave a stray load balancer or public IP behind, which makes
      # the group refuse to delete. Teardown does not delete this group
      # anyway — bootstrap owns it — but the flag keeps a partial destroy from
      # wedging on a leftover.
      prevent_deletion_if_contains_resources = false
    }
  }
}
