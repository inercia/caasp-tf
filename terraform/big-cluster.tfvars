# a big cluster

# 4 nodes, 3 of them are masters
nodes_count = "4"

roles = {
  "0" = "kube-master"
  "1" = "kube-master"
  "2" = "kube-master"
}

# do not try to use too much memory... :-(

# less than 3072 in the admin node leas to trashing
admin_memory = 3512

nodes_memory = {
  "0" = "1224"
  "1" = "1224"
  "2" = "1224"
  "3" = "1224"
}
