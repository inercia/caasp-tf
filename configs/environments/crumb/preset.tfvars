###
### this file will be loaded automatically before any terraform apply/destroy/refresh
### on this environment.
###

# 4 nodes, 2 of them are masters
nodes_count = "4"

# this roles are useually overriden by the tests
roles = {
  "0" = "kube-master"
  "1" = "kube-master"
}

# admin node memory
admin_memory = 4096

# all the nodes with the same amount of memory
default_node_memory = 2560

nodes_memory = {}

### always refresh images when running in crumb
img_refresh = true

### make sure you can ssh to `crumb` with public key
libvirt_uri = "qemu+ssh://root@crumb.arch.suse.de/system"

prefix = "alvaro-caasp"

### this specifies that the "download-image" must do
### the "wget" in crumb, not here
img_down_extra_args = "--run-at root@crumb.arch.suse.de"

### we will download the image to "/tmp" and then import
### it into the "default" pool
img = "/tmp/caasp-latest.qcow2"

img_pool = "default"

network = "caasp-net"
