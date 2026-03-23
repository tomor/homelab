.PHONY: init plan apply destroy validate fmt clean

# Run once when setting up the directory, after changing providers/modules,
# or after pulling Terraform changes that affect dependencies.
init:
	terraform init

# Run after editing Terraform files to catch syntax and configuration errors.
validate:
	terraform validate

# Run before committing to keep Terraform files consistently formatted.
fmt:
	terraform fmt -recursive

# Run before apply to preview infrastructure changes safely.
plan:
	terraform plan

# Run after reviewing the plan to create or update infrastructure.
apply:
	terraform apply

# Run only when you intentionally want to remove managed infrastructure.
destroy:
	terraform destroy

# Run when you need to remove local Terraform cache and state files.
clean:
	rm -rf .terraform .terraform.lock.hcl terraform.tfstate terraform.tfstate.backup
