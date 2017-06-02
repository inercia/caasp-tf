#
# Author(s): Alvaro Saurin <alvaro.saurin@suse.com>
#
# Copyright (c) 2017 SUSE LINUX GmbH, Nuernberg, Germany.
#
# All modifications and additions to the file contributed by third parties
# remain the property of their copyright owners, unless otherwise agreed
# upon. The license for this file, and modifications and additions to the
# file, is the same license as for the pristine package itself (unless the
# license for the pristine package is not an Open Source License, in which
# case the license is the MIT License). An "Open Source License" is a
# license that conforms to the Open Source Definition (Version 1.9)
# published by the Open Source Initiative.
#

# Makefile FOR DEVELOPERS
# if you are not a developer, just do "terraform apply"
#
# Usage:
# * install "sshpass", "wget"...
# * customize some of these vars (for example, putting them in a Makefile.local)
# * do "make dev-apply" (or some othe target)
#

# Note: you can overwrite these vars from command line with something like:
# make dev-apply CHECKOUTS_DIR=~/dev

# prefix for all the resources'
PREFIX            = caasp

# pool used for images in libvirt
LIBVIRT_POOL_NAME = personal
LIBVIRT_POOL_DIR  = ~/.libvirt/images

# some dis
CHECKOUTS_DIR     = ~/Development
SALT_DIR          = $(CHECKOUTS_DIR)/SUSE/k8s-salt
SALT_VM_DIR       = /usr/share/salt/kubernetes
E2E_TESTS_RUNNER  = $(CHECKOUTS_DIR)/SUSE/automation/k8s-e2e-tests/e2e-tests
MANIFESTS_DIR     = $(CHECKOUTS_DIR)/SUSE/caasp-container-manifests

# the kubernetes sources checkout
K8S_SRC_DIR       = $(CHECKOUTS_DIR)/go/src/github.com/kubernetes/kubernetes

# dirs for storying docker imaages and RPMs
E2E_IMAGES_DIR    = ./docker-images
RPMS_DIR          = ./rpms

# utility used for adding/removing DNS entries
CAASPCTL_DNS      = sudo ./resources/common/caaspctl-dns

#####################################################################

# the directory with resources that will be copied to the VMs
RESOURCES_DIR    = resources

VARS_CAASP_DEVEL = profiles/devel/images-caasp-devel.tfvars
VARS_CAASP_2_0   = profiles/devel/images-caasp-2.0.tfvars
VARS_CAASP_3_0   = profiles/devel/images-caasp-3.0.tfvars

# a repo for updates
REPO_UPDATES_2_0 = http://download.suse.de/ibs/Devel:/CASP:/Head:/ControllerNode/standard/

CAASPCTL         = /tmp/caasp/caaspctl
RUN_CAASPCTL     = bash $(CAASPCTL)

RUN_VIRSH        = sudo virsh

# environment variables we always pass to Terraform
# can be overwritten from command line with TF_VAR_XXX
TF_VAR_prefix    = $(PREFIX)
TF_VAR_img_pool  = $(LIBVIRT_POOL_NAME)
TF_VAR_salt_dir  = $(SALT_DIR)
TERRAFORM_VARS   = TF_VAR_prefix=$(TF_VAR_prefix) \
	                 TF_VAR_img_pool=$(TF_VAR_img_pool) \
	                 TF_VAR_salt_dir=$(TF_VAR_salt_dir)
#	                 TF_VAR_manifests_dir=$(MANIFESTS_DIR)

# common options for ssh, rsync, etc
SSH              = sshpass -p "linux" ssh
SCP              = sshpass -p "linux" scp
SSH_OPTS         = -oStrictHostKeyChecking=no \
                   -oUserKnownHostsFile=/dev/null
EXCLUDE_ARGS     = --exclude='*.tfstate*' \
                   --exclude='.git*' \
                   --exclude='Makefile' \
                   --exclude='README.md' \
                   --exclude='*.sublime*' \
                   --exclude='.idea' \
                   --exclude='.pyc' \
                   --exclude='*.tgz'
RSYNC_OPTS       = $(EXCLUDE_ARGS) \
                   -e '$(SSH) $(SSH_OPTS)' \
                   --delete --delete-after --force

PARSE_TFSTATE    = support/mk/parse-tfstate.py --tfstate terraform.tfstate

