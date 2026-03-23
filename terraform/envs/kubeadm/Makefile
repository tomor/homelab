.PHONY: init plan apply destroy validate fmt clean

init:
	terraform init

validate:
	terraform validate

fmt:
	terraform fmt -recursive

plan:
	terraform plan

apply:
	terraform apply

destroy:
	terraform destroy

clean:
	rm -rf .terraform .terraform.lock.hcl terraform.tfstate terraform.tfstate.backup
