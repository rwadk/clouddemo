variable "name_prefix" {
  description = "Prefix for resource names, e.g. clouddemo-prd."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group to deploy into."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "subnet_id" {
  description = "Subnet the VM's NIC attaches to (the public subnet)."
  type        = string
}

variable "aks_subnet_cidr" {
  description = <<-EOT
    CIDR of the AKS node subnet. MongoDB's port is reachable from here and
    nowhere else — the exercise requires database access be restricted to
    Kubernetes network access only.
  EOT
  type        = string
}

## ---------------------------------------------------------------------------
## SSH exposure — deliberately a toggle
## ---------------------------------------------------------------------------
##
## The exercise requires SSH be exposed to the public internet. That is a real
## risk while the environment is running: an EOL Ubuntu image with a managed
## identity that can create VMs, on a subscription with no spending limit.
##
## Rather than hardcode the weakness, it is a flag. Restricted while building,
## open for scanning, demos and evidence. Driven from a GitHub repository
## variable (TF_VAR_ssh_expose_publicly), so it can be toggled from the UI and
## re-applied without a commit.
##
## Fails safe: default is restricted. Exposure must be opted into.

variable "ssh_expose_publicly" {
  description = <<-EOT
    When true, SSH is reachable from the public internet, as the exercise
    requires. When false, SSH is restricted to ssh_admin_cidr.
    Set via the TF_VAR_ssh_expose_publicly environment variable in CI.
  EOT
  type        = bool
  default     = false
}

variable "ssh_admin_cidr" {
  description = "Source CIDR permitted to reach SSH when ssh_expose_publicly is false."
  type        = string
}

variable "ssh_public_key" {
  description = <<-EOT
    Public key for the admin user. Password authentication is disabled
    regardless of exposure — 'SSH exposed to the internet' is satisfied either
    way, and password auth only shortens the time to compromise.
  EOT
  type        = string
}

## ---------------------------------------------------------------------------

variable "vm_size" {
  description = <<-EOT
    VM SKU. Bsv2 rather than the older Bs: Azure refuses additional quota for
    standardBSFamily (DeprecatedQuotaType), so the legacy B-series is capped at
    whatever a subscription starts with. Bsv2 is current generation, still
    burstable, and B2s_v2 carries 8 GiB against B2s's 4 GiB.
  EOT
  type        = string
  default     = "Standard_B2s_v2"
}

variable "os_image" {
  description = <<-EOT
    Deliberately outdated Linux image — the exercise requires 1+ year old.
    Ubuntu 20.04 LTS is past end of standard support.
  EOT
  type = object({
    publisher = string
    offer     = string
    sku       = string
    version   = string
  })
  default = {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts-gen2"
    version   = "latest"
  }
}

variable "mongodb_version" {
  description = "Deliberately outdated MongoDB version — 1+ year old, past EOL."
  type        = string
  default     = "5.0"
}

variable "backup_storage_account_id" {
  description = "Storage account the daily mongodump is written to."
  type        = string
}

variable "overpermissive_role_scope" {
  description = <<-EOT
    Scope for the VM managed identity's Contributor assignment. The exercise
    requires 'overly permissive CSP permissions (e.g. able to create VMs)'.
    Scoped to this environment's resource group rather than the subscription:
    still satisfies the requirement, still demonstrates the same privilege
    escalation, but a compromise cannot reach the other environment.
  EOT
  type        = string
}

variable "tags" {
  description = "Tags applied to all resources."
  type        = map(string)
  default     = {}
}