# names for the VMs
VM_ADMIN         = `$(PARSE_TFSTATE) --regex '$(PREFIX)-admin' --names`
VM_NODES         = `$(PARSE_TFSTATE) --regex '$(PREFIX)-node'  --names`

# stuff for building distributions
DIST_CONT        = *.profile  k8s-setup terraform
DIST_TAR         = kubernetes-terraform.tgz
TAR_ARGS         = $(EXCLUDE_ARGS) -zcvf

# a kubeconfig we will download from the master
KUBECONFIG       = kubeconfig

# the admin user in kubernetes
K8S_ADMIN_USER   = cluster-admin

# files to remove after a "destroy"
CLEANUP_FILES    = admin.{tar,crt,key} ca.crt \
                   $(KUBECONFIG)

# the dashboard and node IPs (might need a "terraform refresh" after a while)
ADMIN_IP         = `$(PARSE_TFSTATE) --name $(PREFIX)-admin`
MASTER_IP        = `$(PARSE_TFSTATE) --name $(PREFIX)-node-0`
NODES_IPS        = `$(PARSE_TFSTATE) --regex '$(PREFIX)-node-[1-9]'`
NUM_NODES        = `$(PARSE_TFSTATE) --regex '$(PREFIX)-node' --count`
ALL_IPS          = $(ADMIN_IP) $(NODES_IPS)

# the hostname used for the API server
API_HOSTNAME     = api.infra.caasp.local

# you can customimze vars in a local Makefile
-include Makefile.local

####################################################################
# CAASP
####################################################################

all: dev-help

dev-help:
	@echo "************ Makefile FOR DEVELOPERS ************"
	@echo "For regular users please do 'terraform apply'"
	@echo "*************************************************"
	@echo
	@echo "Developers can use the following targets:"
	@echo
	@echo " * make dev-(apply|destroy): create/destroy the cluster"
	@echo " * make dev-copy: copy the Salt & co code to the Admin node"
	@echo " * make dev-orch: copy the code and trigger an orchestration"
	@echo
	@echo "  (get more help on orchestrations with 'make dev-orch-help')"
	@echo
	@echo "Some targets for managing the VMs"
	@echo
	@echo " * make dev-snapshot [STAGE=<NAME>]: create a snapshot of the VMs"
	@echo "                                     (with an optional STAGE name)"
	@echo " * make dev-rollback: rollback VMs to the last snapshot"
	@echo " * make dev-(suspend|resume): suspend/resume the VMs"
	@echo
	@echo "IMPORTANT: check the paths in this Makefile before running anything!"
	@echo "           you can overwrite them in a local Makefile.local"

dev-apply-with-args:
	@echo ">>> Applying Terraform..."
	@echo ">>> (with args: $(TERRAFORM_VARS)"
	@env $(TERRAFORM_VARS) terraform apply $(ARGS)
	@echo ">>> (Waiting for nodes before snapshotting...)" && \
			make dev-wait-nodes-accepted _wait-20s dev-snapshot STAGE="post-apply"

dev-apply:
	make dev-apply-with-args
dev-apply-caasp-devel:
	make dev-apply-with-args ARGS="-var-file=$(VARS_CAASP_DEVEL) $(ARGS)"
dev-apply-caasp-devel-big:
	make dev-apply-caasp-devel ARGS="-var-file=profiles/devel/big-cluster.tfvars"
dev-apply-caasp-2.0:
	make dev-apply-with-args ARGS="-var-file=$(VARS_CAASP_2_0) $(ARGS)"
dev-apply-caasp-3.0:
	make dev-apply-with-args ARGS="-var-file=$(VARS_CAASP_3_0) $(ARGS)"

dev-destroy: dev-destroy-snapshots
	-terraform destroy -force
	-rm -f $(CLEANUP_FILES)
	-@notify-send "k8s: cluster destruction finished" &>/dev/null

dev-copy-resources:
	# there is no need for making the FS rw-able
	-@for ip in $(ALL_IPS) ; do \
		echo ">>> Copying '$(RESOURCES_DIR)' to $$ip:/tmp/caasp" ; \
		rsync -avz $(RSYNC_OPTS) $(RESOURCES_DIR)/common/ root@$$ip:/tmp/caasp/ ; \
		rsync -avz $(RSYNC_OPTS) $(RESOURCES_DIR)/admin/  root@$$ip:/tmp/caasp/admin/ ; \
	done

