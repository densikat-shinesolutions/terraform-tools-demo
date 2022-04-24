APPDIR := service
INFRADIR := infra
ENV?=dev

.PHONY: build fmt

fmt:
	cd $(APPDIR) && go fmt

build: fmt
	cd $(APPDIR) && env GOOS=linux GOARCH=amd64 go build .
	cd $(APPDIR) && env GOOS=darwin GOARCH=amd64 go build -o demoservice-mac

plan-account:
	cd infra/account && terraform plan -var-file="$(ENV).tfvars"

deploy-account:
	cd infra/account && terraform apply -var-file="$(ENV).tfvars"

destroy-account:
	cd infra/account && terraform destroy -var-file="$(ENV).tfvars"

plan-application:
	cd infra/application && terraform plan -var-file="$(ENV).tfvars"

deploy-application:
	cd infra/application && terraform apply -var-file="$(ENV).tfvars"

destroy-application:
	cd infra/application && terraform destroy -var-file="$(ENV).tfvars"
