## The Mongo VM — where three graded weaknesses live at once.
##
##   an end-of-life operating system and database
##   SSH reachable from the internet
##   a managed identity with rights it should not have
##
## Each is required by the brief. Each is scoped so the blast radius stops at
## one environment, and each carries its reasoning next to it rather than in a
## commit message nobody will read.

locals {
  # The single rule pair that resolves an apparent contradiction in the brief:
  # "SSH exposed to the internet" and "database reachable only from Kubernetes"
  # are both true, because they are different ports with different sources.
  ssh_source = var.ssh_expose_publicly ? "0.0.0.0/0" : var.ssh_admin_cidr
}

resource "azurerm_user_assigned_identity" "vm" {
  name                = "id-${var.name_prefix}-mongo"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags
}

## ---------------------------------------------------------------------------
## The over-permissive role — required, and deliberately bounded
## ---------------------------------------------------------------------------
##
## The brief asks for "overly permissive permissions (e.g. able to create VMs)".
## Contributor satisfies that literally. What is not required is the usual way
## people write it: at subscription scope.
##
## Scoped to this environment's resource group, the privilege escalation is
## identical to demonstrate — compromise the VM, use its identity, create more
## VMs — but a compromise cannot reach the other environment, the Terraform
## state, or the CD identities.
resource "azurerm_role_assignment" "vm_overpermissive" {
  scope                = var.overpermissive_role_scope
  role_definition_name = "Contributor"
  principal_id         = azurerm_user_assigned_identity.vm.principal_id
  principal_type       = "ServicePrincipal"
}

# Write, not read: the VM generates its own credential and stores it. Nothing
# else ever holds that password — not Terraform state, not a pipeline log, not
# cloud-init data readable through the Azure API.
resource "azurerm_role_assignment" "vm_key_vault" {
  scope                = var.key_vault_id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = azurerm_user_assigned_identity.vm.principal_id
  principal_type       = "ServicePrincipal"
}

## ---------------------------------------------------------------------------
## Network
## ---------------------------------------------------------------------------

# Static, so the SSH target and any scanner evidence survive a reboot. A
# dynamic address would change under the demo.
resource "azurerm_public_ip" "vm" {
  name                = "pip-${var.name_prefix}-mongo"
  resource_group_name = var.resource_group_name
  location            = var.location
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_network_security_group" "vm" {
  name                = "nsg-${var.name_prefix}-mongo"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags

  # Required to be open by the brief, and a real risk while it is: an EOL image
  # holding an identity that can create VMs. So it is a flag defaulting to
  # restricted, not a hardcoded rule — see variables.tf.
  security_rule {
    name                       = "ssh"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = local.ssh_source
    destination_address_prefix = "*"
  }

  # The other half of the pair. MongoDB is reachable from the AKS subnet and
  # nowhere else, which is where "database access restricted to Kubernetes" is
  # actually enforced — mongod itself binds 0.0.0.0.
  security_rule {
    name                       = "mongodb-from-aks"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "27017"
    source_address_prefix      = var.aks_subnet_cidr
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_interface" "vm" {
  name                = "nic-${var.name_prefix}-mongo"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.vm.id
  }
}

resource "azurerm_network_interface_security_group_association" "vm" {
  network_interface_id      = azurerm_network_interface.vm.id
  network_security_group_id = azurerm_network_security_group.vm.id
}

## ---------------------------------------------------------------------------
## The VM
## ---------------------------------------------------------------------------

resource "azurerm_linux_virtual_machine" "mongo" {
  name                  = "vm-${var.name_prefix}-mongo"
  resource_group_name   = var.resource_group_name
  location              = var.location
  size                  = var.vm_size
  admin_username        = var.admin_username
  network_interface_ids = [azurerm_network_interface.vm.id]
  tags                  = var.tags

  # "SSH exposed to the internet" is satisfied by the NSG rule above. Adding
  # password authentication would only shorten the time to compromise without
  # satisfying anything the brief asks for.
  disable_password_authentication = true

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.ssh_public_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
  }

  # Console output, reachable without a network path to the VM:
  #
  #   az vm boot-diagnostics get-boot-log -g <rg> -n <vm>
  #
  # The intended way in during the build is `az vm run-command invoke`, which
  # runs a script as root through the Azure agent and needs no open port at
  # all. This is the fallback for when the VM is broken enough that the agent
  # is not up either — cloud-init writes to the console, so a failed bootstrap
  # is still readable.
  #
  # Empty block means a managed storage account: no resource to declare, and
  # nothing to pay for.
  boot_diagnostics {}

  source_image_reference {
    publisher = var.os_image.publisher
    offer     = var.os_image.offer
    sku       = var.os_image.sku
    version   = var.os_image.version
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.vm.id]
  }

  # cloud-init is readable through the Azure API by anyone with Reader on the
  # VM, so it deliberately carries no secret — only the vault name to fetch
  # from and the identity to fetch as.
  custom_data = base64encode(templatefile("${path.module}/cloud-init.yaml.tftpl", {
    mongodb_database   = var.mongodb_database
    mongodb_version    = var.mongodb_version
    key_vault_name     = var.key_vault_name
    secret_name        = var.connection_string_secret_name
    identity_client_id = azurerm_user_assigned_identity.vm.client_id
  }))

  # The identity must be able to write to the vault before the VM boots and
  # tries to. cloud-init retries anyway, but this removes the race rather than
  # relying on the retry.
  depends_on = [azurerm_role_assignment.vm_key_vault]
}
