#!/usr/bin/env bash
# Initialises and unseals Vault on the kind cluster, lets External Secrets Operator read it, and writes generated
# secret values. Safe to run again: it unseals after a restart and keeps existing values.
# REGISTRY_SERVER, REGISTRY_PULL_USERNAME and REGISTRY_PULL_PASSWORD, when set, are written as the registry pull
# credentials.
set -euo pipefail

context="${KUBE_CONTEXT:-kind-demo}"
namespace="vault"
pod="vault-0"
init_secret="vault-init"

kube() {
  kubectl --context "$context" "$@"
}

vault_exec() {
  kube exec -n "$namespace" "$pod" -- env VAULT_TOKEN="${root_token:-}" vault "$@"
}

wait_for_vault_pod() {
  echo "Waiting for $pod to run"
  until kube get pod -n "$namespace" "$pod" >/dev/null 2>&1; do
    sleep 5
  done
  kube wait pod -n "$namespace" "$pod" --for=jsonpath='{.status.phase}'=Running --timeout=10m >/dev/null
}

vault_status() {
  # Exit code 2 means sealed; the JSON is still valid.
  vault_exec status -format=json 2>/dev/null || true
}

initialise() {
  echo "Initialising Vault"
  local init_json
  init_json="$(vault_exec operator init -key-shares=1 -key-threshold=1 -format=json)"
  # The unseal key stays in the cluster so the demo survives a restart. Not for production.
  kube create secret generic "$init_secret" -n "$namespace" \
    --from-literal=unseal-key="$(jq -r '.unseal_keys_b64[0]' <<<"$init_json")" \
    --from-literal=root-token="$(jq -r '.root_token' <<<"$init_json")" >/dev/null
}

read_init_value() {
  kube get secret "$init_secret" -n "$namespace" -o "jsonpath={.data.$1}" | base64 -d
}

enable_if_missing() {
  local kind="$1" path="$2" type="$3"
  if ! vault_exec "$kind" list -format=json | jq -e --arg path "$path/" 'has($path)' >/dev/null; then
    vault_exec "$kind" enable -path="$path" "$type"
  fi
}

put_if_missing() {
  local path="$1"
  shift
  if vault_exec kv get "secret/$path" >/dev/null 2>&1; then
    echo "Keeping secret/$path"
  else
    vault_exec kv put "secret/$path" "$@" >/dev/null
    echo "Wrote secret/$path"
  fi
}

wait_for_vault_pod

if [[ "$(vault_status | jq -r '.initialized')" != "true" ]]; then
  initialise
fi

if [[ "$(vault_status | jq -r '.sealed')" == "true" ]]; then
  echo "Unsealing Vault"
  vault_exec operator unseal "$(read_init_value unseal-key)" >/dev/null
fi

root_token="$(read_init_value root-token)"

echo "Configuring the secrets engine and Kubernetes auth"
enable_if_missing secrets secret kv-v2
enable_if_missing auth kubernetes kubernetes
vault_exec write auth/kubernetes/config kubernetes_host=https://kubernetes.default.svc >/dev/null

kube exec -i -n "$namespace" "$pod" -- env VAULT_TOKEN="$root_token" vault policy write external-secrets - >/dev/null <<'EOF'
path "secret/data/*" {
  capabilities = ["read"]
}
path "secret/metadata/*" {
  capabilities = ["read", "list"]
}
EOF

vault_exec write auth/kubernetes/role/external-secrets \
  bound_service_account_names=external-secrets \
  bound_service_account_namespaces=external-secrets \
  audience=vault \
  policies=external-secrets \
  ttl=1h >/dev/null

put_if_missing demo-api-key value="$(openssl rand -hex 24)"
put_if_missing object-store access_key_id="$(openssl rand -hex 10)" secret_access_key="$(openssl rand -hex 20)"
put_if_missing object-store-admin username=admin password="$(openssl rand -hex 16)"

if [[ -n "${REGISTRY_SERVER:-}" && -n "${REGISTRY_PULL_USERNAME:-}" && -n "${REGISTRY_PULL_PASSWORD:-}" ]]; then
  vault_exec kv put secret/registry-pull \
    server="$REGISTRY_SERVER" username="$REGISTRY_PULL_USERNAME" password="$REGISTRY_PULL_PASSWORD" >/dev/null
  echo "Wrote secret/registry-pull"
fi

echo "Vault is ready"
