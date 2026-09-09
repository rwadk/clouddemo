# Terraform layout

```
terraform/
├── bootstrap/          state storage, env resource groups, CD identities. Run once, by hand.
├── persistent/
│   ├── val/            DNS zone, registry, demo storage — survives teardown
│   └── prd/
├── envs/
│   ├── val/            calls modules — 1 node, SSH restricted
│   └── prd/            calls modules — 2 nodes, SSH exposed
└── modules/
    ├── network/        VNet, subnets, NSGs
    ├── mongo-vm/       Ubuntu + MongoDB, backup timer, managed identity
    ├── aks/            cluster, private nodes, workload identity
    └── app-platform/   ingress-nginx, External Secrets, external-dns
```

## Three lifecycle tiers

Which tier a resource belongs in is decided by one question: **what does losing
it cost?**

| Tier | Created by | Destroyed by teardown | Why |
|---|---|---|---|
| `bootstrap/` | a human, once | **never** | Holds the state every other stack reads, the resource groups they deploy into, and the identities CI runs as. Destroying it orphans everything else. |
| `persistent/` | `cd` | **no** | Losing any of it costs a manual step: DNS delegation is a paste at Simply.com, the container image must stay byte-identical across a promotion, a storage account name cannot be reused immediately. |
| `envs/` | `cd` | **yes** | Rebuilt from scratch in minutes. This is the entire teardown scope. |

The resource groups themselves belong to `bootstrap`, not to `envs`. Creating a
resource group requires Contributor at *subscription* scope; if each env stack
created its own, every deploy identity would hold subscription-wide rights and
the val/prd boundary would be decorative. So teardown empties an environment's
resource group and leaves the group standing, and `envs/*` reads it with
`data "azurerm_resource_group"`.

## Environments share nothing

`val` and `prd` each get their own resource groups, VNet, AKS cluster, Mongo VM,
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

## Identity

No client secret exists anywhere in this repository or in GitHub. Each
environment has a **user-assigned managed identity** with a federated
credential, created by `bootstrap`.

User-assigned identities rather than app registrations because a federated
credential on a UAMI is an ARM write, covered by subscription Owner, while the
same operation on an app registration is a *directory* write that subscription
Owner does not grant.

The federated subject is the control that matters:

```
repo:<owner>/<repo>:environment:val
repo:<owner>/<repo>:environment:prd
```

A workflow job can only exchange its GitHub token for the prd identity if the
job declares `environment: prd` — the job that sits behind the reviewer gate in
`.github/repo-config/environments.json`. Until that deployment is approved, no
prd credential exists to misuse. The approval is not advisory.

Each environment has **two** identities, because a plan is a read and should
not carry the rights of a write:

| | Deploy — `<env>` | Plan — `<env>-readonly` |
|---|---|---|
| Resource groups | Contributor + RBAC Administrator | Reader |
| State container | Storage Blob Data Contributor | Storage Blob Data **Reader** |
| Used by | apply, destroy | PR plans, the pre-approval prd plan, destroy plans |

RBAC Administrator is on the deploy identity because Contributor cannot create
role assignments, and the env stacks make several — the Mongo VM's identity,
external-dns, AKS.

Read-only plans run with `-lock=false`. Terraform's state lock is a blob lease,
which is a write, so Storage Blob Data Reader cannot take one — and a plan never
persists state, so there is nothing for the lock to protect.

### AKS needs two more roles

Reader covers the ARM view of a cluster — it does not get you a kubeconfig, and
it does not read a single Kubernetes object. Both are separate role
assignments, made by the env stack because it owns the cluster:

| | `<env>` | `<env>-readonly` |
|---|---|---|
| Fetch credentials | AKS Cluster User Role | AKS Cluster User Role |
| Kubernetes API | AKS RBAC Writer | AKS **RBAC Reader** |

