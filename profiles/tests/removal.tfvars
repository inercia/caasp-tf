# a big cluster with some unassigned node

# 4 nodes: 2 master, 1 minion, 1 unassigned

# usage:
#
# 1. This removal orchestration:
#
#     make dev-apply-cfgs CFGS="devel/images-caasp-devel local tests/removal"
#     make dev-orch SNAPSHOT=1 STAGE="post-orch-pre-remove"
#     make dev-orch-rm NAME="caasp-node-0"
#
# should lead to a migration of the MASTER to caasp-node-3
#
# 2. This removal orchestration:
#
#     make dev-apply-cfgs CFGS="devel/images-caasp-devel local tests/removal"
#     make dev-orch SNAPSHOT=1 STAGE="post-orch-pre-remove"
#     make dev-orch-rm NAME="caasp-node-2"
#
# should lead to a migration of the MINION to caasp-node-3
#

nodes_count = "4"

roles = {
  "0" = "kube-master"
  "1" = "kube-master"
  "2" = "kube-minion"
  "3" = "unassigned"
}

# do not try to use too much memory... :-(
# less than 3072 in the admin node leads to trashing
admin_memory = 3512

nodes_memory = {
  "0" = "1224"
  "1" = "1224"
  "2" = "1224"
  "3" = "1224"
}