dev-copy-salt:
	@echo ">>> Making fs RW-able"
	@make dev-ssh CMD='$(RUN_CAASPCTL) rw on'
	@echo ">>> Copying the Salt scripts/pillar"
	rsync -avz $(RSYNC_OPTS) $(SALT_DIR)/  root@$(ADMIN_IP):$(SALT_VM_DIR)/

dev-copy: dev-copy-resources dev-copy-salt
	@echo ">>> Synchronizing Salt stuff"
	@make -s dev-ssh CMD='$(RUN_CAASPCTL) salt sync'

# wait for all the nodes to be accepted by the Salt master
# NOTE: we must wait for nodes+2, as the 'admin' and 'ca'
#       count as nodes too...
dev-wait-nodes-accepted:
	@n=$(NUM_NODES) && \
	  nn=`expr $$n + 2` && \
	  echo "Waiting for $$nn nodes to be accepted (including 'admin' and 'ca')" && \
		make -s dev-ssh CMD="$(RUN_CAASPCTL) keys wait $$nn"


dev-orch-help:
	@echo
	@echo "Orchestration targets:"
	@echo
	@echo "Some specific orchestrations (some of them accept parameters):"
	@echo
	@echo " * make dev-orch: copy the code and trigger an orchestration"
	@echo " * make dev-orch-update: copy the code and update the cluster"
	@echo " * make dev-orch-update-fake: set the cluster as 'needs update' and run a update"
	@echo " * make dev-orch-rm NAME=<NAME>: copy the code and remove the node <NAME>"
	@echo " * make dev-orch-add NAMES='<NAME1> <NAME2> ...': copy the code and add <NAME1>, <NAME2>..."
	@echo
	@echo "   Most of these orchestrations have a 'reorch' equivalent (ie, 'dev-orch-rm'"
	@echo "   has 'dev-reorch-rm') that perform a rollback before starying the orchestration"
	@echo
	@echo "Some vars:"
	@echo
	@echo " * SNAPSHOT=1: creates a 'post-orch' snapshot after orchestrating"
	@echo " * CMD_ARGS='...': extra parameters to use when running the orchestration. For example:"
	@echo
	@echo "Example:"
	@echo
	@echo "  make dev-orch SNAPSHOT=1 CMD_ARGS='kubernetes test=True' # for testing Jinja output"
	@echo
	@echo "IMPORTANT: check the paths in this Makefile before running anything!"
	@echo "           you can overwrite them in a local Makefile.local"

dev-orch: dev-copy-resources dev-copy-salt dev-wait-nodes-accepted dev-kubeconfig-clean
	@echo ">>> Running orchestration"
	@make -s dev-ssh CMD='$(RUN_CAASPCTL) orchestrate $(CMD_ARGS)'
	-@notify-send "k8s: cluster orchestration finished" &>/dev/null
	[ -n "$(SNAPSHOT)" ] && make dev-snapshot STAGE="post-orch"

dev-orch-prepare: dev-wait-nodes-accepted
	@make -s dev-orch CMD_ARGS='prepare $(CMD_ARGS)'

# run the update orchestration
# note that nodes must have the tx_update_reboot_needed flag set
dev-orch-update:
	@make -s dev-orch CMD_ARGS='update $(CMD_ARGS)'

# set the tx_update_reboot_needed in all the nodes
# and start an update orchestration
dev-orch-update-fake:
	@make -s dev-orch CMD_ARGS='update-set-needed'
	@make -s dev-orch CMD_ARGS='update $(CMD_ARGS)'

# remove a node from the cluster
#
# arguments:
#
#  ID:     the node ID we want to remove
#  NAME:   use this name for getting the node ID
#  SKIP:   when not empty, skip doing anything _in_ the node
#
# Example:
#
#  make dev-orch-rm SKIP=1 NAME=caasp-node-0
#
dev-orch-rm:
	@if [ -n '$(NAME)' ] ; then \
	  echo ">>> Finding machine-id for $(NAME)" ; \
		ID=`make -s dev-machine-id TO=$(NAME)` ; \
		echo ">>> ... ID=$$ID" ; \
	else \
		ID=$(ID) ; \
	fi ; \
	[ -n "$$ID" ] || (echo "no node ID provided. run with ID or NAME parameters" ; exit 1 ; ) ; \
	echo ">>> Removing node with ID=$$ID" ; \
	if [ -n '$(SKIP)' ] ; then \
  	echo ">>> (skipping $$ID in the removal)" ; \
	  make -s dev-orch CMD_ARGS="rms $$ID $(CMD_ARGS)" ; \
	else \
	  make -s dev-orch CMD_ARGS="rm $$ID $(CMD_ARGS)" ; \
	fi

