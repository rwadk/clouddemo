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

variable "enable_container_insights" {
  description = <<-EOT
    Container Insights on the AKS cluster. Off by default.

    At defaults it collects container stdout/stderr and performance counters —
    1-3 GB per day on a small cluster, which at 19.19 DKK/GB is several times
    the monthly budget. The exercise grades Defender for Cloud findings, not
    observability, so nothing here depends on it.

    A flag rather than an omission, so turning it on for one session is a
    variable change rather than an edit to the module call. The workspace's
    daily_quota_gb stays as the backstop when it is on.
  EOT
  type        = bool
  default     = false
}
