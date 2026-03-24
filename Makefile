.PHONY: help init plan apply destroy start stop validate fmt clean ansible-inventory ansible-push-files ansible-rke2-cluster

E ?= rke2
TERRAFORM_DIR := terraform
ENV_DIR := $(TERRAFORM_DIR)/envs/$(E)
TF_PARALLELISM ?= 1

help: ## Show this help output.
	@echo "Usage: make <target> E=<kubeadm|rke2>"
	@echo "Example: make plan E=rke2"
	@echo "Example: make apply E=rke2 TF_PARALLELISM=1"
	@echo "Example: make start E=rke2"
	@echo ""
	@awk 'BEGIN {FS = ":.*## "}; /^[a-zA-Z0-9_-]+:.*## / {printf "  %-9s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

init: ## Initialize the selected environment.
	terraform -chdir=$(ENV_DIR) init

validate: ## Validate the selected environment.
	terraform -chdir=$(ENV_DIR) validate

fmt: ## Format Terraform files.
	terraform -chdir=$(TERRAFORM_DIR) fmt -recursive

plan: ## Show the execution plan for the selected environment.
	terraform -chdir=$(ENV_DIR) plan

apply: ## Apply changes to the selected environment.
	terraform -chdir=$(ENV_DIR) apply -parallelism=$(TF_PARALLELISM)

destroy: ## Tear down the selected environment.
	terraform -chdir=$(ENV_DIR) destroy

start: ## Start the Multipass VMs for the selected environment.
	@VM_NAMES="$$(python3 scripts/terraform-vm-names.py "$(ENV_DIR)")"; \
	multipass start $$VM_NAMES

stop: ## Stop the Multipass VMs for the selected environment.
	@VM_NAMES="$$(python3 scripts/terraform-vm-names.py "$(ENV_DIR)")"; \
	multipass stop $$VM_NAMES

clean: ## Remove local Terraform state and cache for the selected environment.
	rm -rf $(ENV_DIR)/.terraform \
		$(ENV_DIR)/.terraform.lock.hcl \
		$(ENV_DIR)/terraform.tfstate \
		$(ENV_DIR)/terraform.tfstate.backup

ansible-inventory: ## Show the Ansible inventory for the selected environment.
	@ANSIBLE_CONFIG=ansible/ansible.cfg ANSIBLE_TF_ENV=$(E) uv run --project ansible ansible-inventory \
		-i ansible/inventory/terraform_inventory.py --list

ansible-push-files: ## Push repo helper files into /home/ubuntu on the selected environment.
	@ANSIBLE_CONFIG=ansible/ansible.cfg ANSIBLE_TF_ENV=$(E) uv run --project ansible ansible-playbook \
		-i ansible/inventory/terraform_inventory.py ansible/playbooks/push-files.yml

ansible-rke2-cluster: ## Bootstrap or reconcile the RKE2 cluster via Ansible.
	@test "$(E)" = "rke2" || { echo "ansible-rke2-cluster requires E=rke2"; exit 1; }
	@ANSIBLE_CONFIG=ansible/ansible.cfg ANSIBLE_TF_ENV=rke2 uv run --project ansible ansible-playbook \
		-i ansible/inventory/terraform_inventory.py ansible/playbooks/rke2-cluster.yml
