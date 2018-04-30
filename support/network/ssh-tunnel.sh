#!/bin/bash
###############################################################
#
# Example: create a local interface that can route to
#          192.168.113.0/24 from tupperware
#
# ./ssh-tunnel.sh --sudo -i ~/.ssh/alvaro@suse \
#       --route-to 192.168.113.0/24 tupperware
#
# Example: create a local interface that is connected
#          to the remote bridge "virbr3" in "tupperware"
#
# ./ssh-tunnel.sh --sudo -i ~/.ssh/alvaro@suse \
#      --tap --tap-rbridge virbr3 tupperware
#
# NOTES:
#
# Make sure the remote sshd has "PermitTunnel yes"
# in "/etc/ssh/sshd_config". Otherwise, this will
# not work...
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
EXTRA_OPTS='-o ServerAliveInterval=10 -o TCPKeepAlive=yes'

# Local and remote tunnel devices (ie, 5 for tun5/tap5)
LOCAL_DEV=5
REMOTE_DEV=5

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

# Load any previous values here
if [[ -f $STATE_FILE ]] ; then
  echo ">>> Loading $STATE_FILE"
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
  echo ">>> FATAL: tunnel type $TUNNEL_TYPE not supported"
  exit 1
fi

FULL_LOCAL_DEV=$DEV_TYPE$LOCAL_DEV
FULL_REMOTE_DEV=$DEV_TYPE$REMOTE_DEV

##############################################################

if [[ -n "$STOP" ]] ; then
  echo ">>> Killing ssh"
  PID=$(ps ax | grep ssh 2>/dev/null | grep $REMOTE 2>/dev/null | grep Tunnel=$TUNNEL_TYPE 2>/dev/null | awk '{ print $1 }')
  [ -n "$PID" ] && $SUDO_CMD kill $PID

  if [[ "$TUNNEL_TYPE" = "point-to-point" ]] ; then
    echo ">>> Nothing else to do for a point-to-point connection"
  elif [[ "$TUNNEL_TYPE" = "ethernet" ]] ; then
    if [[ -n "$KEY" ]] && [[ -n "$REMOTE" ]] && [[ -n "$TAP_RBRIDGE" ]] ; then
      echo ">>> Removing remote tap device at $REMOTE"
      ssh -i $KEY $REMOTE "brctl delif $TAP_RBRIDGE $FULL_REMOTE_DEV"
    fi

    echo ">>> Current local bridges:"
    $SUDO_CMD brctl show
  fi

  rm -f $STATE_FILE
  exit 0
fi

##############################################################

if [[ -n "$STATE_LOADED" ]] ; then
  grep -q "$FULL_LOCAL_DEV:" /proc/net/dev
  if [[ $? -ne 0 ]] ; then
    echo ">>> Tunnel service seems to be down: forcing restart"
    rm -f $STATE_FILE
  else
    echo ">>> It seems there is already a connection to $REMOTE: nothing to do... bye!"
    exit 0
  fi
fi

if [[ -z "$REMOTE" ]] ; then
  echo ">>> FATAL: no remote end provided"
  exit 1
fi

if [[ -z "$KEY" ]] ; then
  echo ">>> FATAL: no key provided"
  exit 1
fi

SSH_ARGS="-f -o Tunnel=$TUNNEL_TYPE \
          -o NumberOfPasswordPrompts=0 $EXTRA_OPTS \
          -i $KEY \
	        -w $LOCAL_DEV:$REMOTE_DEV \
          -l $REMOTE_USERNAME -p $PORT"

if [[ -n "$DEBUG" ]] ; then
  SSH_ARGS="-v $SSH_ARGS"
fi

if [[ "$TUNNEL_TYPE" = "point-to-point" ]] ; then
  SSH_REMOTE_CMD="/sbin/ifconfig $FULL_REMOTE_DEV $REMOTE_IP netmask $NETMASK pointopoint $LOCAL_IP up"
elif [[ "$TUNNEL_TYPE" = "ethernet" ]] ; then
  SSH_REMOTE_CMD="ifconfig $FULL_REMOTE_DEV up && brctl addif $TAP_RBRIDGE $FULL_REMOTE_DEV"
fi

echo ">>> Starting ssh connection..."
if ! $SUDO_CMD ssh $SSH_ARGS $REMOTE "$SSH_REMOTE_CMD" ; then
  echo ">>> FATAL: ssh command failed"
  exit 1
fi

echo ">>> Saving ssh state to $STATE_FILE"
echo "REMOTE=$REMOTE"                      > $STATE_FILE
echo "SUDO=$SUDO"                         >> $STATE_FILE
echo "TUNNEL_TYPE=$TUNNEL_TYPE"           >> $STATE_FILE
echo "ROUTE_TO=$ROUTE_TO"                 >> $STATE_FILE
echo "TAP_RBRIDGE=$TAP_RBRIDGE"           >> $STATE_FILE
echo "KEY=$KEY"                           >> $STATE_FILE

if [[ "$TUNNEL_TYPE" = "point-to-point" ]] ; then
  echo ">>> Configuring local interface"
  $SUDO_CMD ifconfig $FULL_LOCAL_DEV $LOCAL_IP \
    netmask $NETMASK \
    pointopoint $REMOTE_IP up

  if [[ -n "$ROUTE_TO" ]] ; then
    echo ">>> Adding route to $ROUTE_TO via $FULL_LOCAL_DEV"
    $SUDO_CMD ip route add $ROUTE_TO via $REMOTE_IP dev $FULL_LOCAL_DEV
  fi

elif [[ "$TUNNEL_TYPE" = "ethernet" ]] ; then
  sleep 5

  echo ">>> Setting $FULL_LOCAL_DEV up"
  $SUDO_CMD ifconfig $FULL_LOCAL_DEV promisc up

  echo ">>> Obtaining a IP address with DHCP on $FULL_LOCAL_DEV"
  # $SUDO_CMD dhclient $FULL_LOCAL_DEV
  $SUDO_CMD udhcpc -i $FULL_LOCAL_DEV -n -f -q

  echo ">>> Detatils on $FULL_LOCAL_DEV"
  $SUDO_CMD ifconfig $FULL_LOCAL_DEV

  route_line=$(ip route | grep "default via" 2>/dev/null | grep "dev $FULL_LOCAL_DEV" 2>/dev/null)
  if [[ -n "$route_line" ]] ; then
    echo ">>> Removing route: $route_line"
    $SUDO_CMD ip route del $route_line
  fi

  echo ">>> Default route"
  $SUDO_CMD ip route | grep "default via" 2>/dev/null

  echo ">>> Routes via $FULL_LOCAL_DEV"
  $SUDO_CMD ip route | grep "dev $FULL_LOCAL_DEV" 2>/dev/null
fi