# add nodes to the cluster
#
# arguments:
#
#  IDS:     the node IDs we want to add
#  NAMES:   use these names for getting the node IDs
#
# Example:
#
#  make dev-orch-add NAMES="caasp-node-0 caasp-node-1"
#
dev-orch-add:
	@if [ -n '$(NAMES)' ] ; then \
	  IDS= ; \
	  echo ">>> Finding machine-id for $(NAMES)" ; \
		for name in $(NAMES) ; do \
			IDS="$$IDS `make -s dev-machine-id TO=$$name`" ; \
		done ; \
		echo ">>> ... IDS=$$IDS" ; \
	else \
		IDS=$(IDS) ; \
	fi ; \
	[ -n "$$IDS" ] || (echo "no node IDS provided. run with IDS or NAMES parameters" ; exit 1 ; ) ; \
	echo ">>> Adding nodes with IDS=$$IDS" ; \
  make -s dev-orch CMD_ARGS="add $$IDS $(CMD_ARGS)" ; \

dev: dev-apply dev-orch

# shotcuts: targets with rollbacks
dev-reorch:             dev-rollback _wait-20s dev-fix-nodes dev-orch
dev-reorch-update:      dev-rollback _wait-20s dev-fix-nodes dev-orch-update
dev-reorch-update-fake: dev-rollback _wait-20s dev-fix-nodes dev-orch-update-fake
dev-reorch-rm:          dev-rollback _wait-20s dev-fix-nodes dev-orch-rm
dev-reorch-add:         dev-rollback _wait-20s dev-fix-nodes dev-orch-add

# highstates
# use, for example, CMD_ARGS='kube-apiserver' for applying 'kube-apiserver/init.sls' only
dev-high: dev-copy
	@[ -n "$(WHERE)" ] || { echo "no WHERE provided, for example: make dev-high WHERE='G@roles:admin'" ; exit 1 ; }
	@echo ">>> Running highstate at $(WHERE)"
	make -s dev-ssh CMD='$(RUN_CAASPCTL) apply at "$(WHERE)" $(CMD_ARGS)'
	-@notify-send "k8s: highstate at $(WHERE) finished" &>/dev/null
dev-high-admin:
	@make -s dev-high WHERE='G@roles:admin'
dev-high-master:
	@make -s dev-high WHERE='G@roles:kube-master'
dev-high-minions:
	@make -s dev-high WHERE='G@roles:kube-minion'

dev-restart-salt-master:
	@make -s dev-ssh CMD='$(RUN_CAASPCTL) salt restart-master'
dev-restart-salt-minions:
	@make -s dev-ssh-nodes CMD='systemctl restart salt-minion'
dev-restart-salt-api:
	@make -s dev-ssh CMD='$(RUN_CAASPCTL) salt restart-api'
dev-restart-k8s-master:
	@make -s dev-ssh-node-0 CMD='$(RUN_CAASPCTL) restart master'
dev-restart-k8s-minions:
	@make -s dev-ssh-nodes CMD='$(RUN_CAASPCTL) restart minion'

# some times we might need to refresh data
# and readjust some stuff (ie, when IPs change)
dev-refresh:
	@echo ">>> Refreshing Terraform data"
	@support/mk/refresh-vms.sh

dev-kubeconfig: $(KUBECONFIG)
$(KUBECONFIG):
	@echo ">>> Generating a kubeconfig"
	@make -s dev-ssh CMD='$(RUN_CAASPCTL) k8s kubeconfig'
	@echo ">>> Getting the kubeconfig"
	@$(SCP) -q $(SSH_OPTS) root@$(ADMIN_IP):.kube/config $(KUBECONFIG)
	@echo ">>> ... kubeconfig has been copied locally!."
	@echo ">>> Adding $(API_HOSTNAME) to /etc/hosts"
	$(CAASPCTL_DNS) add $(API_HOSTNAME) $(MASTER_IP)

