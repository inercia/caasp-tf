###
### this file will be loaded automatically before any terraform apply/destroy/refresh
### on this environment.
###

# 6 nodes, 3 of them are masters
nodes_count = "6"

# this roles are useually overriden by the tests
roles = {
  "0" = "kube-master"
  "1" = "kube-master"
  "2" = "kube-master"
}

# admin node memory
admin_memory = 4096

# all the nodes with the same amount of memory
default_node_memory = 2560

nodes_memory = {}

### always refresh images when running in acamar
img_refresh = true

### make sure you can ssh to `acamar` with public key
libvirt_uri = "qemu+ssh://root@acamar.arch.suse.de/system"

prefix = "alvaro-caasp"

img_src_filename = "SUSE-CaaS-Platform-4.0-for-KVM-and-Xen.x86_64.qcow2"

### this specifies that the "download-image" must do
### the "wget" in acamar, not here
img_down_extra_args = "--run-at root@acamar.arch.suse.de --src-filename SUSE-CaaS-Platform-4.0-for-KVM-and-Xen.x86_64.qcow2"

### we will download the image to "/tmp" and then import
### it into the "default" pool
img = "/tmp/caasp-latest.qcow2"

img_pool = "default"

network = "caasp-net"
