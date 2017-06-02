# a big cluster running in tupperware

libvirt_uri = "qemu+ssh://root@tupperware.suse.de/system"

prefix = "alvaro"

# WARNING: this URL can change!!!
img = "http://download.suse.de/ibs/Devel:/CASP:/Head:/ControllerNode/images/SUSE-CaaS-Platform-3.0-for-KVM-and-Xen.x86_64.qcow2"

# remove the img_url_base, so we do not try to dowload anything
img_url_base = ""

# 5 nodes, 3 of them are masters
nodes_count = "5"

roles = {
  "0" = "kube-master"
  "1" = "kube-master"
  "2" = "kube-master"
}
