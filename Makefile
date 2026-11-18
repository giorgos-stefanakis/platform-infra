KIND_CLUSTER_DIR   := iac/kind/cluster
KIND_BOOTSTRAP_DIR := iac/kind/bootstrap
TERRAFORM_ROOTS    := $(KIND_CLUSTER_DIR) $(KIND_BOOTSTRAP_DIR)

TF_APPLY   := apply -input=false -auto-approve
TF_DESTROY := destroy -input=false -auto-approve
GIT_TOKEN_ENV = TF_VAR_git_token="$$(gh auth token)"

.PHONY: kind-up kind-seed kind-down lint

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

lint:
	terraform fmt -check -recursive iac
	for root in $(TERRAFORM_ROOTS); do \
		terraform -chdir=$$root init -input=false -backend=false >/dev/null && \
		terraform -chdir=$$root validate || exit 1; \
	done
	tflint --init
	tflint --recursive
	helm lint components -f clusters/kind/components.yaml --set repoURL=lint,revision=lint
