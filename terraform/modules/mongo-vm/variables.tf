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
    VM SKU. Quota, not preference, has picked this twice — and quota is per
    region, so it had to be picked again after the move to Sweden Central.

    West Europe: standardBSFamily refuses additional quota (DeprecatedQuotaType),
    so the legacy B-series is capped at whatever a subscription starts with.
    Bsv2 was granted 30 there.

    Sweden Central: the reverse. standardBsv2Family returns
    QuotaNotAvailableForResource at every value tried — capacity, not the number
    asked for — while the legacy family sits at its unraisable default of 10.
    DASv4 and DSv3 also now refuse with DeprecatedQuotaType.

    standardDsv6Family was granted 20. D2s_v6 keeps the 8 GiB that B2s_v2 had,
    is current generation, and costs 0.687 DKK/hr against B2s_v2's 0.554 — which
    is cheaper than halving RAM, or than running at exactly 10 of 10 vCPU with
    no room for an AKS surge node during a node-pool upgrade.
  EOT
  type        = string
  default     = "Standard_D2s_v6"
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
