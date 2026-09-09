# Bootstrap — state, resource groups, CD identities

The root of the whole setup. It creates:

- the **storage account** holding Terraform state for every other stack, with
  one container per environment;
- the **resource groups** each environment deploys into — two per environment,
  one ephemeral and one persistent;
- the **user-assigned managed identities** CI runs as, their GitHub federated
  credentials, and their role assignments.

This is the only stack that starts on **local** state, because it creates the
storage that remote state lives in. After the first apply it migrates its own
state into the account it just created, so nothing is left un-managed.

Run once, per subscription. It never runs in CI — see *Access*, below.

## Access

Bootstrap does not get a credential; it borrows yours. The provider declares no
authentication, so it falls through to your Azure CLI session:

```
you own the subscription (Owner, from the tenant)
  → az login            interactive, MFA, nothing stored
  → terraform apply     in bootstrap/, as you
  → creates state storage, resource groups, CD identities
  → CD now has identities; bootstrap is not run again
```

Subscription Owner covers everything here **except** the storage data plane —
ARM Owner grants no blob access at all. That is why the stack assigns itself
`Storage Blob Data Contributor`, and why there is a 60-second wait before any
container is created.

If your account can see more than one tenant, use `az login --tenant <id>`.
`azurerm_role_assignment.operator_blob` binds to whoever runs the apply, so a
second operator running it silently moves that assignment.

## First run

```sh
cp terraform.tfvars.example terraform.tfvars   # set subscription_id
terraform init
terraform plan
terraform apply
```

## Migrate this stack's own state into the account it created

**Already done for this subscription** — `versions.tf` carries the real backend
block and the state lives in `tfstate-bootstrap`. What follows is what to repeat
on a fresh subscription, where the storage account does not exist yet.

1. Comment out the `backend "azurerm"` block in `versions.tf` so the first
   apply runs on local state, then apply.
2. Take the values from `terraform output backend_blocks` and fill the block
   back in, using `key = "bootstrap.tfstate"`. The storage account name carries
   a random suffix, so it differs per subscription.
3. Re-initialise and let Terraform copy the local state up:

```sh
terraform init -migrate-state
```

4. Confirm the prompt. Verify with `terraform plan` — it should report no
   changes. The local `terraform.tfstate` is now a stale copy and is gitignored.

## Wire up GitHub

`terraform output github_environment_variables` prints everything the workflows
need. Set the repository variables in `.github/repo-config/repo-config.json`
(`prune_variables` is true — an undeclared variable gets deleted on the next
reconcile), and the per-environment `AZURE_CLIENT_ID` in
`.github/repo-config/environments.json`:

| Where | Name |
|---|---|
| repository variable | `TFSTATE_RESOURCE_GROUP` |
| repository variable | `TFSTATE_STORAGE_ACCOUNT` |
| repository variable | `AZURE_TENANT_ID` |
| repository variable | `AZURE_SUBSCRIPTION_ID` |
| `val` environment variable | `AZURE_CLIENT_ID` |
| `prd` environment variable | `AZURE_CLIENT_ID` |
| `val-readonly` environment variable | `AZURE_CLIENT_ID` |
| `prd-readonly` environment variable | `AZURE_CLIENT_ID` |

Four GitHub environments, not two. `val-readonly` and `prd-readonly` are new
and must be declared in `environments.json` with **no reviewers** — their whole
purpose is to produce a plan before anyone is asked to approve anything:

```json
{ "name": "val-readonly", "wait_timer": 0, "prevent_self_review": false,
  "reviewers": [], "deployment_branch_policy": null,
  "variables": { "AZURE_CLIENT_ID": "..." }, "secrets": [] }
```

None of these are secrets. Under OIDC a client ID grants nothing on its own —
the federated subject is what authorises, and it names this repository and one
environment.

## Notes

- **Shared-key auth is disabled** on the account, so all access — including the
  Terraform backend — authenticates with Entra ID. That is why the provider sets
  `storage_use_azuread = true` and every other stack's backend needs
  `use_azuread_auth = true`.
- Subscription **Owner does not include storage data-plane access**. The stack
  assigns itself `Storage Blob Data Contributor`, with a 60-second wait because
  RBAC is eventually consistent and container creation otherwise races it.
- Blob versioning and a 30-day soft-delete window are enabled as a safety net
  against state corruption.
- This account is deliberately hardened, in explicit contrast to the demo
  storage account in the persistent stack, which the exercise requires to be
  publicly readable and listable.
- **The env resource groups are created here on purpose.** Creating a resource
  group needs Contributor at subscription scope. Making them here, once, as a
  human means each deploy identity gets Contributor on its own two groups
  instead — and teardown empties a group rather than deleting it.
- **No CI identity can reach `tfstate-bootstrap`.** The Terraform defining
  CI's permissions sits in a state file CI cannot read, so a compromised
  pipeline cannot inspect or widen its own grants.
