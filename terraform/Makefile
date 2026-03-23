.PHONY: help init plan apply destroy validate fmt clean

E ?= rke2
ENV_DIR := envs/$(E)
TF_PARALLELISM ?= 1

help: ## Show this help output.
	@echo "Usage: make <target> E=<kubeadm|rke2>"
	@echo "Example: make plan E=rke2"
	@echo "Example: make apply E=rke2 TF_PARALLELISM=1"
	@echo ""
	@awk 'BEGIN {FS = ":.*## "}; /^[a-zA-Z0-9_-]+:.*## / {printf "  %-9s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

init: ## Initialize the selected environment.
	terraform -chdir=$(ENV_DIR) init

validate: ## Validate the selected environment.
	terraform -chdir=$(ENV_DIR) validate

fmt: ## Format Terraform files.
	terraform fmt -recursive

plan: ## Show the execution plan for the selected environment.
	terraform -chdir=$(ENV_DIR) plan

apply: ## Apply changes to the selected environment.
	terraform -chdir=$(ENV_DIR) apply -parallelism=$(TF_PARALLELISM)

destroy: ## Tear down the selected environment.
	terraform -chdir=$(ENV_DIR) destroy

clean: ## Remove local Terraform state and cache for the selected environment.
	rm -rf $(ENV_DIR)/.terraform \
		$(ENV_DIR)/.terraform.lock.hcl \
		$(ENV_DIR)/terraform.tfstate \
		$(ENV_DIR)/terraform.tfstate.backup
