#
# Author(s): Flavio Castelli <flavio@suse.com>
#            Alvaro Saurin <alvaro.saurin@suse.com>
#
# Copyright (c) 2017 SUSE LINUX GmbH, Nuernberg, Germany.
#
# All modifications and additions to the file contributed by third parties
# remain the property of their copyright owners, unless otherwise agreed
# upon. The license for this file, and modifications and additions to the
# file, is the same license as for the pristine package itself (unless the
# license for the pristine package is not an Open Source License, in which
# case the license is the MIT License). An "Open Source License" is a
# license that conforms to the Open Source Definition (Version 1.9)
# published by the Open Source Initiative.
#

#####################
# Cluster variables #
#####################

variable "libvirt_uri" {
  default     = "qemu:///system"
  description = "libvirt connection url - default to localhost"
}

variable "img_pool" {
  default     = "default"
  description = "pool to be used to store all the volumes"
}

variable "img_url_base" {
  type        = "string"
  default     = "http://download.suse.de/ibs/Devel:/CASP:/Head:/ControllerNode/images/"
  description = "URL to the CaaSP KVM image used for the Admin node"
}

variable "img_src_filename" {
  type        = "string"
  default     = ""
  description = "Force a specific filename"
}

variable "img" {
  type        = "string"
  default     = "images/2.0/caasp.qcow2"
  description = "remote URL or local copy (can be used in conjuction with img_url_base) of the image to use."
}

variable "img_regex" {
  type        = "string"
  default     = "SUSE-CaaS-Platform.*-KVM-and-Xen.*x86_64.*Build"
  description = "regex for selecting the image filename (ie, we will download '<img_url_base>/<img_regex>.qcow2')"
}

variable "img_refresh" {
  default     = "true"
  description = "Try to get the latest image (true/false)"
}

variable "img_down_extra_args" {
  default     = ""
  description = "Extra arguments for the images downloader"
}

variable "img_sudo_virsh" {
  default     = "local"
  description = "Run virsh wioth sudo on [local|remote|both]"
}

variable "nodes_count" {
  default     = 2
  description = "Number of non-admin nodes to be created"
}

variable "prefix" {
  type        = "string"
  default     = "caasp"
  description = "a prefix for resources"
}

variable "network" {
  type        = "string"
  default     = "default"
  description = "an existing network to use for the VMs"
}

variable "password" {
  type        = "string"
  default     = "linux"
  description = "password for sshing to the VMs"
}

variable "admin_memory" {
  default     = 3072
  description = "RAM of the Admin node (in bytes)"
}

variable "default_node_memory" {
  default     = 1536
  description = "default amount of RAM of the Nodes (in bytes)"
}

variable "nodes_memory" {
  default = {
    "3" = "1024"
    "4" = "1024"
    "5" = "1024"
  }

  description = "amount of RAM for some specific nodes"
}

#######################
# Cluster declaration #
#######################

provider "libvirt" {
  uri = "${var.libvirt_uri}"
}

#######################
# Base image          #
#######################

resource "null_resource" "download_caasp_image" {
  count = "${length(var.img_url_base) == 0 ? 0 : 1}"

  provisioner "local-exec" {
    command = "./support/tf/download-image.sh  --img-regex '${var.img_regex}' --sudo-virsh '${var.img_sudo_virsh}' --src-base '${var.img_url_base}' --refresh '${var.img_refresh}' --local '${var.img}' --upload-to-img '${var.prefix}_base_${basename(var.img)}' --upload-to-pool '${var.img_pool}' --src-filename '${var.img_src_filename}' ${var.img_down_extra_args}"
  }
}

##############
# Admin node #
##############

resource "libvirt_volume" "admin" {
  name             = "${var.prefix}_admin.qcow2"
  pool             = "${var.img_pool}"
  base_volume_name = "${var.prefix}_base_${basename(var.img)}"
  depends_on       = ["null_resource.download_caasp_image"]
}

data "template_file" "admin_cloud_init_user_data" {
  template = "${file("cloud-init/admin.cfg.tpl")}"

  vars {
    password = "${var.password}"
    hostname = "${var.prefix}-admin"
  }
}

resource "libvirt_cloudinit_disk" "admin" {
  name      = "${var.prefix}_admin_cloud_init.iso"
  pool      = "${var.img_pool}"
  user_data = "${data.template_file.admin_cloud_init_user_data.rendered}"
}

resource "libvirt_domain" "admin" {
  name      = "${var.prefix}-admin"
  memory    = "${var.admin_memory}"
  cloudinit = "${libvirt_cloudinit_disk.admin.id}"

  #cpu {
  #  feature {
  #    policy = "require"
  #    name   = "pcid"
  #  }
  #}

  disk {
    volume_id = "${libvirt_volume.admin.id}"
  }
  network_interface {
    network_name   = "${var.network}"
    wait_for_lease = 1
  }
  graphics {
    type        = "vnc"
    listen_type = "address"
  }
}

#output "ip_admin" {
#  value = "${libvirt_domain.admin.network_interface.0.addresses.0}"
#}

###########################
# Cluster non-admin nodes #
###########################

resource "libvirt_volume" "node" {
  count            = "${var.nodes_count}"
  name             = "${var.prefix}_node_${count.index}.qcow2"
  pool             = "${var.img_pool}"
  base_volume_name = "${var.prefix}_base_${basename(var.img)}"
  depends_on       = ["null_resource.download_caasp_image"]
}

data "template_file" "node_cloud_init_user_data" {
  count    = "${var.nodes_count}"
  template = "${file("cloud-init/node.cfg.tpl")}"

  vars {
    admin_node_ip = "${libvirt_domain.admin.network_interface.0.addresses.0}"
    password      = "${var.password}"
    hostname      = "${var.prefix}-node-${count.index}"
  }

  depends_on = ["libvirt_domain.admin"]
}

resource "libvirt_cloudinit_disk" "node" {
  count     = "${var.nodes_count}"
  name      = "${var.prefix}_node_cloud_init_${count.index}.iso"
  pool      = "${var.img_pool}"
  user_data = "${element(data.template_file.node_cloud_init_user_data.*.rendered, count.index)}"
}

resource "libvirt_domain" "node" {
  count      = "${var.nodes_count}"
  name       = "${var.prefix}-node-${count.index}"
  memory     = "${lookup(var.nodes_memory, count.index, var.default_node_memory)}"
  cloudinit  = "${element(libvirt_cloudinit_disk.node.*.id, count.index)}"
  depends_on = ["libvirt_domain.admin"]

  disk {
    volume_id = "${element(libvirt_volume.node.*.id, count.index)}"
  }

  network_interface {
    network_name   = "${var.network}"
    wait_for_lease = 1
  }

  graphics {
    type        = "vnc"
    listen_type = "address"
  }
}

#output "nodes" {
#  value = ["${libvirt_domain.node.*.network_interface.0.addresses.0}"]
#}

