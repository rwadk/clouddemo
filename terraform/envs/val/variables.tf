variable "project" {
  description = "Short project name, used in resource names and tags."
  type        = string
  default     = "clouddemo"
}

variable "location" {
  description = "Azure region."
  type        = string
  default     = "swedencentral"
}

variable "node_count" {
  description = "AKS node count for this environment."
  type        = number
  default     = 1
}

## ---------------------------------------------------------------------------
## Remote state of the persistent tier
## ---------------------------------------------------------------------------
##
## Both tiers share this environment's state container; they differ by key.
## Container-scoped RBAC means this stack can read the persistent stack's
## state, and cannot read the other environment's at all.

variable "state_resource_group_name" {
  description = "Resource group of the Terraform state storage account."
  type        = string
}

variable "state_storage_account_name" {
  description = "Terraform state storage account, from the bootstrap output."
  type        = string
}

variable "state_container_name" {
  description = "State container for this environment."
  type        = string
  default     = "tfstate-val"
}

## ---------------------------------------------------------------------------
## SSH exposure — see terraform/README.md
## ---------------------------------------------------------------------------

variable "ssh_expose_publicly" {
  description = <<-EOT
    When true, the Mongo VM's SSH is reachable from the public internet, as the
    exercise requires. Fails safe: exposure must be opted into. Driven from the
    SSH_EXPOSE_PUBLICLY repository variable via TF_VAR_ssh_expose_publicly.
  EOT
  type        = bool
  default     = false
}

variable "ssh_admin_cidr" {
  description = "Source CIDR permitted to reach SSH when ssh_expose_publicly is false."
  type        = string
  default     = "0.0.0.0/32"
}
