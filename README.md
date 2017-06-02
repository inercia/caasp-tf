
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
`linux` (specified on the Terraform variable `passwprd`).

# Cluster architecture

The cluster is made by 1 admin node and the number of generic nodes chosen by
the user.

All the nodes are based on the same CaaSP image and will have the same amount of
memory.

All of them have a cloud-init ISO attached to them to inject the cloud-init
configuration.

All the nodes are attached to the `default` network of libvirt. This is a network
that satisfies CaaSP's basic network requirement: there's a DHCP and a DNS
enabled but the DNS server is not able to resolve the names of the nodes inside
of that network.

# Creating the cluster

Steps to perform:

  * Configure the cluster the way you want (see above section).
  * Execute: `terraform apply`

At the end of the deployment you will see the IP address of the admin server.
Use the velum instance running inside of this node to deploy the CaaSP cluster.

## Using specific cluster profiles

There are some specific profiles that can be useful for adding some extra
behaviour for developers, QA people, etc.
Take a look at these profiles (and read the instructions on how to use them):

* the [development](profiles/devel) profile

These files could be used as templates for your own `terraform-local.tf` recipes...

