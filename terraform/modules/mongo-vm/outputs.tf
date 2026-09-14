output "private_ip" {
  description = "Private address. What the cluster connects to — the connection string is built from it."
  value       = azurerm_network_interface.vm.private_ip_address
}

output "public_ip" {
  description = "Public address. The SSH target, and what a scanner sees."
  value       = azurerm_public_ip.vm.ip_address
}

output "identity_principal_id" {
  description = "The VM's managed identity — the one holding Contributor."
  value       = azurerm_user_assigned_identity.vm.principal_id
}

output "ssh_command" {
  description = "Ready-to-paste SSH command, for the demo."
  value       = "ssh ${var.admin_username}@${azurerm_public_ip.vm.ip_address}"
}

output "nsg_name" {
  description = "NSG carrying the two rules. Useful for showing the toggle's effect."
  value       = azurerm_network_security_group.vm.name
}
