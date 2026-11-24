# platform-infra

Infrastructure and GitOps definitions that run one application stack on clusters with different infrastructure.

| Cluster | Represents | Infrastructure installed here |
|---|---|---|
| `kind` | A bare-metal client with no existing stack | Cilium, Envoy Gateway, OpenEBS, SeaweedFS, HashiCorp Vault |
| `aks` | A client with its own AKS stack | Traefik, cert-manager; AKS provides Cilium, storage, Blob and Key Vault |
| `kind-flows` | Flows and customer integrations for the client Acme, on one node | Cilium, Envoy Gateway, OpenEBS, HashiCorp Vault |

`kind` and `aks` run the same application platform (External Secrets Operator, CloudNativePG, RabbitMQ Cluster
Operator) and the same application chart. Only the values in `clusters/<cluster>/` differ. `kind-flows` runs Flows
from the `flows` chart in this repository, with values from the client's GitOps repository (see
[kind-flows](#kind-flows)).

## Layout

```
iac/
  modules/bootstrap/   Cilium (optional), Argo CD, repository credentials, root Application
  state/               Terraform state storage; local state, applied once
  shared/              Entra ID app registration, container registry, managed identities
  kind/                kind cluster, then the bootstrap module
  kind-flows/          one-node kind cluster for Flows, then the bootstrap module
  aks/                 Azure resources and AKS, then the bootstrap module
clusters/<cluster>/    components to install, their values, application values
clusters/aks/client/   infrastructure the AKS client brings itself: Traefik, cert-manager, Key Vault secret store
components/<name>/     one Argo CD Application per component, upstream chart pinned
charts/flows/          Flows on Kubernetes, from the reference manifests of the Flows Kubernetes guide
```

Terraform owns everything up to and including Argo CD and the root Application. Argo CD owns everything after it.

## Prerequisites

Terraform, TFLint, kind, kubectl, Helm, Docker, Azure CLI, GitHub CLI.

## Usage

Argo CD reads both repositories with the token from `gh auth token`. The token is passed to Terraform at apply time
and is never written to git.

### kind

```sh
make kind-up     # create the cluster, then install Cilium, Argo CD and the root Application
make kind-seed   # initialise and unseal Vault, then write generated secret values
make kind-down   # remove all of it
```

`kind-up` runs two Terraform stages. `iac/kind/cluster` creates a one-node cluster without the default CNI and maps
host port 80 to the gateway NodePort. `iac/kind/bootstrap` installs the rest. Both stages keep local state.

Argo CD then syncs the components in `clusters/kind/components.yaml`. Vault starts sealed, so the components that read
secrets wait until `kind-seed` has run. Run `kind-seed` again after the cluster restarts to unseal Vault.

The unseal key and root token are kept in the `vault-init` Secret in the cluster. This is for the demo only.

The image is in the private registry. `iac/shared` creates a read-only pull token. `kind-seed` reads it from the
Terraform outputs, so run `shared-up` first. It writes the token to Vault, and the `registry-pull` component turns it
into the `registry-pull` image pull secret. AKS needs no such secret: the cluster identity can pull from the registry.

After a restart, the ExternalSecrets can stay in `SecretSyncedError` even once Vault is unsealed. Restart the
controller to retry at once:

```sh
kubectl --context kind-demo -n external-secrets rollout restart deploy/external-secrets
```

### kind-flows

Flows for the client Acme on one kind node, delivered by Argo CD from two repositories: the components and the
`flows` chart from this one, and the client's objects and values from
[client-acme-gitops](https://github.com/giorgos-stefanakis/client-acme-gitops) (`argocd/`). The `kind` cluster also
maps host port 80, so run only one of the two at a time.

```sh
make kind-flows-up     # create the cluster, install Cilium, Argo CD and the root Application, then seed Vault
make kind-flows-seed   # unseal Vault again after a restart
make kind-flows-down   # remove all of it
```

`FLOWS_REVISION` and `FLOWS_CLIENT_REVISION` choose the branches Argo CD syncs (default `main`).

`kind-flows-seed` generates the database passwords (`flows/database`) and the session secret (`flows/auth`) in Vault,
and writes the GitHub CLI token as the GHCR pull credential (`registry-pull`): the Flows images are private packages,
and the token needs `read:packages`.

The `flows` chart follows the reference manifests of the Flows guide *Deploying Flows on Kubernetes* (satori-flows
`docs/architecture/kubernetes.md`), with these choices:

- CloudNativePG runs PostgreSQL 18 in namespace `flows-db`. Its standard image carries pgvector. Bootstrap creates
  `flows` and the `vector` extension; a managed role and a `Database` create `flows_jobs`.
- The blob store and the connection vault key are on one ReadWriteOnce volume, mounted by every backend pod on the
  one node.
- `runtime.json` is rendered by an ExternalSecret from the chart's settings and the Vault values.
- The migrate Job is an Argo CD Sync hook in wave 3, after the database (waves 1 and 2) and before the workloads
  (wave 4). A PreSync hook would run before the database exists on the first install.
- Envoy Gateway routes `/api`, `/auth`, `/health` and `/v1` to the API and the rest to the web image.
- `default-deny` and `allow-flows` NetworkPolicies, plus one egress rule to every namespace labelled
  `flows.satori/integration: "true"`, so adding an integration never changes Flows.
- Sign-in uses local accounts in development mode at `http://localhost`. Guest login does not work in a cluster:
  Flows admits it only from a loopback client address, and the edition entrypoint refuses it.

### Azure

Sign in with `az login` to the right tenant. Terraform uses that session. Copy `.env.example` to `.env` and fill it
in; the Makefile loads `.env`, and git ignores it.

```sh
make shared-up   # once: state storage, then the Entra app registration, registry and identities
make aks-up      # AKS and its Azure resources, then Argo CD and the root Application
make aks-stop    # stop the cluster when idle
make aks-start
make aks-down    # remove what aks-up created
```

`shared-up` applies `iac/state` with local state, then `iac/shared` with its state in that storage account. Copy the
`shared-up` outputs into `clusters/*/values/`: the registry, the client IDs and the tenant.

The registry and the identities live in the shared stage, so the image reference and the client IDs stay the same
across `aks-down` and `aks-up`. The Key Vault holds `demo-api-key` and the Cloudflare token; Terraform writes both,
so they end up in the Terraform state.

### Components

The root Application renders the Helm chart in `components/`. For each name in `clusters/<cluster>/components.yaml`
it creates the Applications in `components/<name>/application.yaml`. Each one pins its upstream chart and reads its
values from `clusters/<cluster>/values/<name>.yaml` when that file exists. Sync waves set the order: operators and
controllers first, then the resources that need them.

On AKS the root Application also syncs `clusters/aks/client/`. In a real client cluster, the client installs these
itself; here they stand in for the client's stack.

### Lint

```sh
make lint   # terraform fmt, validate and tflint; helm lint of the components for each cluster
```

CI runs `make lint` on every push to `main` and on pull requests.
