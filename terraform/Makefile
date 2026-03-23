.PHONY: help init plan apply destroy validate fmt clean

ENV ?= kubeadm
ENV_DIR := envs/$(ENV)

help:
	@echo "Usage: make <target> ENV=<kubeadm|rke2>"
	@echo "Example: make plan ENV=rke2"

init:
	terraform -chdir=$(ENV_DIR) init

validate:
	terraform -chdir=$(ENV_DIR) validate

fmt:
	terraform fmt -recursive

plan:
	terraform -chdir=$(ENV_DIR) plan

apply:
	terraform -chdir=$(ENV_DIR) apply

destroy:
	terraform -chdir=$(ENV_DIR) destroy

clean:
	rm -rf $(ENV_DIR)/.terraform \
		$(ENV_DIR)/.terraform.lock.hcl \
		$(ENV_DIR)/terraform.tfstate \
		$(ENV_DIR)/terraform.tfstate.backup
