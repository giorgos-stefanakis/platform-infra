# platform-infra

Infrastructure and GitOps definitions that run one application stack on clusters with different infrastructure.

| Cluster | Represents | Infrastructure installed here |
|---|---|---|
| `kind` | A bare-metal client with no existing stack | Cilium, Envoy Gateway, OpenEBS, SeaweedFS, HashiCorp Vault |
| `aks` | A client with its own AKS stack | Traefik, cert-manager; AKS provides Cilium, storage, Blob and Key Vault |

Both clusters run the same application platform (External Secrets Operator, CloudNativePG, RabbitMQ Cluster Operator)
and the same application chart. Only the values in `clusters/<cluster>/` differ.

## Layout

```
iac/
  modules/bootstrap/   Cilium (optional), Argo CD, repository credentials, root Application
  state/               Terraform state storage; local state, applied once
  shared/              Entra ID app registrations
  kind/                kind cluster, then the bootstrap module
  aks/                 Azure resources and AKS, then the bootstrap module
clusters/<cluster>/    components to install, their values, application values
components/<name>/     one Argo CD Application per component, upstream chart pinned
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

### Components

The root Application renders the Helm chart in `components/`. For each name in `clusters/<cluster>/components.yaml`
it creates the Applications in `components/<name>/application.yaml`. Each one pins its upstream chart and reads its
values from `clusters/<cluster>/values/<name>.yaml` when that file exists. Sync waves set the order: operators and
controllers first, then the resources that need them.

### Lint

```sh
make lint   # terraform fmt, validate and tflint
```
