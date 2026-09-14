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

variable "dns_zone_name" {
  description = <<-EOT
    Public DNS zone for this environment, delegated from rwa.dk at Simply.com.

    Delegation is a manual paste of the zone's name servers. Destroying and
    re-creating the zone returns a *different* NS set, which is the single
    biggest reason this tier is separate from the ephemeral one.
  EOT
  type        = string
  default     = "clouddemo.rwa.dk"
}

variable "operator_object_id" {
  description = <<-EOT
    Entra object ID of the human operator, granted Key Vault Administrator so
    the TLS certificate can be imported by hand.

    Needed as a variable rather than read from the running principal, because
    the persistent stack is applied by CI — data.azurerm_client_config would
    resolve to the deploy identity, not to a person.

      az ad signed-in-user show --query id -o tsv
  EOT
  type        = string
  default     = "c720b060-224d-40a3-9012-50a5c35f7a2d"
}
