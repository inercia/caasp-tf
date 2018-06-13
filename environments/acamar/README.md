# Steps


## Configure sshd on the remote end

  - add in "/etc/ssh/sshd_config"

```
PermitTunnel yes
PermitRootLogin yes
```

  - do a "systemctl reload sshd"
  - Add you public key to /root/ ssh/authorized_keys
  - chmod 600 /root/.ssh/authorized_keys
  - chmod 700 /root/.ssh
  - At this point you should be able to connect to this machine as root.
  Check you can do it.


## Configure ssh locally

  - add a local entry

```
    Host *.arch.suse.de
      Compression yes
      StrictHostKeyChecking no
      ForwardX11 no
      ForwardX11Trusted no
      KeepAlive yes
      User root
      IdentityFile <SOME_PATH>/.ssh/<SOME_KEY>
```

## Update libvirt

  - ssh root@<HOST>
  - add the virtualization repo:

```
zyyper ar http://download.opensuse.org/repositories/Virtualization/SLE_12 virtualization
```

  - then `zypper ref && zyper dup`


## Create a virsh pool

  - ssh root@<HOST>
  - run:

```
virsh pool-define /dev/stdin <<EOF
<pool type='dir'>
  <name>default</name>
  <target>
    <path>/var/lib/libvirt/images</path>
  </target>
</pool>
EOF

virsh pool-start default
virsh pool-autostart default
```

## Create a virsh network

  - ssh root@<HOST>
  - run:

```
virsh net-create /dev/stdin <<EOF
<network>
  <name>caasp-net</name>
  <uuid>ad3cc7b4-cc58-4fa1-8dd6-24fc4b8be0c0</uuid>
  <forward mode='nat'>
    <nat>
      <port start='1024' end='65535'/>
    </nat>
  </forward>
  <bridge name='virbr3' stp='on' delay='0'/>
  <mac address='52:54:00:03:f8:f2'/>
  <domain name='caasp-net'/>
  <ip address='192.168.113.1' netmask='255.255.255.0'>
    <dhcp>
      <range start='192.168.113.128' end='192.168.113.254'/>
    </dhcp>
  </ip>
</network>
EOF
```
