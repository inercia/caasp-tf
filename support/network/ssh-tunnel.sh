#!/bin/bash
###############################################################
#
# Example: create a local interface that can route to
#          192.168.113.0/24 from tupperware
#
#      ./ssh-tunnel.sh --sudo -i ~/.ssh/alvaro@suse \
#            --route-to 192.168.113.0/24 tupperware
#
# Example: create a local interface that is connected
#          to the remote bridge "virbr3" in "tupperware"
#
#      ./ssh-tunnel.sh --sudo -i ~/.ssh/alvaro@suse \
#           --tap --tap-rbridge virbr3 tupperware
#
# REQUIREMENTS:
#
#    In the remote end:
#
#      - add "PermitTunnel yes" in "/etc/ssh/sshd_config"
#      - add "PermitRootLogin yes" in "/etc/ssh/sshd_config"
#      - add your ssh key
#      - do a "systemctl reload sshd"
#
###############################################################

# This is the WAN IP/hostname of the remote machine, and the key
REMOTE=
KEY=

# Remote username will usually be root, or any other privileged user
# who can open tun/tap devices on the remote host
REMOTE_USERNAME=root

# Remote IP in the tunnel
REMOTE_IP=192.168.7.1

# Local IP in the tunnel
LOCAL_IP=192.168.7.2

# Netmask to set (on both sides)
NETMASK=255.255.255.252

# SSH port to use
PORT=22

# MTU for tunnel
MTU=1500

# Extra SSH options, these would give us some nice keep alive
EXTRA_OPTS='-oCompression=yes -oServerAliveInterval=10 -oTCPKeepAlive=yes'

# Local and remote tunnel devices (ie, 5 for tun5/tap5)
LOCAL_DEV=6
REMOTE_DEV=6

# route to a specific subnet
ROUTE_TO=

# TUNNEL_TYPE: 'point-to-point' for tun or 'ethernet' for tap
TUNNEL_TYPE="point-to-point"

# state file for the ssh connection
STATE_FILE=/tmp/$(basename $0).state

DEBUG=
SUDO_CMD=
STOP=
TAP_RBRIDGE=
STATE_LOADED=

UP_SCRIPT=$(dirname $0)/ssh-tunnel-up.sh

now()   { date +'%Y-%m-%d %H:%M:%S' ; }
log()   { echo "# $(now) [INFO] $@" ; }
warn()  { echo "# $(now) [WARN] $@" ; }
abort() { echo "# $(now) [ERROR] $@" ; exit 1 ; }
quit()  { log "$@" ; exit 0 ; }

# Load any previous values here
if [[ -f $STATE_FILE ]] ; then
  log "Loading $STATE_FILE"
  . $STATE_FILE
  STATE_LOADED=1
fi

while [ $# -gt 0 ] ; do
  case $1 in
    --username)
      REMOTE_USERNAME=$2
      shift
      ;;
    --to)
      REMOTE=$2
      shift
      ;;
    -i|--key)
      KEY=$2
      shift
      ;;
    --rip)
      REMOTE_IP=$2
      shift
      ;;
    --lip)
      LOCAL_IP=$2
      shift
      ;;
    --ltun)
      LOCAL_DEV=$2
      shift
      ;;
    --rtun)
      REMOTE_DEV=$2
      shift
      ;;
    --route)
      ROUTE_TO=$2
      shift
      ;;
    --sudo)
      SUDO_CMD="sudo"
      ;;
    --tap)
      TUNNEL_TYPE="ethernet"
      ;;
    --tap-rbridge)
      TAP_RBRIDGE=$2
      shift
      ;;
    --debug|-v)
      set -x
      DEBUG=1
      ;;
    --stop|--kill|-S|-k)
      STOP=1
      ;;
    *)
      REMOTE=$1
      break
      ;;
  esac
  shift
done

if [[ "$TUNNEL_TYPE" = "point-to-point" ]] ; then
  DEV_TYPE="tun"
elif [[ "$TUNNEL_TYPE" = "ethernet" ]] ; then
  DEV_TYPE="tap"
else
  abort "tunnel type $TUNNEL_TYPE not supported"
fi

FULL_LOCAL_DEV=$DEV_TYPE$LOCAL_DEV
FULL_REMOTE_DEV=$DEV_TYPE$REMOTE_DEV

SSH_COMMON_ARGS="-t -t -i $KEY -l $REMOTE_USERNAME -p $PORT"

##############################################################
# stop service

ssh_pid() {
  ps ax | grep ssh               2>/dev/null | \
          grep Tunnel            2>/dev/null | \
          grep $KEY              2>/dev/null | \
          grep $REMOTE_USERNAME  2>/dev/null | \
          grep $PORT             2>/dev/null | \
          awk '{ print $1 }'
}

kill_ssh() {
  log "Killing ssh"
  local pid=$(ssh_pid)
  [[ -n "$pid" ]] && $SUDO_CMD kill $pid
}

remove_remote_tap() {
  log "Trying to remove $FULL_REMOTE_DEV from $TAP_RBRIDGE at $REMOTE"
  ssh $SSH_COMMON_ARGS $REMOTE \
    "brctl delif $TAP_RBRIDGE $FULL_REMOTE_DEV 2>/dev/null" || /bin/true
  ssh $SSH_COMMON_ARGS $REMOTE "brctl show" | grep $FULL_REMOTE_DEV 2>/dev/null
}

