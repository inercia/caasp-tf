# Development profile

This is a development profile that includes additional resources for:

* copying the Salt code to the admin node
* copying the manifests to the admin node
* running custom provisioning scripts
* assigning roles to machines
* running the orchestration

**All these steps are optional**: they can be enabled/disabled by
setting some `TF_VAR_x`s.

## Using this profile

Enable this profile by doing:

```bash
make -C $PROJECT_ROOT_DIR dev-profile-apply
```

You can set some vars for modifying the cluster creation:

```bash
# you can run the Makefile target
cd $PROJECT_ROOT_DIR 
env TF_VAR_img_refresh="false" TF_VAR_orchestrate="true" make dev-apply
# or just Terraform
env TF_VAR_img_refresh="false" TF_VAR_orchestrate="true" terraform apply
```

It is a bit annoying to provide many vars in command line, so you can also
invoke Terraform with some _variables file(s)_, ie:

```bash
cd $PROJECT_ROOT_DIR 
terraform apply -var-file=profiles/images-staging-b.tfvars
```

## Removing this profile

```bash
make -C $PROJECT_ROOT_DIR dev-profile-clean
```

## Running custom scripts

You can add a `autorun.local.sh` script in `resources/{admin,nodes}/`
for being executed automatically when creating the cluster.

## Extending an existing profile

You can extend an exiting profile by adding your own `.local.tf` files
(these files will not be added to git). For example, you can run some
extra stuff in the Admin Node in the devel profile with:

```bash
cd $PROJECT_ROOT_DIR && cat <<EOF> profiles/devel/profile-devel-custom.local.tf
resource "null_resource" "run_extra_stuff" {
  # add any dependencies necessary with 'depends_on = []'

  connection {
    host     = "${libvirt_domain.admin.network_interface.0.addresses.0}"
    password = "${var.password}"
  }

  provisioner "remote-exec" {
    inline = [
      "echo 'Running extra stuff'",
    ]
  }
}
EOF
make dev-profile-apply
```

