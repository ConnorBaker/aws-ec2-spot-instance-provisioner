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
