## CD identities, and the resource groups they are allowed to touch.
##
## These live in bootstrap rather than in the environment stacks because of a
## chicken-and-egg: creating a resource group requires Contributor at
## *subscription* scope. If each env stack created its own resource group,
## every deploy identity would need subscription-wide rights and the val/prd
## boundary would be decorative. Bootstrap creates the groups once, running as
## the human operator, and grants each identity Contributor on its own two.
##
## The consequence, which the workflows depend on: teardown destroys the
## *contents* of an environment, never the resource group itself. The env
## stacks read their group with a data source.
##
## User-assigned managed identities rather than app registrations: federated
## credentials on a UAMI are an ARM write, covered by subscription Owner.
## Doing the same on an app registration is a directory write, which Owner
## does not grant. No client secret exists in either direction.

locals {
  # Each environment owns two resource groups: one whose contents teardown
  # destroys, and one that outlives it.
  env_resource_groups = merge([
    for env in var.environments : {
      "${env}-ephemeral"  = { env = env, name = "rg-${var.project}-${env}", lifecycle = "ephemeral" }
      "${env}-persistent" = { env = env, name = "rg-${var.project}-${env}-persistent", lifecycle = "persistent" }
    }
  ]...)

  # Contributor creates resources; it cannot create role assignments. The
  # env stacks make several — the Mongo VM's identity, external-dns, AKS — so
  # the deploy identity needs both roles or the apply fails halfway through.
  deploy_rg_roles = merge([
    for key, rg in local.env_resource_groups : {
      for role in ["Contributor", "Role Based Access Control Administrator"] :
      "${key}|${role}" => { env = rg.env, rg_key = key, role = role }
    }
  ]...)
}

resource "azurerm_resource_group" "env" {
  for_each = local.env_resource_groups

  name     = each.value.name
  location = var.location
  tags = merge(local.tags, {
    environment = each.value.env
    lifecycle   = each.value.lifecycle
  })
}

resource "azurerm_user_assigned_identity" "deploy" {
  for_each = toset(var.environments)

  name                = "id-${var.project}-deploy-${each.key}"
  resource_group_name = azurerm_resource_group.tfstate.name
  location            = var.location

  tags = merge(local.tags, { environment = each.key })
}

# The subject is the whole control. A workflow job can only exchange its token
# for this identity if the job declares `environment: <env>` — which for prd is
# the job that sits behind the reviewer gate in .github/repo-config/
# environments.json. Without the approval, no prd credential is ever minted.
resource "azurerm_federated_identity_credential" "deploy" {
  for_each = toset(var.environments)

  name = "github-environment-${each.key}"

  # No resource_group_name: the identity reference fully identifies the
  # credential, and the field is deprecated for removal in the next major
  # provider version. parent_id is likewise deprecated in favour of
  # user_assigned_identity_id.
  user_assigned_identity_id = azurerm_user_assigned_identity.deploy[each.key].id
  audience                  = ["api://AzureADTokenExchange"]
  issuer                    = "https://token.actions.githubusercontent.com"
  subject                   = "${var.github_oidc_subject_prefix}:environment:${each.key}"
}

resource "azurerm_role_assignment" "deploy_rg" {
  for_each = local.deploy_rg_roles

  scope                = azurerm_resource_group.env[each.value.rg_key].id
  role_definition_name = each.value.role
  principal_id         = azurerm_user_assigned_identity.deploy[each.value.env].principal_id

  # Skips the Entra lookup that otherwise races identity creation.
  principal_type = "ServicePrincipal"
}

# Container-scoped, not account-scoped. This is the val-cannot-read-prd-state
# boundary, and the reason bootstrap makes one container per environment.
#
# Note what is absent: no CI identity has any access to tfstate-bootstrap. The
# terraform that defines these very permissions lives in a state file the
# deploy identities cannot read or write, so a compromised pipeline cannot
# inspect or widen its own grants.
resource "azurerm_role_assignment" "deploy_state" {
  for_each = toset(var.environments)

  scope                = "${azurerm_storage_account.tfstate.id}/blobServices/default/containers/${azurerm_storage_container.tfstate[each.key].name}"
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.deploy[each.key].principal_id
  principal_type       = "ServicePrincipal"
}

## ---------------------------------------------------------------------------
## Read-only plan identities
## ---------------------------------------------------------------------------
##
## A plan is a read. Giving it the deploy identity meant every PR touching
## terraform/ briefly held Contributor on a whole environment, and it meant the
## prd reviewer approved a deployment without having seen its plan.
##
## So each environment gets a second identity with Reader, bound to a separate
## GitHub environment that has no reviewers:
##
##   repo:<owner>/<repo>:environment:val-readonly
##   repo:<owner>/<repo>:environment:prd-readonly
##
## PRs plan against val-readonly. Every push plans prd against prd-readonly
## *before* the approval gate, so the reviewer reads the actual prd plan —
## changes and drift — and then decides. Neither identity can write anything.
##
## Two known limits of Reader, both deliberate:
##
##   - Key Vault secret *values* are a data-plane read that Reader does not
##     grant, so a plan touching azurerm_key_vault_secret will error rather
##     than diff it. Granting the plan identity secret-read access to silence
##     that would be worse than the gap it closes.
##   - Reader lacks Microsoft.Storage/storageAccounts/listKeys/action. If a
##     storage account in these groups ever has shared-key auth enabled, its
##     refresh needs "Reader and Data Access" instead.

resource "azurerm_user_assigned_identity" "plan" {
  for_each = toset(var.environments)

  name                = "id-${var.project}-plan-${each.key}"
  resource_group_name = azurerm_resource_group.tfstate.name
  location            = var.location

  tags = merge(local.tags, { environment = each.key, role = "plan" })
}

resource "azurerm_federated_identity_credential" "plan" {
  for_each = toset(var.environments)

  name                      = "github-environment-${each.key}-readonly"
  user_assigned_identity_id = azurerm_user_assigned_identity.plan[each.key].id
  audience                  = ["api://AzureADTokenExchange"]
  issuer                    = "https://token.actions.githubusercontent.com"
  subject                   = "${var.github_oidc_subject_prefix}:environment:${each.key}-readonly"
}

resource "azurerm_role_assignment" "plan_rg" {
  for_each = local.env_resource_groups

  scope                = azurerm_resource_group.env[each.key].id
  role_definition_name = "Reader"
  principal_id         = azurerm_user_assigned_identity.plan[each.value.env].principal_id
  principal_type       = "ServicePrincipal"
}

# Data *Reader*, not Contributor. Enough to read the state blob and diff
# against it; not enough to take the lease Terraform would otherwise use as a
# state lock, which is why plan jobs run with -lock=false. A plan never
# persists state, so there is nothing for the lock to protect.
resource "azurerm_role_assignment" "plan_state" {
  for_each = toset(var.environments)

  scope                = "${azurerm_storage_account.tfstate.id}/blobServices/default/containers/${azurerm_storage_container.tfstate[each.key].name}"
  role_definition_name = "Storage Blob Data Reader"
  principal_id         = azurerm_user_assigned_identity.plan[each.key].principal_id
  principal_type       = "ServicePrincipal"
}
