nodes_count = "5"

roles = {
  "0" = "kube-master"
  "1" = "kube-minion"
  "2" = "kube-minion"
  "3" = "kube-minion"
  "4" = "kube-minion"
}

# less than 3072 in the admin node leads to trashing
admin_memory = 4096

nodes_memory = {
  "0" = "5120"
  "1" = "5120"
  "2" = "5120"
  "3" = "5120"
  "4" = "5120"
}
