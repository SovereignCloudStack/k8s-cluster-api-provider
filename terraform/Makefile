# Makefile

# set the env we used
#ENVIRONMENT = gx-betacloud
#ENVIRONMENT ?= gx-citycloud
#ENVIRONMENT = gx-scs
SHELL = /bin/bash
SED ?= sed
#ENVIRONMENT = gx-bc
OPENSTACK ?= openstack
CONSOLE = $(PREFIX)-mgmtcluster

# check for openstack credentials
NEED_OSCLOUD := $(shell test -z "$$OS_PASSWORD" -a -z "$$OS_CLOUD" && echo 1 || echo 0)
ifeq ($(NEED_OSCLOUD),1)
  export OS_CLOUD=$(ENVIRONMENT)
else
  ENVIRONMENT ?= $(OS_CLOUD)
endif
USERNAME=$(shell ( grep '^ssh_username' environments/environment-$(ENVIRONMENT).tfvars || echo ubuntu ) | $(SED) 's@^ssh_username[^=]*= *"*\([^"]*\).*$$@\1@')

# if enabled, use s3 for remote tofu state
ifneq (,$(wildcard ./minio.env))
  include minio.env
endif

YQISJQ=$(shell yq --help | grep jq >/dev/null 2>&1 && echo 1)
ifeq ($(YQISJQ),1)
  YQ=yq --yaml-output
  YQIN=
else
  YQ=yq eval
  YQIN=-
endif

CLOUD=$(shell ( grep '^cloud_provider' environments/environment-$(ENVIRONMENT).tfvars || echo $(ENVIRONMENT) ) | $(SED) 's@^cloud_provider[^=]*= *"*\([^"]*\).*$$@\1@')
ifeq ($(TESTCLUSTER),)
TESTCLUSTER=$(shell ( grep '^testcluster_name' environments/environment-$(ENVIRONMENT).tfvars || echo testcluster ) | $(SED) 's@^testcluster_name[^=]*= *"*\([^"]*\).*$$@\1@')
endif

PREFIX=$(shell (grep '^prefix *=' environments/environment-${ENVIRONMENT}.tfvars || echo capi) | $(SED) -e 's/^[^=]*= *//' -e 's/"//g')
MGMTCLUSTERNAME=$(shell ($(OPENSTACK) --os-cloud $(ENVIRONMENT) server list --name "$(PREFIX)-mgmtcluster" -c Name -f value))

GITBRANCH=$(shell git branch | grep '^*' | $(SED) 's/^* //')
# Specify a branch, tag or commit to checkout on the mgmtcluster
GITREFERENCE=$(shell git rev-parse HEAD)
# GITREFERENCE=$GITBRANCH
GITREPO=$(shell git config --get remote.origin.url | $(SED) 's%git@\([^:]*\):%https://\1/%')

init: mycloud
	@if [ ! -d .terraform/providers ]; then tofu init; fi
	@tofu workspace select ${ENVIRONMENT} || tofu workspace new ${ENVIRONMENT}

attach: init
	@tofu import -var-file="environments/environment-$(ENVIRONMENT).tfvars" $(RESOURCE) $(PARAMS)

detach: init
	@tofu state rm $(RESOURCE) $(PARAMS)

state-push: init
	@tofu state push $(STATE)

dry-run: init
	tofu plan -var-file="environments/environment-$(ENVIRONMENT).tfvars" -var "git_reference=$(GITREFERENCE)" $(PARAMS)

mycloud: environments/environment-$(ENVIRONMENT).tfvars
	@if [ -f "clouds.yaml" ]; then \
		$(YQ) '.clouds."$(CLOUD)"' $(YQIN) < clouds.yaml > mycloud.$(CLOUD).yaml; \
	elif [ -f "${HOME}/.config/openstack/clouds.yaml" ]; then \
		$(YQ) '.clouds."$(CLOUD)"' $(YQIN) < ${HOME}/.config/openstack/clouds.yaml > mycloud.$(CLOUD).yaml; \
	elif [ -f "/etc/openstack/clouds.yaml" ]; then \
		$(YQ) '.clouds."$(CLOUD)"' $(YQIN) < /etc/openstack/clouds.yaml > mycloud.$(CLOUD).yaml; \
	else \
		echo "Error clouds.yaml file not found in any location."; \
		exit 1; \
	fi

