#
# second stage: add some masters and minions
#
# usage:
#
# 1. create an initial cluster with 1 master and 1 minion, using the stage 1 file
#
#      make dev-apply-cfgs CFGS="devel/images-caasp-devel local tests/addition-stage-1"
#
# 2. orchestrate (creating a snapshot afterwards)
#
#      make dev-orch SNAPSHOT=1 STAGE="post-orch-with-2"
#
# 3. add 1 master and 1 minion, using the stage 2 file
#
# #    make dev-apply-cfgs CFGS="devel/images-caasp-devel local tests/addition-stage-2" STAGE="post-add-2-more"
#
# 4. run the addition orchestration
#
#      make dev-orch-add NAMES="caasp-node-2 caasp-node-3"
#

# 3 nodes: 2 master, 1 minion
nodes_count = "5"

roles = {
  "0" = "kube-master"
  "1" = "kube-master"
  "2" = "kube-minion"
  "3" = "kube-master"
  "4" = "kube-minion"
}

# do not try to use too much memory... :-(

# less than 3072 in the admin node leads to trashing
admin_memory = 3512

nodes_memory = {
  "0" = "1224"
  "1" = "1224"
  "2" = "1224"
  "3" = "1224"
  "4" = "1224"
}
