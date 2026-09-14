output "resource_group_name" {
  description = "Persistent resource group for this environment."
  value       = data.azurerm_resource_group.persistent.name
}

output "dns_zone_name" {
  description = "Public DNS zone name."
  value       = azurerm_dns_zone.env.name
}

output "dns_zone_id" {
  description = "Zone ID — consumed by the ephemeral stack for the external-dns role assignment."
  value       = azurerm_dns_zone.env.id
}

output "dns_name_servers" {
  description = "Paste these at Simply.com to delegate the zone. Stable unless the zone is destroyed."
  value       = azurerm_dns_zone.env.name_servers
}

output "key_vault_id" {
  description = "Key Vault resource ID — consumed by the ephemeral stack for RBAC grants."
  value       = azurerm_key_vault.env.id
}

output "key_vault_uri" {
  description = "Vault URI. The Mongo VM writes its generated password here at first boot."
  value       = azurerm_key_vault.env.vault_uri
}

output "key_vault_name" {
  description = "Vault name."
  value       = azurerm_key_vault.env.name
}