gitchk:
	@if [ "$(GITREFERENCE)" != "$(GITBRANCH)" ]; then \
		git diff -r $(GITREFERENCE) -- :/ ':(exclude,top)terraform/environments' > git.diff ; \
	else \
		git diff -r origin/$(GITBRANCH) -- :/ ':(exclude,top)terraform/environments' > git.diff ; \
	fi
	@if test -s git.diff; then echo "WARN: Local changes won't be used on mgmtcluster. Commit and push them"; cat git.diff; fi

create: init
	@if [[ "$(MGMTCLUSTERNAME)" ]]; then \
		echo "Management cluster with prefix $(PREFIX) already exists. This is not supported due to unexpected side-effects." && exit 1; \
	else \
		touch .deploy.$(ENVIRONMENT); \
		tofu apply -auto-approve -var-file="environments/environment-$(ENVIRONMENT).tfvars" -var "git_reference=$(GITREFERENCE)" -var "git_repo=$(GITREPO)"; \
	fi

show: init
	@tofu show

clean: init
	@if test -e ./.deploy.MGMTCLUSTER_ADDRESS.$(ENVIRONMENT); then source ./.deploy.MGMTCLUSTER_ADDRESS.$(ENVIRONMENT); \
	ssh -o StrictHostKeyChecking=no -i .deploy.id_rsa.$(ENVIRONMENT) $(USERNAME)@$$MGMTCLUSTER_ADDRESS "timeout 320 ~/bin/cleanup.sh || true"; fi
	tofu destroy -auto-approve -var-file="environments/environment-$(ENVIRONMENT).tfvars" $(PARAMS)
	@tofu workspace select default
	tofu workspace delete $(ENVIRONMENT)
	@if test -e ./.deploy.MGMTCLUSTER_ADDRESS.$(ENVIRONMENT); then source ./.deploy.MGMTCLUSTER_ADDRESS.$(ENVIRONMENT); ssh-keygen -R $$MGMTCLUSTER_ADDRESS -f ~/.ssh/known_hosts; fi
	@rm -f .deploy.$(ENVIRONMENT) .deploy.MGMTCLUSTER_ADDRESS.$(ENVIRONMENT) .deploy.id_rsa.$(ENVIRONMENT) mycloud.$(ENVIRONMENT).yaml
	@rm -f .kubeconfig.$(ENVIRONMENT) $(TESTCLUSTER).yaml.$(ENVIRONMENT) clusterctl.$(TESTCLUSTER).yaml.$(ENVIRONMENT) $(TESTCLUSTER)-config.yaml.$(ENVIRONMENT)

fullclean:
	./cleanup/cleanup.sh --verbose --full
	@if test -e ./.deploy.MGMTCLUSTER_ADDRESS.$(ENVIRONMENT); then source ./.deploy.MGMTCLUSTER_ADDRESS.$(ENVIRONMENT); ssh-keygen -R $$MGMTCLUSTER_ADDRESS -f ~/.ssh/known_hosts; rm -f .deploy.MGMTCLUSTER_ADDRESS.$(ENVIRONMENT); fi
	$(MAKE) clean

forceclean:
	./cleanup/cleanup.sh --verbose --full --force-fip --force-pvc
	@if test -e ./.deploy.MGMTCLUSTER_ADDRESS.$(ENVIRONMENT); then source ./.deploy.MGMTCLUSTER_ADDRESS.$(ENVIRONMENT); ssh-keygen -R $$MGMTCLUSTER_ADDRESS -f ~/.ssh/known_hosts; rm -f .deploy.MGMTCLUSTER_ADDRESS.$(ENVIRONMENT); fi
	$(MAKE) clean

