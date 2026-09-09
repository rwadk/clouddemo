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
