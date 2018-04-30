#cloud-config

# set locale
locale: fr_FR.UTF-8

# set timezone
timezone: Europe/Paris
hostname: ${hostname}
fqdn: ${hostname}.suse.de

# set root password
chpasswd:
  list: |
    root:${password}
  expire: False

users:
  - name: qa
    gecos: User
    sudo: ["ALL=(ALL) NOPASSWD:ALL"]
    groups: users
    lock_passwd: false
    passwd: ${password}

# set as admin node
suse_caasp:
  role: admin

# setup and enable ntp
ntp:
  servers:
    - ntp1.suse.de
    - ntp2.suse.de
    - ntp3.suse.de

runcmd:
  - /usr/bin/systemctl enable --now ntpd
  - sed -i -e 's/DHCLIENT_SET_HOSTNAME="yes"/DHCLIENT_SET_HOSTNAME="no"/g' /etc/sysconfig/network/dhcp
  
# enable and run the SUSE CaaSP administrative dashboard
#runcmd:
#  - [ sh, -c, /usr/share/caasp-container-manifests/activate.sh ]

final_message: "The system is finally up, after $UPTIME seconds"
