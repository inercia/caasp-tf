#!/bin/sh
# Sample udhcpc renew script

RESOLV_CONF="/etc/resolv.conf"

[ -n "$broadcast" ] && BROADCAST="broadcast $broadcast"
[ -n "$subnet" ] && NETMASK="netmask $subnet"

echo ">>> Configuring $interface -> $ip $BROADCAST $NETMASK"
/usr/bin/ifconfig $interface $ip $BROADCAST $NETMASK
