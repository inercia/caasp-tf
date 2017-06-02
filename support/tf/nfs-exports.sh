#!/bin/sh

NETWORK="192.168.0.0/16"
ETC_EXPORTS="/etc/exports"

##################################################################################

log()   { echo ">>> $1" ; }
warn()  { log "WARNING: $1" ; }
abort() { log "FATAL: $1" ; exit 1 ; }

reload_nfs_config() {
	local status=$(systemctl is-active nfs-server)
    if [ "$status" = "active" ] ; then
	    systemctl reload nfs-server
	else
		systemctl start nfs-server
	fi
}

command=$1
directory=$(realpath $2)

case "$command" in
	add)
	    log "Adding $directory"
	    HOSTS_LINE="$directory    $NETWORK(rw,sync,no_subtree_check,no_root_squash)"
	    if [ -n "$(grep $directory $ETC_EXPORTS)" ] ; then
	            warn "$directory already exists."
	    else
	        log "Adding $directory to your $ETC_EXPORTS"
	        echo "$HOSTS_LINE" >> $ETC_EXPORTS

	        if [ -n "$(grep $directory $ETC_EXPORTS)" ] ; then
	            log "Directory added succesfully:"
	            log "$(grep $directory $ETC_EXPORTS)"
			    reload_nfs_config
	        else
	            warn "ERROR: failed to add $directory to $ETC_EXPORTS, Try again!"
	        fi
	    fi
		;;

	del)
	    log "Removing $directory"
	    if [ -n "$(grep $directory $ETC_EXPORTS)" ] ; then
	        log "$directory found in your $ETC_EXPORTS, removing now..."
	        sed -i".bak" "\|$directory|d" $ETC_EXPORTS
		    reload_nfs_config
	    else
	        warn "$directory was not found in your $ETC_EXPORTS"
	    fi
	    ;;

	*)
	    abort "Unknown argument $1"
	    ;;

esac
