## Key Vault — persistent, not ephemeral.
##
## The tier test is "what does losing it cost?", and the answer here is a manual
## step: the TLS certificate for the prd hostname is issued and imported by
## hand. An ephemeral vault would mean re-importing it after every teardown,
## which is exactly the cost the persistent tier exists to avoid.
##
## What it holds:
##
##   the TLS certificate     imported by the operator, once
##   the MongoDB password    written by the VM at first boot, not by Terraform
##
## That second one is deliberate. If Terraform managed the secret, every plan
## would refresh it — and reading a secret's value is a data-plane operation
## that Reader does not grant, so every PR plan run by the <env>-readonly
## identity would fail. Fixing that by granting the plan identities
## Key Vault Secrets User would hand a read-only identity the ability to read
## live credentials, which is a worse trade than the tidiness it buys.
##
## Having the VM generate and store its own password also keeps the credential
## out of Terraform state, which holds values in plaintext.

resource "random_string" "kv_suffix" {
  length  = 4
  special = false
  upper   = false
}

resource "azurerm_key_vault" "env" {
  name                = "kv-${var.project}-${local.env}-${random_string.kv_suffix.result}"
  resource_group_name = data.azurerm_resource_group.persistent.name
  location            = data.azurerm_resource_group.persistent.location
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"

  # RBAC rather than access policies: one authorisation model across the whole
  # subscription instead of a second one that only applies here.
  rbac_authorization_enabled = true

  # Purge protection stays OFF on purpose. Once enabled it cannot be disabled,
  # and the vault name is then unusable for 90 days after a delete — which
  # turns a rebuild into a renaming exercise. Soft delete at the 7-day minimum
  # keeps an accidental delete recoverable without that trap.
  purge_protection_enabled   = false
  soft_delete_retention_days = 7

  tags = local.tags
}

# Whoever is applying. In CI that is this environment's deploy identity, which
# is what needs to grant the VM and the workload identities their access later.
resource "azurerm_role_assignment" "deploy_kv" {
  scope                = azurerm_key_vault.env.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azurerm_client_config.current.object_id
}

# The operator, explicitly. Subscription Owner grants nothing on the Key Vault
# data plane — the same gap bootstrap hit with blob storage — so importing the
# TLS certificate by hand needs its own assignment, and CI cannot stand in for a
# human here because the apply runs as the deploy identity.
resource "azurerm_role_assignment" "operator_kv" {
  scope                = azurerm_key_vault.env.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = var.operator_object_id
}
