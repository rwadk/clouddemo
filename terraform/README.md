# Terraform layout

```
terraform/
├── bootstrap/          state storage. Local state → migrated into itself. Run once.
├── modules/
│   ├── network/        VNet, subnets, NSGs
│   ├── mongo-vm/       Ubuntu + MongoDB, backup timer, managed identity
│   ├── aks/            cluster, private nodes, workload identity
│   └── app-platform/   ingress-nginx, External Secrets, external-dns
└── envs/
    ├── val/            calls modules — 1 node, SSH restricted
    └── prd/            calls modules — 2 nodes, SSH exposed
```

## Environments share nothing

`val` and `prd` each get their own resource group, VNet, AKS cluster, Mongo VM,
storage account, Key Vault, Log Analytics workspace, DNS zone and deploy
identity. There is no shared resource between them.

Three things are common by necessity or design:

| | Why |
|---|---|
| The subscription | Only one exists. Resource-group separation plus per-environment scoped identities is the real boundary. |
| **The container image** | Deliberate. A promotion pipeline exists to deploy the byte-identical artifact that was tested. |
| State storage account | Meta-infrastructure. Isolated by a container per environment with container-scoped RBAC, so the val deploy identity cannot read prd state. |

**Root configs per environment, not Terraform workspaces.** Workspaces hide
which environment you are pointed at behind CLI state — precisely the mistake to
avoid in a pipeline that can reach production. `envs/prd` is unambiguous in a
diff, in a plan, and on a slide.

## DNS

Two sibling zones, each delegated independently from `rwa.dk` at Simply.com, so
neither environment's records live inside the other's zone:

| Environment | Hostname |
|---|---|
| prd | `clouddemo.rwa.dk` |
| val | `valdemo.rwa.dk` |

Each zone has its own external-dns workload identity, RBAC-scoped to that zone
alone. No DNS credential exists inside either cluster.

## The SSH exposure toggle

The exercise requires SSH exposed to the public internet. That is a live risk:
an EOL Ubuntu image holding a managed identity that can create VMs, on a
subscription with no spending limit.

So it is a flag, not a hardcoded rule — `modules/mongo-vm` takes
`ssh_expose_publicly`, defaulting to **false**. Wire it from a GitHub
repository variable so it can be toggled from the UI without a commit:

```yaml
# .github/workflows/infra.yml
env:
  TF_VAR_ssh_expose_publicly: ${{ vars.SSH_EXPOSE_PUBLICLY }}
```

Restricted while building; open for scanning, evidence and the demo.

Two notes for the demo:

- Toggling the variable and re-running the workflow is itself a good live
  moment — the vulnerability appearing and disappearing under version control.
- **Defender for Cloud findings are not instant.** Recommendations can take
  tens of minutes to refresh, so turn exposure on well before the panel rather
  than expecting the finding to surface live.

Password authentication stays disabled in both states. "SSH exposed to the
internet" is satisfied by the open NSG rule; adding password auth only shortens
the time to compromise.

## Applying

Every stack uses the remote backend created by `bootstrap/` — see
`bootstrap/README.md` for the one-time setup and state migration.

```sh
cd envs/val    # or envs/prd
terraform init
terraform plan
terraform apply
```
