variable "subscription_id" {
  description = "Azure subscription ID to deploy into."
  type        = string
}

variable "location" {
  description = <<-EOT
    Azure region for bootstrap resources.

    Not westeurope: it is capacity-locked and refuses storage account creation
    with RequestDisallowedByAzure ("not accepting new customers"). northeurope
    takes storage but reports Standard_B2s_v2 as NotAvailableForSubscription,
    which the Mongo VM needs. swedencentral has both, and is nearest to
    Denmark.
  EOT
  type        = string
  default     = "swedencentral"
}

variable "project" {
  description = "Short project name, used in resource names and tags."
  type        = string
  default     = "clouddemo"
}

variable "environments" {
  description = <<-EOT
    Environments that get their own state container. Each gets an isolated
    container so a per-environment deploy identity can be granted access to
    its own state and nothing else.
  EOT
  type        = list(string)
  default     = ["val", "prd"]
}
