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

variable "github_oidc_subject_prefix" {
  description = <<-EOT
    Subject prefix GitHub puts in the OIDC token, everything before
    ":environment:<name>".

    Deliberately not assembled from "repo:<owner>/<repo>". GitHub embeds
    immutable numeric owner and repository IDs, so the real prefix looks like
    repo:owner@13893807/repo@1361837722. Assembling the readable form yields a
    credential that never matches, and the resulting AADSTS700213 names the
    subject it wanted rather than the one to configure.

    Read it from the repository instead of guessing:

      gh api repos/OWNER/REPO/actions/oidc/customization/sub \
        --jq .sub_claim_prefix

    The IDs are a feature. Deleting this repository and recreating one with the
    same name produces different IDs, so the federated credential stops matching
    rather than silently trusting whatever now owns the name.
  EOT
  type        = string
  default     = "repo:rwadk@13893807/clouddemo@1361837722"
}
