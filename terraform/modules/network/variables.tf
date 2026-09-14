variable "name_prefix" {
  description = "Prefix for resource names, e.g. clouddemo-prd."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group to deploy into. Owned by bootstrap, not by this stack."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "address_space" {
  description = <<-EOT
    VNet address space. Subnets are derived from it rather than declared
    separately, so an environment is described by one CIDR.

    val and prd use non-overlapping ranges even though the VNets never peer.
    Keeping the option open costs nothing, and two environments with identical
    address space are confusing on a diagram.
  EOT
  type        = string
}

variable "tags" {
  description = "Tags applied to all resources."
  type        = map(string)
  default     = {}
}