Pair that with `local_account_disabled = true` on the cluster. Without it,
Contributor on the resource group can pull the *admin* kubeconfig and read
every secret in the cluster, which would make the deploy identity the most
over-permissioned thing in the environment. With it, no admin kubeconfig
exists and everything authenticates through Entra and Azure RBAC.

Note the principal IDs reach the env stack as `TF_VAR` values from bootstrap's
outputs, not through remote state — an env stack has no access to
`tfstate-bootstrap`, which is the point.

`Azure Kubernetes Service RBAC Reader` excludes Secrets. That is deliberate and
consistent with the Key Vault limit below.

Two limits of Reader worth knowing before they surprise you:

- Key Vault secret *values* are a data-plane read Reader does not grant, so a
  plan touching `azurerm_key_vault_secret` errors rather than diffing it.
  Granting the plan identity secret-read access to silence that would be worse
  than the gap it closes.
- Reader lacks `listKeys`. If a storage account in these groups ever enables
  shared-key auth, its refresh needs `Reader and Data Access` instead.

Note what is absent: no CI identity has any access to `tfstate-bootstrap`. The
Terraform that defines these permissions lives in a state file the deploy
identities cannot read or write, so a compromised pipeline cannot inspect or
widen its own grants.

## Workflows

CI turns source into a validated artifact. CD places a known-good artifact into
environments. Neither does the other's job.

| | Trigger | Does |
|---|---|---|
| `ci` | every PR | detects changed areas, plans val **and** prd read-only, builds without pushing |
| | push to `main` | builds, tests, pushes, hands a digest to CD |
| `cd` | called by `ci` | applies val → plans prd → applies prd behind its gate |
| | dispatch | redeploy, rollback, or test a change to `cd.yml` from a branch |
| `infra-teardown` | dispatch only | destroys `envs/<env>`, nothing else |

`bootstrap` appears in none of them. It runs by hand.

### Why the split

If CD knew how to build, the artifact would stop being the interface between
the two and every redeploy would mean a rebuild — which makes rollback a build
rather than a lookup. CD's contract is one line: *given a digest, converge both
environments onto it.*

The handoff is `workflow_call`, not `workflow_run`. `workflow_run` only ever
uses the workflow file on the default branch, so a change to `cd.yml` could not
be tested before merging it. OIDC federation was already only provable on a
real Actions run; adopting a trigger that makes CD changes unverifiable until
after merge is the wrong trade. `workflow_dispatch` still targets any branch,
so CD remains testable from a feature branch — which is also why
`deployment_branch_policy` stays null.

### `ci-ok` is the requireable check

A conditional job that skips reports no status, so requiring `plan` directly
would deadlock any PR that does not touch `terraform/` — the same trap the
ruleset comment describes for `reconcile`. `ci-ok` runs unconditionally and
passes when nothing *failed*, which is not the same as everything having run.

That is the check to add to the branch ruleset's `required_status_checks`.

### CI always emits a digest — it does not always build one

```
push to main
  app changed?
    yes → build, push sha-<commit>, move the `main` tag, emit that digest
    no  → resolve the `main` tag to its digest, emit that
  → cd.yml converges both environments onto it
```

A terraform-only change therefore deploys the image already running, and the
app deploy is a no-op. Making the digest optional instead would leave the app
unmanaged on those runs — half desired-state, half push-based.

Pinned by **digest, never tag**. A tag is mutable, so `:main` deployed to prd is
a promise; `@sha256:…` is a proof, and it is what makes the val→prd promotion
verifiable.

**A consequence worth knowing:** if an app change reaches val and its prd
approval is declined, prd stays on the older digest while the `main` tag moves
on. A later *terraform-only* push then carries the declined image into prd. What
catches it is the prd plan running before the gate — the image diff appears in
the plan the reviewer is approving. With a mutable tag it would be invisible.

### Nothing is approved unseen

