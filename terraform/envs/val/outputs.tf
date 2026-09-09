output "resource_group_name" {
  description = "Resource group this environment deploys into."
  value       = data.azurerm_resource_group.env.name
}

output "log_analytics_workspace_id" {
  description = "Workspace ID — consumed by AKS and the Mongo VM's diagnostic settings."
  value       = azurerm_log_analytics_workspace.env.id
}

output "dns_zone_name" {
  description = "Public zone this environment publishes into, read from the persistent tier."
  value       = data.terraform_remote_state.persistent.outputs.dns_zone_name
}
