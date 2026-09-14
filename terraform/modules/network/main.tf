## Addressing only — one VNet, two subnets.
##
## What is deliberately NOT here:
##
##   The NSG. Its two rules are about the Mongo VM — SSH from the internet on a
##   toggle, 27017 from the AKS subnet and nowhere else — so modules/mongo-vm
##   owns them, and this module exports the CIDR that second rule needs. That
##   keeps the boundary at "addressing" rather than splitting the VM's security
##   posture across two modules.
##
##   Any NSG on the AKS subnet. AKS manages its own rules in the MC_* node
##   resource group, and a second NSG on the same subnet is a good way to
##   produce traffic that is allowed by one and denied by the other.
##
## Both subnets are sized /24, which is ample because the cluster uses Azure CNI
## Overlay: pods draw from an overlay range, so the subnet only has to address
## nodes. Classic Azure CNI would size this by pod count instead.

locals {
  public_prefix = cidrsubnet(var.address_space, 8, 1)
  aks_prefix    = cidrsubnet(var.address_space, 8, 2)
}

resource "azurerm_virtual_network" "env" {
  name                = "vnet-${var.name_prefix}"
  resource_group_name = var.resource_group_name
  location            = var.location
  address_space       = [var.address_space]

  tags = var.tags
}

# Holds the Mongo VM's NIC. Public in the sense that the brief requires SSH to
# be reachable from the internet — not in the sense of a route table.
resource "azurerm_subnet" "public" {
  name                 = "snet-public"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.env.name
  address_prefixes     = [local.public_prefix]
}

# The private subnet the brief asks for. AKS node pools take no public IP by
# default, so "private nodes" comes from the cluster; what this subnet adds is
# a CIDR the Mongo VM's NSG can name, which is what makes "reachable only from
# Kubernetes" expressible as a rule rather than a claim.
resource "azurerm_subnet" "aks" {
  name                 = "snet-aks"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.env.name
  address_prefixes     = [local.aks_prefix]
}