```
apply val          val            Contributor
  ↓
plan prd           prd-readonly   Reader — no gate, cannot change anything
  ↓
apply prd          prd            Contributor, behind the reviewer gate
```

The reviewer opens the run, reads the actual prd plan — proposed changes and any
drift, refreshed against live prd — and then decides. The gate is not advisory:
prd's federated credential trusts `…:environment:prd`, so until the deployment
is approved the job holds no Azure credential at all.

`infra-teardown` has the same shape and needs it more: `guard` checks the typed
confirmation with no credential at all, a read-only job produces the **destroy**
plan, and only then is the reviewer asked. The approval is for a list of
resources you have read.

There is no way to reach prd without a green val first, and no dispatch input
that skips it.

### CD's three gates

| | Gate | Status |
|---|---|---|
| 1 | **Serialisation** — workflow-level `concurrency: cd` | active |
| 2 | **Recovery approval** — `cd-recovery` when the previous run failed | commented, needs the environment |
| 3 | **prd approval** — `environment: prd` | active |

Gate 1 has a limitation worth knowing: GitHub holds only **one** pending run per
group. A third run arriving while one waits cancels the waiting one as
superseded rather than queuing it. The real behaviour is "finish the current
run, then deploy the newest queued commit" — intermediate commits are skipped.
Usually what you want for CD, but it means a commit can pass CI and never be
deployed on its own.

Gate 2 pauses the **whole run**, not just prd. A failed CD run most likely
failed in val, because val runs first, and applying the next change on top of a
half-applied environment compounds the damage.

The job-level `env-<env>` groups are a separate concern from gate 1: they stop
CD colliding with `infra-teardown` on the same state. A job can only belong to
one group, so both layers exist.

### Still to do when the app lands

- **ACR needs a home.** The image is deliberately shared between environments,
  but `persistent/` is per-environment. A `persistent/shared/` stack is the
  honest place for it.
- **The deploy identity's AKS access needs narrowing.** Contributor on the
  resource group is enough to pull an *admin* kubeconfig, which reads every
  secret in the cluster. That wants `Azure Kubernetes Service Cluster User Role`
  plus in-cluster RBAC, and `local_account_disabled = true` on the cluster.

## DNS

Two sibling zones, each delegated independently from `rwa.dk` at Simply.com, so
neither environment's records live inside the other's zone:

| Environment | Hostname |
|---|---|
| prd | `clouddemo.rwa.dk` |
| val | `valdemo.rwa.dk` |

Each zone has its own external-dns workload identity, RBAC-scoped to that zone
alone. No DNS credential exists inside either cluster.

The zones live in `persistent/` and carry `prevent_destroy`. Delegation is a
manual paste of the zone's name servers; destroying and re-creating a zone
returns a *different* NS set, so a teardown that took the zone with it would
cost a trip to Simply.com and a propagation wait every single time.

## The SSH exposure toggle

The exercise requires SSH exposed to the public internet. That is a live risk:
an EOL Ubuntu image holding a managed identity that can create VMs, on a
subscription with no spending limit.

So it is a flag, not a hardcoded rule — `modules/mongo-vm` takes
`ssh_expose_publicly`, defaulting to **false**. It is wired from the
`SSH_EXPOSE_PUBLICLY` repository variable, so it can be toggled from the GitHub
UI and re-applied without a commit.

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

CD does this. To run a stack by hand, the backend is partial — the state
account's name carries a random suffix chosen by bootstrap — so `init` needs
the values `bootstrap` printed as `backend_blocks`:

```sh
cd envs/val
terraform init \
  -backend-config="resource_group_name=rg-clouddemo-tfstate" \
  -backend-config="storage_account_name=stclouddemotfXXXXXX" \
  -backend-config="container_name=tfstate-val" \
  -backend-config="key=val.tfstate" \
  -backend-config="use_azuread_auth=true"
terraform plan
```

`bootstrap` is the exception and is documented in `bootstrap/README.md`.
