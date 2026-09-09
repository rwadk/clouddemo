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
  default     = "valdemo.rwa.dk"
}
