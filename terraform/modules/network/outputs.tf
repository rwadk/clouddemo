output "vnet_id" {
  description = "VNet resource ID."
  value       = azurerm_virtual_network.env.id
}

output "vnet_name" {
  description = "VNet name."
  value       = azurerm_virtual_network.env.name
}

output "public_subnet_id" {
  description = "Subnet the Mongo VM's NIC attaches to."
  value       = azurerm_subnet.public.id
}

output "aks_subnet_id" {
  description = "Subnet the AKS node pool runs in."
  value       = azurerm_subnet.aks.id
}

output "aks_subnet_cidr" {
  description = <<-EOT
    CIDR of the AKS subnet. Consumed by modules/mongo-vm as the only source
    permitted to reach MongoDB's port.
  EOT
  value       = azurerm_subnet.aks.address_prefixes[0]
}
