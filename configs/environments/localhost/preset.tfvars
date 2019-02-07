###
### this file will be loaded automatically before any terraform apply/destroy/refresh
### on this environment.
###

# 2 nodes, 1 master
nodes_count = "2"

# this roles are useually overriden by the tests
roles = {
  "0" = "kube-master"
}

# admin node memory
admin_memory = 4096

# all the nodes with the same amount of memory
default_node_memory = 2048

### we need to run "virsh" with "sudo" in the localhost
### otherwise the downloader will not be able to import to image to the pool
img_sudo_virsh = "local"

img_refresh = false
