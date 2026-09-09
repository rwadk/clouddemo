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

variable "github_repository" {
  description = <<-EOT
    owner/repo that federated credentials trust. Appears in the OIDC subject
    as repo:<owner>/<repo>:environment:<env>, so a token minted by any other
    repository will not match.
  EOT
  type        = string
  default     = "rwadk/clouddemo"
}
