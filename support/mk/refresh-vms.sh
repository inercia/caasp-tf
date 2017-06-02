#!/bin/sh
#
# libvirt can change the IP addresses for your VMs after a while
# (for example, if you put your laptop to sleep), so we need to
# "refresh" the "tfstate" by doing a "terraform refresh" and update
# some other things...
#
# env vars:
#
#   FORCE: force the refresh, even if the Admin Node IP is the same
#

[ -n "$DEBUG" ] && set -x

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

PARSE_TFSTATE="$DIR/parse-tfstate.py"

TFSTATE=$DIR/../../terraform.tfstate

# ssh password and flags
SSH_PASSWD="${SSH_PASSWD:-linux}"
SSH_OPTS="-oStrictHostKeyChecking=no \
          -oUserKnownHostsFile=/dev/null"

# force the refresh, even if the Admin Node IP does not change
FORCE="${FORCE:-}"

# the hostname used for the Admin Node
ADMIN_HOSTNAME="${ADMIN_HOSTNAME:-dashboard}"

# caaspctl in the VMs
CAASPCTL=/tmp/caasp/caaspctl

# VMs names
VM_NAME_ADMIN="caasp-admin"
VM_NAME_NODES="caasp-node"

###############################################################

while [ $# -gt 0 ] ; do
	case "$1" in
	    --forced|--force|-f)
			    FORCE=1
	        ;;
	    --pass|--password|-p)
    			SSH_PASSWD="$2"
    			shift
          ;;
      --tfstate)
          TFSTATE=$2
          shift
          ;;
	    --admin)
    			ADMIN_HOSTNAME=$2
    			shift
	        ;;
	    *)
	        echo ">>> Unknown command $1"
	        ;;
	esac
	shift
done

###############################################################

log()     { echo ">>> $1" ; }
log_sys() { log "$1" ; logger -t "caaspctl" "$1" ; }
warn()    { log "WARNING: $1" ; }
abort()   { log "FATAL: $1" ; exit 1 ; }

do_ssh()        { sshpass -p "$SSH_PASSWD" ssh $SSH_OPTS $@ ; }
parse_tfstate() { $PARSE_TFSTATE --tfstate $TFSTATE $@ ; }
admin_ip()      { parse_tfstate --name "$VM_NAME_ADMIN" 2>/dev/null ; }
nodes_num()     { parse_tfstate --regex "$VM_NAME_NODES" --count 2>/dev/null ; }
nodes_ips()     { parse_tfstate --regex "$VM_NAME_NODES" 2>/dev/null ; }
nodes_ips_map() { parse_tfstate --regex "$VM_NAME_NODES" --map | sort 2>/dev/null ; }
run_caaspctl() {
  local ip=$1
  shift
  do_ssh root@$ip "$CAASPCTL $@"
}

old_admin_ip=$(admin_ip)
#[ -n "$old_admin_ip" ] || abort "could not determine current Admin Node IP"

old_nodes_ips=$(nodes_ips_map)
#[ -n "$old_nodes_ips" ] || abort "could not determine current Nodes IPs"

log "Refreshing Terraform..."
count=0
# note: hackish solution to the unreliability of "terraform refresh"
while ! terraform refresh -state $TFSTATE ; do
  count=$((count + 1))
  log "Terraform refresh failed: retrying..."
  [ $count -gt 100 ] && abort "Terraform refresh failed"
  sleep 1
done

[ -f $TFSTATE ] || abort "terraform.tfstate does not exist"
n=$(nodes_num)
[ "$n" != "0" ] || abort "no nodes found in terraform state file"

new_admin_ip=$(admin_ip)
[ -z "$new_admin_ip" ] && abort "could not determine new Admin Node IP"

admin_ip_changed=
if [ "$new_admin_ip" != "$old_admin_ip" ] || [ -n "$FORCE" ] ; then
	log "Admin Node IP changed."
  log " - old: $old_admin_ip"
  log " - new: $new_admin_ip"
  admin_ip_changed=1
fi

new_nodes_ips=$(nodes_ips_map)
[ -z "$new_nodes_ips" ] && abort "could not determine new Node IPs"

nodes_ips_changed=
if [ "$new_nodes_ips" != "$old_nodes_ips" ] || [ -n "$FORCE" ] ; then
	log "Nodes IP changed, from..."
  log "$old_nodes_ips"
  log "to...:"
  log "$new_nodes_ips"
  nodes_ips_changed=1
fi

if [ -z "$admin_ip_changed$nodes_ips_changed" ] ; then
  log "Nothing has changed."
else
  for node_ip in $(nodes_ips) ; do

    if [ -n "$admin_ip_changed" ] ; then
    	log "Updating dashboard IP as $new_admin_ip..."
    	run_caaspctl $node_ip "dns set $ADMIN_HOSTNAME $new_admin_ip"

    	log "Linking $node_ip to $ADMIN_HOSTNAME..."
    	run_caaspctl $node_ip "salt set-master $new_admin_ip"
    fi

    if [ -n "$nodes_ips_changed" ] ; then
      log "Restarting Salt minion"
      do_ssh root@$node_ip "systemctl restart salt-minion"
    fi

  	#echo ">>> Checking NTP service"
  	#do_ssh root@$node_ip "systemctl is-active ntpd &>/dev/null || systemctl restart ntpd"
  done
fi

exit 0
