## Persistent tier — val.
##
## Everything here survives infra-teardown. What belongs: anything whose
## re-creation costs a manual step, a globally-unique name that cannot be
## reused immediately, or an artifact that must stay byte-identical across a
## promotion.
##
## Today that is the DNS zone. The container registry and the deliberately
## public demo storage account belong here too — see ../../README.md.

data "azurerm_resource_group" "persistent" {
  name = "rg-${var.project}-${local.env}-persistent"
}

locals {
  env = "val"

  tags = {
    project     = var.project
    environment = local.env
    lifecycle   = "persistent"
    managedby   = "terraform"
  }
}

resource "azurerm_dns_zone" "env" {
  name                = var.dns_zone_name
  resource_group_name = data.azurerm_resource_group.persistent.name
  tags                = local.tags

  # Teardown does not target this stack, but a mistyped -target or a future
  # refactor could. Delegation at Simply.com points at the name servers below;
  # losing the zone means re-delegating by hand and waiting out propagation.
  lifecycle {
    prevent_destroy = true
  }
}
