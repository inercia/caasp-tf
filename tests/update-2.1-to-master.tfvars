# we don't need many machines for testing updates
nodes_count = "4"

roles = {
  "0" = "kube-master"
  "1" = "kube-master"
  "2" = "kube-minion"
  "3" = "kube-minion"
}

repo_updates_url = "http://dist.nue.suse.com/ibs/SUSE:/SLE-12-SP3:/Update:/Products:/CASP30/images/repo/SUSE-CAASP-3.0-POOL-x86_64-Media1/"
