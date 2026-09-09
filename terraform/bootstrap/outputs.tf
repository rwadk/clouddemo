output "resource_group_name" {
  description = "Resource group holding the Terraform state storage."
  value       = azurerm_resource_group.tfstate.name
}

output "storage_account_name" {
  description = "Storage account holding Terraform state."
  value       = azurerm_storage_account.tfstate.name
}

output "state_containers" {
  description = "Per-environment state containers."
  value       = { for k, c in azurerm_storage_container.tfstate : k => c.name }
}

output "backend_blocks" {
  description = "Backend block for each stack. Paste into the stack's versions.tf."
  value = {
    for k, c in azurerm_storage_container.tfstate : k => <<-EOT
      backend "azurerm" {
        resource_group_name  = "${azurerm_resource_group.tfstate.name}"
        storage_account_name = "${azurerm_storage_account.tfstate.name}"
        container_name       = "${c.name}"
        key                  = "${k}.tfstate"
        use_azuread_auth     = true
      }
    EOT
  }
}

output "env_resource_groups" {
  description = "Resource groups created for each environment, by key."
  value       = { for k, rg in azurerm_resource_group.env : k => rg.name }
}

output "deploy_identity_client_ids" {
  description = <<-EOT
    Client ID per environment. Set each as an AZURE_CLIENT_ID *environment*
    variable on the matching GitHub environment — see terraform/README.md.
  EOT
  value       = { for k, id in azurerm_user_assigned_identity.deploy : k => id.client_id }
}

output "plan_identity_client_ids" {
  description = "Read-only client ID per environment, for the <env>-readonly GitHub environments."
  value       = { for k, id in azurerm_user_assigned_identity.plan : k => id.client_id }
}

## Principal IDs, not client IDs: role assignments key on the former.
##
## These travel to the env stacks as TF_VAR values rather than through state,
## because an env stack has no access to tfstate-bootstrap by design. Any AKS
## role assignment has to be made by the stack that owns the cluster, and this
## is how that stack learns who to grant.

output "deploy_identity_principal_ids" {
  description = "Principal ID per environment, for role assignments made by the env stacks."
  value       = { for k, id in azurerm_user_assigned_identity.deploy : k => id.principal_id }
}

output "plan_identity_principal_ids" {
  description = "Read-only principal ID per environment, for role assignments made by the env stacks."
  value       = { for k, id in azurerm_user_assigned_identity.plan : k => id.principal_id }
}

output "github_environment_variables" {
  description = "Copy-paste block of the GitHub configuration the workflows need."
  value = {
    repository_variables = {
      TFSTATE_RESOURCE_GROUP  = azurerm_resource_group.tfstate.name
      TFSTATE_STORAGE_ACCOUNT = azurerm_storage_account.tfstate.name
      AZURE_TENANT_ID         = data.azurerm_client_config.current.tenant_id
      AZURE_SUBSCRIPTION_ID   = data.azurerm_client_config.current.subscription_id
    }
    environment_variables = merge(
      { for k, id in azurerm_user_assigned_identity.deploy : k => { AZURE_CLIENT_ID = id.client_id } },
      { for k, id in azurerm_user_assigned_identity.plan : "${k}-readonly" => { AZURE_CLIENT_ID = id.client_id } },
    )
  }
}
