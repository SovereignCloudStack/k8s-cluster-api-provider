# Makefile

# set the env we used 
#ENVIRONMENT = gx-betacloud
ENVIRONMENT ?= gx-citycloud
#ENVIRONMENT = gx-scs
SHELL=/bin/bash
#ENVIRONMENT = gx-bc
OPENSTACK ?= openstack
USERNAME ?= ubuntu
CONSOLE = capi-mgmtcluster

# check for openstack credentials
NEED_OSCLOUD := $(shell test -z "$$OS_PASSWORD" -a -z "$$OS_CLOUD" && echo 1 || echo 0)
ifeq ($(NEED_OSCLOUD),1)
  export OS_CLOUD=$(ENVIRONMENT)
endif

# if enabled, use s3 for remote terraform state
ifneq (,$(wildcard ./minio.env))
  include minio.env
endif

init:
	@if [ ! -d .terraform/plugins ]; then terraform init; fi
	@terraform workspace select ${ENVIRONMENT} || terraform workspace new ${ENVIRONMENT}

attach: init
	@terraform import -var-file="environments/environment-$(ENVIRONMENT).tfvars" $(RESOURCE) $(PARAMS)

detach: init
	@terraform state rm $(RESOURCE) $(PARAMS)

state-push: init
	@terraform state push $(STATE)

dry-run: init
	@terraform plan -var-file="environments/environment-$(ENVIRONMENT).tfvars" $(PARAMS)

create: init
	@touch .deploy.$(ENVIRONMENT)
	@terraform apply -auto-approve -var-file="environments/environment-$(ENVIRONMENT).tfvars"

show: init
	@terraform show

clean: init
	@terraform destroy -auto-approve -var-file="environments/environment-$(ENVIRONMENT).tfvars" $(PARAMS)
	@terraform workspace select default
	@terraform workspace delete $(ENVIRONMENT)
	@rm -f .deploy.$(ENVIRONMENT) .deploy.MGMTCLUSTER_ADDRESS.$(ENVIRONMENT) .deploy.id_rsa.$(ENVIRONMENT)

fullclean:
	@./cleanup/cleanup.sh --verbose --full
	$(MAKE) clean

purge:
	@echo "Warning, going to delete ALL resources in $(ENVIRONMENT), even those that have not been created by the testbed. The SSH-Key capi-keypair will be removed for all projects."
	@read -p "Continue? (y/n) " -r; \
        if [[ ! $$REPLY =~ ^[Yy] ]]; \
        then \
			exit 1; \
        fi
	@openstack keypair delete capi-keypair || true
	@ospurge --purge-own-project --os-cloud $(ENVIRONMENT) --verbose
	@rm -f .deploy.$(ENVIRONMENT) .MGMT_ADDRESS.$(ENVIRONMENT)
	@rm -f .id_rsa.$(ENVIRONMENT)
	@terraform workspace select default 
	@terraform workspace delete -force $(ENVIRONMENT) || true
	@openstack keypair delete capi-keypair || true
	@ospurge --purge-own-project --os-cloud $(ENVIRONMENT) --verbose

list: init
	@terraform state list

ssh:    .deploy.MGMTCLUSTER_ADDRESS.$(ENVIRONMENT) .deploy.id_rsa.$(ENVIRONMENT)
	@source ./.deploy.MGMTCLUSTER_ADDRESS.$(ENVIRONMENT); \
	ssh -o StrictHostKeyChecking=no -i .deploy.id_rsa.$(ENVIRONMENT) $(USERNAME)@$$MGMTCLUSTER_ADDRESS

login: ssh

deploy: .deploy.MGMTCLUSTER_ADDRESS.$(ENVIRONMENT) .deploy.id_rsa.$(ENVIRONMENT)
	@source ./.deploy.MGMTCLUSTER_ADDRESS.$(ENVIRONMENT); \
	ssh -o StrictHostKeyChecking=no -i .deploy.id_rsa.$(ENVIRONMENT) $(USERNAME)@$$MGMTCLUSTER_ADDRESS "bash deploy.sh"

log:    .deploy.$(ENVIRONMENT)
	@$(OPENSTACK) console log show $(CONSOLE)

