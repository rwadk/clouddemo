## Ephemeral tier — val.
##
## This is what CD applies and what infra-teardown destroys. Nothing here may
## be something whose loss costs a manual step: no DNS zone, no registry, no
## globally-unique name that has to be reused immediately.
##
## The resource group itself is *not* declared here. Bootstrap owns it, so that
## this stack's deploy identity holds Contributor on one resource group rather
## than on the subscription. Teardown empties the group; it never removes it.

data "azurerm_resource_group" "env" {
  name = "rg-${var.project}-${local.env}"
}

data "terraform_remote_state" "persistent" {
  backend = "azurerm"

  config = {
    resource_group_name  = var.state_resource_group_name
    storage_account_name = var.state_storage_account_name
    container_name       = var.state_container_name
    key                  = "${local.env}-persistent.tfstate"
    use_azuread_auth     = true
  }
}

locals {
  env         = "val"
  name_prefix = "${var.project}-${local.env}"

  tags = {
    project     = var.project
    environment = local.env
    lifecycle   = "ephemeral"
    managedby   = "terraform"
  }
}

## ---------------------------------------------------------------------------
## Observability
## ---------------------------------------------------------------------------

resource "azurerm_log_analytics_workspace" "env" {
  name                = "log-${local.name_prefix}"
  resource_group_name = data.azurerm_resource_group.env.name
  location            = data.azurerm_resource_group.env.location

  sku               = "PerGB2018"
  retention_in_days = 30

  tags = local.tags
}

## ---------------------------------------------------------------------------
## TODO — modules, in dependency order. See ../../README.md.
## ---------------------------------------------------------------------------
#
# module "network" {
#   source              = "../../modules/network"
#   name_prefix         = local.name_prefix
#   resource_group_name = data.azurerm_resource_group.env.name
#   location            = data.azurerm_resource_group.env.location
#   tags                = local.tags
# }
#
# module "mongo_vm" {
#   source                    = "../../modules/mongo-vm"
#   name_prefix               = local.name_prefix
#   resource_group_name       = data.azurerm_resource_group.env.name
#   location                  = data.azurerm_resource_group.env.location
#   subnet_id                 = module.network.public_subnet_id
#   aks_subnet_cidr           = module.network.aks_subnet_cidr
#   ssh_expose_publicly       = var.ssh_expose_publicly
#   ssh_admin_cidr            = var.ssh_admin_cidr
#   ssh_public_key            = var.ssh_public_key
#   backup_storage_account_id = data.terraform_remote_state.persistent.outputs.demo_storage_account_id
#   overpermissive_role_scope = data.azurerm_resource_group.env.id
#   tags                      = local.tags
# }
#
# module "aks" {
#   source              = "../../modules/aks"
#   name_prefix         = local.name_prefix
#   resource_group_name = data.azurerm_resource_group.env.name
#   location            = data.azurerm_resource_group.env.location
#   node_count          = var.node_count
#   subnet_id           = module.network.aks_subnet_id
#   log_analytics_id    = azurerm_log_analytics_workspace.env.id
#   tags                = local.tags
#
#   # No admin kubeconfig exists at all with this set, so Contributor on the
#   # resource group stops being a path to every secret in the cluster.
#   # Everything authenticates through Entra and Azure RBAC instead.
#   local_account_disabled = true
#   azure_rbac_enabled     = true
# }
#
# ## AKS is two access layers, and Reader only covers the first: it can see the
# ## cluster resource but cannot fetch a kubeconfig, let alone read objects.
# ## Both identities therefore need Cluster User; they differ in what the
# ## Kubernetes API then lets them do.
# ##
# ## Principal IDs arrive as TF_VAR values from the bootstrap outputs of the
# ## same name — this stack cannot read tfstate-bootstrap to look them up.
# ##
# ## Note RBAC Reader excludes Secrets by design. A kubernetes_secret or a
# ## secret-bearing helm_release will not diff under the plan identity, the same
# ## way Key Vault secret values do not. That is the correct trade.
#
# locals {
#   aks_roles = {
#     deploy_user   = { principal = var.deploy_identity_principal_id, role = "Azure Kubernetes Service Cluster User Role" }
#     deploy_writer = { principal = var.deploy_identity_principal_id, role = "Azure Kubernetes Service RBAC Writer" }
#     plan_user     = { principal = var.plan_identity_principal_id, role = "Azure Kubernetes Service Cluster User Role" }
#     plan_reader   = { principal = var.plan_identity_principal_id, role = "Azure Kubernetes Service RBAC Reader" }
#   }
# }
#
# resource "azurerm_role_assignment" "aks" {
#   for_each             = local.aks_roles
#   scope                = module.aks.cluster_id
#   role_definition_name = each.value.role
#   principal_id         = each.value.principal
#   principal_type       = "ServicePrincipal"
# }
#
# module "app_platform" {
#   source      = "../../modules/app-platform"
#   name_prefix = local.name_prefix
#   dns_zone_id = data.terraform_remote_state.persistent.outputs.dns_zone_id
#   depends_on  = [module.aks]
# }
