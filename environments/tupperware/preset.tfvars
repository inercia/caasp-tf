###
### this file will be loaded automatically before any terraform apply/destroy/refresh
### on this environment.
###


### always refresh images when running in tupperware
img_refresh = true

### make sure you can ssh to `tupperware` with public key
libvirt_uri = "qemu+ssh://root@tupperware.suse.de/system"

prefix = "alvaro-caasp"

img_src_filename = "SUSE-CaaS-Platform-4.0-for-KVM-and-Xen.x86_64.qcow2"

### this specifies that the "download-image" must do
### the "wget" in tupperware, not here
img_down_extra_args = "--run-at tupperware --src-filename SUSE-CaaS-Platform-4.0-for-KVM-and-Xen.x86_64.qcow2"

### we will download the image to "/tmp" and then import
### it into the "default" pool
img = "/tmp/caasp-latest.qcow2"

img_pool = "default"

network = "caasp-net"