purge:
	@echo "Warning, going to delete ALL resources in $(ENVIRONMENT), even those that have not been created by the CAPI or tofu. The SSH-Key $(PREFIX)-keypair will be removed for all projects."
	@echo "Application credentials $(PREFIX)-appcred and $(PREFIX)-$(TESTCLUSTER)-appcred will be also removed for all projects."
	@read -p "Continue? (y/n) " -r; \
	if [[ ! $$REPLY =~ ^[Yy] ]]; then \
		exit 1; \
	fi
	@$(OPENSTACK) keypair delete $(PREFIX)-keypair || true
	@$(OPENSTACK) application credential delete $(PREFIX)-appcred || true
	@$(OPENSTACK) application credential delete $(PREFIX)-$(TESTCLUSTER)-appcred || true
	@ospurge --purge-own-project --os-cloud $(ENVIRONMENT) --verbose || true
	@tofu workspace select default
	@tofu workspace delete -force $(ENVIRONMENT) || true
	@if test -e ./.deploy.MGMTCLUSTER_ADDRESS.$(ENVIRONMENT); then source ./.deploy.MGMTCLUSTER_ADDRESS.$(ENVIRONMENT); ssh-keygen -R $$MGMTCLUSTER_ADDRESS -f ~/.ssh/known_hosts; fi
	@rm -f .deploy.$(ENVIRONMENT) .deploy.MGMTCLUSTER_ADDRESS.$(ENVIRONMENT) .deploy.id_rsa.$(ENVIRONMENT) mycloud.$(ENVIRONMENT).yaml
	@rm -f .kubeconfig.$(ENVIRONMENT) $(TESTCLUSTER).yaml.$(ENVIRONMENT) clusterctl.$(TESTCLUSTER).yaml.$(ENVIRONMENT) $(TESTCLUSTER)-config.yaml.$(ENVIRONMENT)
	@$(OPENSTACK) keypair delete $(PREFIX)-keypair || true
	@$(OPENSTACK) application credential delete $(PREFIX)-appcred || true
	@$(OPENSTACK) application credential delete $(PREFIX)-$(TESTCLUSTER)-appcred || true
	@ospurge --purge-own-project --os-cloud $(ENVIRONMENT) --verbose

list: init
	@tofu state list

ssh: .deploy.MGMTCLUSTER_ADDRESS.$(ENVIRONMENT) .deploy.id_rsa.$(ENVIRONMENT)
	@source ./.deploy.MGMTCLUSTER_ADDRESS.$(ENVIRONMENT); \
	ssh -o StrictHostKeyChecking=no -i .deploy.id_rsa.$(ENVIRONMENT) $(USERNAME)@$$MGMTCLUSTER_ADDRESS

login: ssh

get-kubeconfig: .deploy.MGMTCLUSTER_ADDRESS.$(ENVIRONMENT) .deploy.id_rsa.$(ENVIRONMENT)
	@source ./.deploy.MGMTCLUSTER_ADDRESS.$(ENVIRONMENT); \
	scp -o StrictHostKeyChecking=no -i .deploy.id_rsa.$(ENVIRONMENT) $(USERNAME)@$$MGMTCLUSTER_ADDRESS:.kube/config .kubeconfig.$(ENVIRONMENT); \
	scp -o StrictHostKeyChecking=no -i .deploy.id_rsa.$(ENVIRONMENT) $(USERNAME)@$$MGMTCLUSTER_ADDRESS:$(TESTCLUSTER)/$(TESTCLUSTER).yaml $(TESTCLUSTER).yaml.$(ENVIRONMENT); \
	scp -o StrictHostKeyChecking=no -i .deploy.id_rsa.$(ENVIRONMENT) $(USERNAME)@$$MGMTCLUSTER_ADDRESS:$(TESTCLUSTER)/clusterctl.yaml clusterctl.$(TESTCLUSTER).yaml.$(ENVIRONMENT); \
	scp -o StrictHostKeyChecking=no -i .deploy.id_rsa.$(ENVIRONMENT) $(USERNAME)@$$MGMTCLUSTER_ADDRESS:$(TESTCLUSTER)/$(TESTCLUSTER)-config.yaml $(TESTCLUSTER)-config.yaml.$(ENVIRONMENT); \
	$(SED) -i "s/127\.0\.0\.1/$$MGMTCLUSTER_ADDRESS/" clusterctl.$(TESTCLUSTER).yaml.$(ENVIRONMENT); \
	$(SED) -i "s/127\.0\.0\.1/$$MGMTCLUSTER_ADDRESS/" .kubeconfig.$(ENVIRONMENT)

deploy: .deploy.MGMTCLUSTER_ADDRESS.$(ENVIRONMENT) .deploy.id_rsa.$(ENVIRONMENT)
	@source ./.deploy.MGMTCLUSTER_ADDRESS.$(ENVIRONMENT); \
	ssh -o StrictHostKeyChecking=no -i .deploy.id_rsa.$(ENVIRONMENT) $(USERNAME)@$$MGMTCLUSTER_ADDRESS "~/bin/deploy_cluster_api.sh"

log: .deploy.$(ENVIRONMENT)
	@$(OPENSTACK) console log show $(CONSOLE)

console: .deploy.$(ENVIRONMENT)
	@xdg-open $$( $(OPENSTACK) console url show $(CONSOLE) -f value -c url )

.deploy.$(ENVIRONMENT): init
	@STAT=$$(tofu state list); \
	if test -n "$$STAT"; then touch .deploy.$(ENVIRONMENT); else echo 'please, use "make create"'; exit 1; fi