dev-kubeconfig-clean:
	[ ! -f $(KUBECONFIG) ] || $(CAASPCTL_DNS) del $(API_HOSTNAME)
	rm -f $(KUBECONFIG)

dev-install-dashboard: $(KUBECONFIG)
	@echo ">>> Installing the dashboard"
	kubectl --kubeconfig=$(KUBECONFIG) apply -f "https://raw.githubusercontent.com/kubernetes/dashboard/master/src/deploy/recommended/kubernetes-dashboard.yaml"
	@echo ">>> Running the kubectl proxy for http://127.0.0.1:8001/ui/"
	kubectl --kubeconfig=$(KUBECONFIG) proxy

####################################################################
# profiles

dev-profile-apply: dev-profile-clean
	@echo ">>> Applying development profile"
	@for i in profiles/devel/profile-devel*.tf ; do ln -sf $$i ; done

dev-profile-clean:
	@echo ">>> Cleaning profile files"
	@for i in *.tf ; do \
		if [ -L $$i ] ; then \
			l=`readlink $$i` ; \
			[[ $$l == profiles/* ]] && rm -f $$i ; \
		fi ; \
	done

####################################################################
# updates & reboots

# for testing upgrades:
#
#   1. make sure the REPO_UPDATES_2_0 repo contains some updates
#   2. switch to the Salt master branch
#   3. do a regular apply & orchestration with
#
#      make dev-apply dev-orch
#
#   4. set the "update needed" flag with
#
#      make dev-nodes-set-reboot-needed
#
#   5. create a snapshot with
#
#      make dev-snapshot STAGE="post-orch-pre-update"
#
#   6. switch to the Salt branch you want to test
#   7. do a
#
#      make dev-orch-update
#
# if someting goes wrong with the Salt code, retry with
#
#   make dev-rollback dev-orch-update

dev-nodes-set-reboot-needed:
	@echo ">>> Setting reboot-needed grain"
	@make -s dev-ssh-nodes CMD='sed -i "/^tx_update_reboot_needed/ d" /etc/salt/grains ; echo "tx_update_reboot_needed: true" >> /etc/salt/grains'
	@echo ">>> Refreshing grains"
	@make -s dev-ssh CMD='$(RUN_CAASPCTL) salt "*" saltutil.refresh_grains'

dev-nodes-update-packages:
	@echo ">>> Installing a repo with updates"
	@make -s dev-ssh-nodes CMD="$(RUN_CAASPCTL) zypper ar $(REPO_UPDATES_2_0) updates"
	@echo ">>> Doing a 'zypper update'"
	@make -s dev-ssh-nodes CMD='$(RUN_CAASPCTL) zypper update'
	-@notify-send "k8s: cluster updates downloaded... would need a reboot" &>/dev/null

dev-nodes-reboot:
	@make -s dev-ssh-nodes CMD='$(RUN_CAASPCTL) reboot'
	-@notify-send "k8s: nodes rebooted" &>/dev/null

####################################################################
# some ssh convencience targets

dev-ssh-to:
	@[ -n '$(TO)' ] || (echo "no TO provided" ; exit 1 ; )
	@$(SSH) -q $(SSH_OPTS) root@$(TO) '$(CMD)'

dev-ssh: dev-ssh-admin
dev-ssh-admin:
	@make -s dev-ssh-to TO='$(ADMIN_IP)'

dev-ssh-nodes:
	@[ -n "$(CMD)" ] || (echo "no CMD provided" ; exit 1 ; )
	@for node in $(NODES_IPS) ; do \
		make -s dev-ssh-to TO=$$node CMD='$(CMD)' ; \
	done

dev-ssh-node-0:
	@make -s dev-ssh-to TO=`$(PARSE_TFSTATE) --name $(PREFIX)-node-0`
dev-ssh-node-1:
	@make -s dev-ssh-to TO=`$(PARSE_TFSTATE) --name $(PREFIX)-node-1`
dev-ssh-node-2:
	@make -s dev-ssh-to TO=`$(PARSE_TFSTATE) --name $(PREFIX)-node-2`
dev-ssh-node-3:
	@make -s dev-ssh-to TO=`$(PARSE_TFSTATE) --name $(PREFIX)-node-3`
dev-ssh-node-4:
	@make -s dev-ssh-to TO=`$(PARSE_TFSTATE) --name $(PREFIX)-node-4`

dev-ssh-salt-master:
	@[ -n "$(CMD)" ] || (echo "no CMD provided" ; exit 1 ; )
	@make -s dev-ssh CMD='$(RUN_CAASPCTL) salt $(CMD)'

dev-machine-id:
	@[ -n '$(TO)' ] || (echo "no TO provided" ; exit 1 ; )
	@make -s dev-ssh-to CMD='cat /etc/machine-id' TO=`$(PARSE_TFSTATE) --name $(TO)`

####################################################################
# some logging utilities
dev-logs-salt-master:
	@echo ">>> Dumping logs from the Salt master"
	@make -s dev-ssh CMD='$(RUN_CAASPCTL) salt logs'

dev-logs-events:
	@echo ">>> Dumping Salt events at the master"
	@make -s dev-ssh CMD='$(RUN_CAASPCTL) salt events'

####################################################################
# VMs management

VMS_SNAPSHOTS = $(VM_ADMIN) $(VM_NODES)

_do-snapshot:
	@echo ">>> Snapshotting VMs..."
	@sleep 5
	@for vm in $(VMS_SNAPSHOTS) ; do \
	  if [ -n "$(STAGE)" ] ; then \
			echo ">>> ... snapshotting $$vm (as stage $(STAGE))" ; \
			$(RUN_VIRSH) snapshot-create-as --domain "$$vm" --name "$(STAGE)" --description "Snapshot created at $(STAGE)" ; \
		else \
			echo ">>> ... snapshotting $$vm" ; \
			$(RUN_VIRSH) snapshot-create --domain "$$vm" ; \
		fi ; \
	done

# NOTE: we need to suspend before snapshotting. Otherwise, qemu
#       freezes sometimes... :-/
dev-snapshot: dev-suspend _do-snapshot dev-resume
	-@notify-send "k8s: VMs snapshots created" &>/dev/null

dev-snapshot-list:
	@for vm in $(VMS_SNAPSHOTS) ; do \
		echo "$$vm:" ; \
		$(RUN_VIRSH) snapshot-list --tree "$$vm" ; \
	done

dev-destroy-snapshots:
	-@for vm in $(VMS_SNAPSHOTS) ; do \
		echo ">>> Destroying snapshots for $$vm" ; \
		while $(RUN_VIRSH) snapshot-delete --current --domain "$$vm" &>/dev/null ; do /bin/true ; done ; \
	done

dev-suspend:
	@echo ">>> Suspending VMs"
	-@for vm in $(VMS_SNAPSHOTS) ; do \
		echo ">>> ... suspending $$vm" ; \
		$(RUN_VIRSH) suspend --domain "$$vm" ; \
	done
	-@notify-send "k8s: all VMs suspended" &>/dev/null

dev-resume:
	@echo ">>> Resuming VMs"
	-@for vm in $(VMS_SNAPSHOTS) ; do \
		echo ">>> ... resuming $$vm" ; \
		$(RUN_VIRSH) resume --domain "$$vm" ; \
	done
	-@notify-send "k8s: all VMs suspended" &>/dev/null

# NOTE: we need to "echo 1 > /proc/sys/vm/overcommit_memory"
#       or qemu-kvm will kill our machine...
# NOTE: better to suspend before rolling back, so minions do
#       talk to a master that comes from the past
dev-rollback: dev-suspend
	@echo ">>> Rolling back VMs"
	@for vm in $(VMS_SNAPSHOTS) ; do \
	  snap=`$(RUN_VIRSH) snapshot-list $$vm | tail -n2 | awk '{ print $1 }'` ; \
		echo ">>> ... rolling back: $$vm -> $$snap" ; \
		$(RUN_VIRSH) snapshot-revert --current --running --domain "$$vm" ; \
	done
	@sleep 5
	-@make -s dev-refresh
	-@notify-send "k8s: VMs rolled back" &>/dev/null

####################################################################
# packages installation

_install-rpms-on:
	@echo "Copying RPMs to $(NODE)"
	@$(SSH) -q $(SSH_OPTS) root@$(NODE) 'rm -rf /tmp/rpms && mkdir -p /tmp/rpms'
	@rsync -avz $(RSYNC_OPTS) $(RPMS_DIR)/* root@$(NODE):/tmp/rpms/
	@$(SSH) -q $(SSH_OPTS) root@$(NODE) 'ls -lisah /tmp/rpms/*'
	@echo "Importing keys"
	@$(SSH) -q $(SSH_OPTS) root@$(NODE) 'caaspctl rw 1'
	@$(SSH) -q $(SSH_OPTS) root@$(NODE) 'rpm --import /tmp/rpms/*.key /tmp/rpms/*.pub || /bin/true'
	@echo "Installing packages and rebooting"
	@$(SSH) -q $(SSH_OPTS) root@$(NODE) 'caaspctl zypper in -y /tmp/rpms/*.rpm'
	-@notify-send "k8s: packages installed in $(NODE)" &>/dev/null

# insstall all the RPMs found in $(RPMS_DIR)/
dev-install-rpms-nodes:
	@for node in $(NODES_IPS) ; do \
		make -s _install-rpms-on NODE=$$node ; \
	done

####################################################################
# e2e tests

# running the e2e tests:
#
#   1. make sure you have a checkout of the kubernetes sources tree
#      that matches the version installed in the cluster
#
#   2. if you don't have a really good internet connection
#
#        2.1 upload the e2e images with
#          make dev-e2e-upload-images"
#
#        2.2 create a snapshot with
#          make dev-snapshot STAGE="post-upload-e2e-images"
#
#   3. orchetreste with
#        make dev-orch
#
#   4. run the tests with
#        make dev-e2e
#
e2e_images_lst_file = $(E2E_IMAGES_DIR)/e2e-images.lst

$(e2e_images_lst_file):
	@echo ">>> Generating images list from sources"
	@echo ">>> WARNING: make sure it is in the right branch !!!"
	grep -Iiroh "gcr.io/google_.*" $(K8S_SRC_DIR)/test/e2e | \
		sed -e "s/[,\")}]//g" | awk '{print $1}' | \
		sort | uniq | tr '\n' ' ' > $(e2e_images_lst_file)

dev-e2e-upload-images: $(e2e_images_lst_file)
	@echo ">>> Downloading and saving images" ; \
	env OUT_DIR=$(E2E_IMAGES_DIR) ./support/mk/save-images.sh `cat $(e2e_images_lst_file)`
	@-for node in $(NODES_IPS) ; do \
		echo ">>> Copying images to $$node" ; \
		rsync -avz -c $(RSYNC_OPTS) $(E2E_IMAGES_DIR)/docker-image-*  root@$$node:/tmp/ ; \
		$(SSH) -q $(SSH_OPTS) root@$$node 'sh for i in /tmp/docker-image-* ; do docker load -i $i ; done' ; \
		echo ">>> ... images copies to $$node" ; \
	done
	@echo ">>> Loading images in nodes"
	@make -s dev-ssh-nodes CMD='ls /tmp/docker-image*gz | xargs -n1 docker load -i'

# run the e2e tests
dev-e2e: $(KUBECONFIG)
	@echo ">>> Running the kubernetes e2e tests"
	@echo ">>> WARNING: assuming e2e images have been pre-pulled !!!"
	$(E2E_TESTS_RUNNER) --kubeconfig $(KUBECONFIG) $(E2E_ARGS)
	-@notify-send "k8s: e2e tests finished" &>/dev/null

####################################################################
# aux

.PHONY: _wait-20s
_wait-20s:
	@echo ">>> Waiting some time..."
	@sleep 20

# hack for fixing things
dev-fix-nodes:
	@for name in $(VM_ADMIN) $(VM_NODES) ; do \
	  ip=`$(PARSE_TFSTATE) --name $$name` ; \
		echo "Setting hostname=$$name at $$ip" ; \
		make -s dev-ssh-to TO=$$ip CMD="hostname $$name" ; \
		make -s dev-ssh-to TO=$$ip CMD="systemctl enable --now ntpd" ; \
	done

####################################################################
# other

dev-tupperware-plan:
	terraform plan -var-file=profiles/devel/tupperware-big-cluster.tfvars

dev-tupperware-apply:
	terraform apply -var-file=profiles/devel/tupperware-big-cluster.tfvars

dev-tupperware-destroy:
	terraform destroy -var-file=profiles/devel/tupperware-big-cluster.tfvars

####################################################################
# distribution

dist:
	@echo "Creating distribution package"
	tar $(TAR_ARGS) $(DIST_TAR) $(DIST_CONT)