if [[ -n "$STOP" ]] ; then
  kill_ssh
  trap "log Removing $STATE_FILE ; rm -f $STATE_FILE ; exit 0" INT TERM EXIT

  if [[ "$TUNNEL_TYPE" = "point-to-point" ]] ; then
    log "Nothing else to do for a point-to-point connection"
  elif [[ "$TUNNEL_TYPE" = "ethernet" ]] ; then
    if [[ -n "$KEY" ]] && [[ -n "$REMOTE" ]] && [[ -n "$TAP_RBRIDGE" ]] ; then
      remove_remote_tap
    fi

    log "Current local bridges:"
    $SUDO_CMD brctl show
  fi

  exit 0
fi

##############################################################

if [[ -n "$STATE_LOADED" ]] ; then
  grep -q "$FULL_LOCAL_DEV:" /proc/net/dev
  pid=$(ssh_pid)
  if [[ $? -eq 0 ]] && [[ -n "$pid" ]] ; then
    log "Local interface $FULL_LOCAL_DEV already present (ssh $pid)"
    quit "It seems there is a connection to $REMOTE: nothing to do..."
  fi

  log "Tunnel device is not present: forcing restart"
  if [[ "$TUNNEL_TYPE" = "ethernet" ]] && [[ -n "$KEY" ]] && [[ -n "$REMOTE" ]] && [[ -n "$TAP_RBRIDGE" ]] ; then
    remove_remote_tap
  fi

  kill_ssh
  rm -f $STATE_FILE
fi

##############################################################

[[ -n "$REMOTE" ]] || abort "no remote end provided"
[[ -n "$KEY"    ]] || abort "no key provided"

SSH_ARGS="$SSH_COMMON_ARGS -f -o Tunnel=$TUNNEL_TYPE \
          -o NumberOfPasswordPrompts=0 $EXTRA_OPTS \
	        -w $LOCAL_DEV:$REMOTE_DEV"

if [[ -n "$DEBUG" ]] ; then
  SSH_ARGS="-v $SSH_ARGS"
fi

if [[ "$TUNNEL_TYPE" = "point-to-point" ]] ; then
  SSH_REMOTE_CMD="/sbin/ifconfig $FULL_REMOTE_DEV $REMOTE_IP netmask $NETMASK pointopoint $LOCAL_IP up"
elif [[ "$TUNNEL_TYPE" = "ethernet" ]] ; then
  SSH_REMOTE_CMD="ifconfig $FULL_REMOTE_DEV up && ( brctl delif $TAP_RBRIDGE $FULL_REMOTE_DEV 2>/dev/null || /bin/true ) && brctl addif $TAP_RBRIDGE $FULL_REMOTE_DEV"
fi

log "Starting ssh connection..."
$SUDO_CMD ssh $SSH_ARGS $REMOTE "$SSH_REMOTE_CMD" || abort "ssh command failed"
trap "kill_ssh ; rm -f $STATE_FILE" INT TERM

log "Saving ssh state to $STATE_FILE"
echo "REMOTE=$REMOTE"                      > $STATE_FILE
echo "SUDO=$SUDO"                         >> $STATE_FILE
echo "TUNNEL_TYPE=$TUNNEL_TYPE"           >> $STATE_FILE
echo "ROUTE_TO=$ROUTE_TO"                 >> $STATE_FILE
echo "TAP_RBRIDGE=$TAP_RBRIDGE"           >> $STATE_FILE
echo "KEY=$KEY"                           >> $STATE_FILE

if [[ "$TUNNEL_TYPE" = "point-to-point" ]] ; then
  log "Configuring local interface"
  $SUDO_CMD ifconfig $FULL_LOCAL_DEV $LOCAL_IP \
    netmask $NETMASK \
    pointopoint $REMOTE_IP up

  if [[ -n "$ROUTE_TO" ]] ; then
    log "Adding route to $ROUTE_TO via $FULL_LOCAL_DEV"
    $SUDO_CMD ip route add $ROUTE_TO via $REMOTE_IP dev $FULL_LOCAL_DEV
  fi

elif [[ "$TUNNEL_TYPE" = "ethernet" ]] ; then
  sleep 5

  log "Setting up local interface $FULL_LOCAL_DEV"
  $SUDO_CMD ifconfig $FULL_LOCAL_DEV promisc up || abort "could not setup local interface $FULL_LOCAL_DEV"

  log "Obtaining a IP address with DHCP on $FULL_LOCAL_DEV"
  # do not let udhcpc change the routes/DNS configuration
  # by using /bin/true as the script
  $SUDO_CMD udhcpc -i $FULL_LOCAL_DEV -n -f -q --script=$UP_SCRIPT || abort "could not get IP address"

  log "Detatils on $FULL_LOCAL_DEV"
  $SUDO_CMD ifconfig $FULL_LOCAL_DEV || abort "could not get interface details"

  route_line=$(ip route | grep "default via" 2>/dev/null | grep "dev $FULL_LOCAL_DEV" 2>/dev/null)
  if [[ -n "$route_line" ]] ; then
    log "Removing route: $route_line"
    $SUDO_CMD ip route del $route_line
  fi

  log "Default route"
  $SUDO_CMD ip route | grep "default via" 2>/dev/null || abort "while getting interface details"

  log "Routes via $FULL_LOCAL_DEV"
  $SUDO_CMD ip route | grep "dev $FULL_LOCAL_DEV" 2>/dev/null
fi

trap "quit Tunnel established" INT TERM

exit 0
