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
