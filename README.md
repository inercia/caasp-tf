
# Requirements

* `libvirt`
* [`terraform`](https://github.com/hashicorp/terraform)
* the [`terraform-provider-libvirt`](https://github.com/dmacvicar/terraform-provider-libvirt) plugin
* Some olter tools like `wget`, `sshpass`...

# Cluster configuration

The deployment can by tuned uses some terraform variables. All of them
are defined at the top of the `terraform.tf` file. Each variable has also a
description field that explains its purpose.

These are the most important ones:

  * `libvirt_uri`: by default this points to localhost, however it's possible
    to perform the deployment on a different libvirt machine. More on that later.
  * `img_src`: this is the URL of **a directory** where the CaaSP image
    can be found for creating the whole cluster. Note: the
    **latest version** of the image will be **automatically obtained**
    unless the `refresh` variables is set fo `false`.
  * `nodes_count`: number of non-admin nodes to be created.

The easiest way to set these values is by creating a `terraform.tfvars`. The
project comes with an example file named `terraform.tfvars.example`.

## cloud-init

The project comes with two cloud-init files: one for the admin node, the other
for the generic nodes.

Note well: the system is going to have a `root` and a `qa` users with password
`linux` (specified on the Terraform variable `password`).

# Cluster architecture

The cluster is made by 1 admin node and the number of generic nodes chosen by
the user.

All of them have a cloud-init ISO attached to them to inject the cloud-init
configuration.

All the nodes are attached to the `default` network of libvirt. This is a network
that satisfies CaaSP's basic network requirement: there's a DHCP and a DNS
enabled but the DNS server is not able to resolve the names of the nodes inside
of that network.

# Usage

These are some examples of what you can do with the `caasp` script:

* Create a cluster in the tupperware environment, with the
"fix_deployment" branch of Salt, orchestrating and then creating
a snapshot of the VMs

```
./caasp --env tupperware \
        --salt-src-branch fix_deployment \
        'cluster create ; salt wait ; orch boot ; cluster snapshot'
```

* Run the `tests/orchestration-simple.scene` script, but after the
`post-create` stage

```
./caasp --script tests/orchestration-simple.scene \
        --script-begin post-create
```

* Dump the `/etc/hosts` in any machine that matches `node-1`

```
./caasp @node-1 cat /etc/hosts
```

## First steps

* Run `./caasp cluster create` for creating the VMs in the _localhost_.
* Then run the bootstrap orchestration with `./caasp orch boot`.
* Finally, you can get a valid kubeconfig file with `./caasp orch kubeconfig`

You can also ssh to any machine with `./caasp ssh <name>`.

## Development mode

You can enable the _development mode_ by running `./caasp devel enable`. This will:

  * link the `terraform/profile-devel.tf` file into the top directory, adding features
  like copying Salt code, assigning roles, etc. Checkout the contents of this Terraform
  file. If it does not suit your needs, you can create your own development profile
  and use it with `./caasp --tf-devel-profile=<MY_PROFILE> devel enable`.
  * prior to any orchestration, it will sync the local Salt code directory with the
  directory in the Admin Node.
