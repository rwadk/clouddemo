## Bootstrap: remote state storage.
##
## The only stack that does not use remote state, because it creates the
## storage that holds it. Runs once on local state, then migrates its own
## state into the account it just created.
##
## One container per environment rather than one shared container: each
## environment's deploy identity can then be granted Storage Blob Data
## Contributor on *its own container only*, so the val pipeline cannot read
## or write prd state. Container-scoped RBAC is the isolation that matters;
## duplicating the account itself would buy nothing extra.
##
## Deliberately hardened, in explicit contrast to the per-environment demo
## storage accounts, which the exercise requires to be publicly readable.

data "azurerm_client_config" "current" {}

resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

locals {
  # Bootstrap keeps its own container alongside the environments'.
  state_containers = toset(concat(["bootstrap"], var.environments))

  tags = {
    project   = var.project
    lifecycle = "persistent"
    managedby = "terraform"
  }
}

resource "azurerm_resource_group" "tfstate" {
  name     = "rg-${var.project}-tfstate"
  location = var.location
  tags     = local.tags
}

resource "azurerm_storage_account" "tfstate" {
  name                = "st${var.project}tf${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.tfstate.name
  location            = azurerm_resource_group.tfstate.location

  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"

  # Hardening
  min_tls_version                 = "TLS1_2"
  https_traffic_only_enabled      = true
  allow_nested_items_to_be_public = false
  shared_access_key_enabled       = false
  public_network_access_enabled   = true

  blob_properties {
    versioning_enabled = true

    delete_retention_policy {
      days = 30
    }
  }

  tags = local.tags
}

# Subscription Owner does NOT include storage data-plane access. Without this,
# creating containers and reading state both fail. This grants the human
# operator account-wide; per-environment CI identities get container-scoped
# assignments once those identities exist.
resource "azurerm_role_assignment" "operator_blob" {
  scope                = azurerm_storage_account.tfstate.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = data.azurerm_client_config.current.object_id
}

# RBAC is eventually consistent; container creation otherwise races it.
resource "time_sleep" "rbac_propagation" {
  depends_on      = [azurerm_role_assignment.operator_blob]
  create_duration = "60s"
}

resource "azurerm_storage_container" "tfstate" {
  for_each = local.state_containers

  name                  = "tfstate-${each.key}"
  storage_account_id    = azurerm_storage_account.tfstate.id
  container_access_type = "private"

  depends_on = [time_sleep.rbac_propagation]
}