.deploy.MGMTCLUSTER_ADDRESS.$(ENVIRONMENT): .deploy.$(ENVIRONMENT)
	@MGMTCLUSTER_ADDRESS=$$(tofu output mgmtcluster_address); \
	echo "MGMTCLUSTER_ADDRESS=$$MGMTCLUSTER_ADDRESS" > $@;

.deploy.id_rsa.$(ENVIRONMENT): .deploy.$(ENVIRONMENT)
	@PRIVATE_KEY=$$(tofu output private_key); \
	echo "$$PRIVATE_KEY" > $@; \
	chmod 0600 $@

check: .deploy.MGMTCLUSTER_ADDRESS.$(ENVIRONMENT) .deploy.id_rsa.$(ENVIRONMENT)
	@source ./.deploy.MGMTCLUSTER_ADDRESS.$(ENVIRONMENT); \
	ssh -o StrictHostKeyChecking=no -i .deploy.id_rsa.$(ENVIRONMENT) $(USERNAME)@$$MGMTCLUSTER_ADDRESS "~/bin/sonobuoy.sh $(TESTCLUSTER) $(SONOMODE)"

# Pass SONOMODE="--mode quick" for a quick check
check-quick:
	$(MAKE) check SONOMODE="--mode quick"

check-conformance:
	$(MAKE) check SONOMODE="--mode certified-conformance"

check-storage:
	$(MAKE) check SONOMODE="--e2e-focus='Storage' --e2e-skip='Disruptive'"

check-csi:
	$(MAKE) check SONOMODE="--e2e-focus='CSI' --e2e-skip='Disruptive'"

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
		LEN=$$(ssh -o StrictHostKeyChecking=no -i .deploy.id_rsa.$(ENVIRONMENT) $(USERNAME)@$$MGMTCLUSTER_ADDRESS "sudo wc -l /var/log/cloud-init-output.log 2>/dev/null"); \
		LEN=$${LEN%% *}; \
		if test -n "$$LEN" -a "$$LEN" != "$$DISP"; then \
		  OUT=$$(ssh -o StrictHostKeyChecking=no -i .deploy.id_rsa.$(ENVIRONMENT) $(USERNAME)@$$MGMTCLUSTER_ADDRESS "sudo tail -n $$((LEN-DISP)) /var/log/cloud-init-output.log 2>/dev/null"); \
		  echo -e "$$OUT" | \
			$(SED) -e "s/^\(TASK.*\)$$/$$BOLD\1$$NORM/" \
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
	"KUBECONFIG=/home/$(USERNAME)/.kube/config:/home/$(USERNAME)/$(TESTCLUSTER)/$(TESTCLUSTER).yaml k9s --all-namespaces"

deploy-cso: .deploy.MGMTCLUSTER_ADDRESS.$(ENVIRONMENT) .deploy.id_rsa.$(ENVIRONMENT)
	@source ./.deploy.MGMTCLUSTER_ADDRESS.$(ENVIRONMENT); \
	ssh -t -o StrictHostKeyChecking=no -i .deploy.id_rsa.$(ENVIRONMENT) $(USERNAME)@$$MGMTCLUSTER_ADDRESS \
	"GIT_ACCESS_TOKEN=$(GIT_ACCESS_TOKEN) envsubst '\$${GIT_ACCESS_TOKEN}' < /home/$(USERNAME)/kubernetes-manifests.d/cso.yaml | KUBECONFIG=/home/$(USERNAME)/.kube/config kubectl --context kind-kind apply -f -"

deploy-cspo: .deploy.MGMTCLUSTER_ADDRESS.$(ENVIRONMENT) .deploy.id_rsa.$(ENVIRONMENT)
	@source ./.deploy.MGMTCLUSTER_ADDRESS.$(ENVIRONMENT); \
	ssh -t -o StrictHostKeyChecking=no -i .deploy.id_rsa.$(ENVIRONMENT) $(USERNAME)@$$MGMTCLUSTER_ADDRESS \
	"GIT_ACCESS_TOKEN=$(GIT_ACCESS_TOKEN) envsubst '\$${GIT_ACCESS_TOKEN}' < /home/$(USERNAME)/kubernetes-manifests.d/cspo.yaml | KUBECONFIG=/home/$(USERNAME)/.kube/config kubectl --context kind-kind apply -f -"

PHONY: clean attach detach ssh dry-run list deploy watch openstack create log console login k9s mycloud gitchk deploy-cso deploy-cspo
