###
### this file will be loaded automatically before any terraform apply/destroy/refresh
### on this environment.
###

### we need to run "virsh" with "sudo" in the localhost
### otherwise the downloader will not be able to import to image to the pool
img_sudo_virsh = "local"

img_refresh = false
