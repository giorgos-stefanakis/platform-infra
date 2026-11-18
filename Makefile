# Local settings and secrets, not in git. See the README for the keys.
ifneq (,$(wildcard .env))
include .env
export $(shell sed -n 's/^\([A-Za-z_][A-Za-z0-9_]*\)=.*/\1/p' .env)
endif

KIND_CLUSTER_DIR   := iac/kind/cluster
KIND_BOOTSTRAP_DIR := iac/kind/bootstrap
STATE_DIR          := iac/state
SHARED_DIR         := iac/shared
AKS_CLUSTER_DIR    := iac/aks/cluster
AKS_BOOTSTRAP_DIR  := iac/aks/bootstrap
TERRAFORM_ROOTS    := $(KIND_CLUSTER_DIR) $(KIND_BOOTSTRAP_DIR) $(STATE_DIR) $(SHARED_DIR) $(AKS_CLUSTER_DIR) $(AKS_BOOTSTRAP_DIR)

AKS_NAME           := aks-demo
AKS_RESOURCE_GROUP := rg-demo-aks

TF_APPLY   := apply -input=false -auto-approve
TF_DESTROY := destroy -input=false -auto-approve
GIT_TOKEN_ENV = TF_VAR_git_token="$$(gh auth token)"

# Read from the state stage when used, so they work right after state-up.
STATE_RESOURCE_GROUP  = $(shell terraform -chdir=$(STATE_DIR) output -raw resource_group_name)
STATE_STORAGE_ACCOUNT = $(shell terraform -chdir=$(STATE_DIR) output -raw storage_account_name)
STATE_ENV = TF_VAR_state_resource_group_name=$(STATE_RESOURCE_GROUP) \
	TF_VAR_state_storage_account_name=$(STATE_STORAGE_ACCOUNT)

# $(call remote_init,<directory>,<state key>)
remote_init = terraform -chdir=$(1) init -input=false -reconfigure \
	-backend-config=resource_group_name=$(STATE_RESOURCE_GROUP) \
	-backend-config=storage_account_name=$(STATE_STORAGE_ACCOUNT) \
	-backend-config=container_name=tfstate \
	-backend-config=key=$(2).tfstate \
	-backend-config=use_azuread_auth=true

.PHONY: kind-up kind-seed kind-down state-up shared-up aks-up aks-stop aks-start aks-down lint

# kind

kind-up:
	terraform -chdir=$(KIND_CLUSTER_DIR) init -input=false
	terraform -chdir=$(KIND_CLUSTER_DIR) $(TF_APPLY)
	terraform -chdir=$(KIND_BOOTSTRAP_DIR) init -input=false
	$(GIT_TOKEN_ENV) terraform -chdir=$(KIND_BOOTSTRAP_DIR) $(TF_APPLY)

kind-seed:
	scripts/kind-seed.sh

kind-down:
	$(GIT_TOKEN_ENV) terraform -chdir=$(KIND_BOOTSTRAP_DIR) $(TF_DESTROY)
	terraform -chdir=$(KIND_CLUSTER_DIR) $(TF_DESTROY)

# Azure

state-up:
	terraform -chdir=$(STATE_DIR) init -input=false
	terraform -chdir=$(STATE_DIR) $(TF_APPLY)

shared-up: state-up
	$(call remote_init,$(SHARED_DIR),shared)
	terraform -chdir=$(SHARED_DIR) $(TF_APPLY)
	terraform -chdir=$(SHARED_DIR) output

aks-up:
	$(call remote_init,$(AKS_CLUSTER_DIR),aks-cluster)
	$(STATE_ENV) terraform -chdir=$(AKS_CLUSTER_DIR) $(TF_APPLY)
	$(call remote_init,$(AKS_BOOTSTRAP_DIR),aks-bootstrap)
	$(STATE_ENV) $(GIT_TOKEN_ENV) terraform -chdir=$(AKS_BOOTSTRAP_DIR) $(TF_APPLY)
	az aks get-credentials --name $(AKS_NAME) --resource-group $(AKS_RESOURCE_GROUP) --overwrite-existing

aks-stop:
	az aks stop --name $(AKS_NAME) --resource-group $(AKS_RESOURCE_GROUP)

aks-start:
	az aks start --name $(AKS_NAME) --resource-group $(AKS_RESOURCE_GROUP)

aks-down:
	$(call remote_init,$(AKS_BOOTSTRAP_DIR),aks-bootstrap)
	$(STATE_ENV) $(GIT_TOKEN_ENV) terraform -chdir=$(AKS_BOOTSTRAP_DIR) $(TF_DESTROY)
	$(call remote_init,$(AKS_CLUSTER_DIR),aks-cluster)
	$(STATE_ENV) terraform -chdir=$(AKS_CLUSTER_DIR) $(TF_DESTROY)

lint:
	terraform fmt -check -recursive iac
	for root in $(TERRAFORM_ROOTS); do \
		terraform -chdir=$$root init -input=false -backend=false >/dev/null && \
		terraform -chdir=$$root validate || exit 1; \
	done
	tflint --init
	tflint --recursive
	for cluster in kind aks; do \
		helm lint components -f clusters/$$cluster/components.yaml --set repoURL=lint,revision=lint || exit 1; \
	done
