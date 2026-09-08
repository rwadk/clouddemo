# Bootstrap — Terraform remote state

Creates the storage account that holds Terraform state for every other stack.
This is the only stack that starts on **local** state, because it creates the
storage that remote state lives in. After the first apply it migrates its own
state into the account it just created, so nothing is left un-managed.

Run once, per subscription.

## First run

```sh
cp terraform.tfvars.example terraform.tfvars   # set subscription_id
terraform init
terraform plan
terraform apply
```

## Migrate this stack's own state into the account it created

1. Take the values from `terraform output backend_config`.
2. Uncomment the `backend "azurerm"` block in `versions.tf` and fill it in,
   using `key = "bootstrap.tfstate"`.
3. Re-initialise and let Terraform copy the local state up:

```sh
terraform init -migrate-state
```

4. Confirm the prompt. Verify with `terraform plan` — it should report no
   changes. The local `terraform.tfstate` is now a stale copy and is gitignored.

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
