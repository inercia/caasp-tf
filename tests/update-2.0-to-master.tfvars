# we don't need many machines for testing updates
nodes_count = "4"

roles = {
  "0" = "kube-master"
  "1" = "kube-master"
  "2" = "kube-minion"
  "3" = "kube-minion"
}