console:   .deploy.$(ENVIRONMENT)
	@xdg-open $$( $(OPENSTACK) console url show $(CONSOLE) -f value -c url )

.deploy.$(ENVIRONMENT): init
	@STAT=$$(terraform state list); \
	if test -n "$$STAT"; then touch .deploy.$(ENVIRONMENT); else echo 'please, use "make create"'; exit 1; fi

.deploy.MGMTCLUSTER_ADDRESS.$(ENVIRONMENT): .deploy.$(ENVIRONMENT)
	@MGMTCLUSTER_ADDRESS=$$(terraform output mgmtcluster_address); \
	echo "MGMTCLUSTER_ADDRESS=$$MGMTCLUSTER_ADDRESS" > $@;

.deploy.id_rsa.$(ENVIRONMENT): .deploy.$(ENVIRONMENT)
	@PRIVATE_KEY=$$(terraform output private_key); \
	echo "$$PRIVATE_KEY" > $@; \
        chmod 0600 $@

watch: .deploy.id_rsa.$(ENVIRONMENT) .deploy.MGMTCLUSTER_ADDRESS.$(ENVIRONMENT)
	@source ./.deploy.MGMTCLUSTER_ADDRESS.$(ENVIRONMENT); \
	DISP=0; \
	if test "$$COLORTERM" = "1"; then \
	  GREEN=$$(echo -e "\e[0;32m"); \
	  GREENBOLD=$$(echo -e "\e[1;32m"); \
	  BOLD=$$(echo -e "\e[0;1m"); \
	  RED=$$(echo -e "\e[0;31m"); \
	  YELLOW=$$(echo -e "\e[0;33m"); \
	  NORM=$$(echo -e "\e[0;0m"); \
	fi; \
	while true; do \
		LEN=$$(ssh -o StrictHostKeyChecking=no -i .deploy.id_rsa.$(ENVIRONMENT) $(USERNAME)@$$MGMTCLUSTER_ADDRESS sudo wc -l /var/log/cloud-init-output.log 2>/dev/null); \
		LEN=$${LEN%% *}; \
		if test -n "$$LEN" -a "$$LEN" != "$$DISP"; then \
		  OUT=$$(ssh -o StrictHostKeyChecking=no -i .deploy.id_rsa.$(ENVIRONMENT) $(USERNAME)@$$MGMTCLUSTER_ADDRESS sudo tail -n $$((LEN-DISP)) /var/log/cloud-init-output.log 2>/dev/null); \
		  echo -e "$$OUT" | \
		    sed -e "s/^\(TASK.*\)$$/$$BOLD\1$$NORM/" \
		        -e "s/^\(PLAY.*\)$$/$$GREEN\1$$NORM/" \
			-e "s/^\(The system is finally up.*\)$$/$$GREENBOLD\1$$NORM/" \
			-e "s/\(FAILED\)/$$RED\1$$NORM/g" \
			-e "s/\(failed=[1-9][0-9]*\|unreachable=[1-9][0-9]*\)/$$RED\1$$NORM/g" \
			-e "s/\(warn\|WARN\|RETRYING\)/$$YELLOW\1$$NORM/" \
			-e "s/\(ok:\|ok=[0-9]*\)/$$GREEN\1$$NORM/"; \
		  if echo "$$OUT" | grep '^The system is finally up' >/dev/null 2>&1; then break; fi; \
		  DISP=$$LEN; \
		  sleep 5; \
		fi; \
	done;

openstack: init
	@$(OPENSTACK)

k9s: .deploy.MGMTCLUSTER_ADDRESS.$(ENVIRONMENT) .deploy.id_rsa.$(ENVIRONMENT)
	@source ./.deploy.MGMTCLUSTER_ADDRESS.$(ENVIRONMENT); \
	ssh -t -o StrictHostKeyChecking=no -i .deploy.id_rsa.$(ENVIRONMENT) $(USERNAME)@$$MGMTCLUSTER_ADDRESS \
	"KUBECONFIG=/etc/rancher/k3s/k3s.yaml:/home/ubuntu/workload-cluster.yaml k9s --all-namespaces"

PHONY: clean console attach detach ssh dry-run list deploy watch openstack create log console login k9s 
