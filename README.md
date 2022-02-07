## About

The Terraform configuration provided here was originally intended to
easily spin up a bare-metal arm64 instance on AWS running NixOS. This is
useful to people that want to make changes to nixpkgs but don't
necessarily have arm64 devices to test on.

The script is meant to be run on the EC2 instance. It updates NixOS and
builds (runs) the tests the NixOS Hadoop module offers, logging
everything. If something were to fail, it destroys the infrastructure it
provisioned to avoid excess bills.

Since testing NixOS modules requires the use of `/dev/kvm`, by and large
the Terraform configuration should be provided with an `instance_type`
ending in `.metal`.

### Usage

Hop into a new shell with the tools you'll need by running
`nix develop`.

Create an SSH key and provision and update an instance by running
`build-instance.sh`.

Create a ramdisk, a local nix store on the ramdisk, and build Hadoop's
NixOS tests by running `run-tests.sh`.

If any part of `build-instance.sh` or `run-tests.sh` fails, it should
destroy the infrastructure that has been created to avoid excess
billing.

The infrastructure can also manually be destroyed by running
`terraform -chdir=terraform destroy -auto-approve`.
