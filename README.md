## About

The Terraform configuration provided here was originally intended to
easily spin up a bare-metal arm64 instance on AWS running NixOS; an
unpleasant but necessary task for those who do not have arm64 devices
but want to ensure that changes made to nixpkgs don't break anything.

The script is meant to be run on the EC2 instance. It updates NixOS,
builds (runs) the tests the NixOS Hadoop module offers, and then puts
the resulting artifacts in S3 (TODO). Since testing NixOS modules
requires the use of `/dev/kvm`, by and large the Terraform configuration
should be provided with an `instance_type` ending in `.metal`.
