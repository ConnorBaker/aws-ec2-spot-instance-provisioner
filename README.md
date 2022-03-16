# AWS EC2 Spot Instance Provisioner

[![built with nix](https://builtwithnix.org/badge.svg)](https://builtwithnix.org)

## About

The scripts in `scripts` provision an EC2 spot instance in Ohio (which
generally has the lowest costs of all the EC2 spot instances in the US)
running Amazon Linux 2022. They:

1.  Create a RAM-disk using TMPFS at `/nix`
2.  Install nix (so it lives on the RAM-disk)
3.  Enable nix's experimental features and unfree packages
4.  Install `htop` and `git` with `nix profile`
5.  Create a RAM-disk using TMPFS in the home directory

The scripts create logs of these actions.

The scripts should be run from the root directory (i.e.,
`./scripts/build-instance.sh`)

If a script were to fail, it should destroy the infrastructure it
provisioned to avoid excess bills.

*I am not responsible for any costs incurred through the use of these
scripts.*

### Note on testing NixOS modules

Testing NixOS modules requires the use of `/dev/kvm`, which are only
available on `instance_type`s ending in `.metal`. If you wish to test
NixOS modules, you can use `./scripts/own-instance-kvm.sh` to set the
proper permissions after running `./scripts/build-instance.sh`, but you
must make sure to change `./terraform/terraform.tfvars`.

## Usage

Hop into a new shell with the tools you'll need by running
`nix develop`.

Create the instance with `./scripts/build-instance.sh`. The script ends
by printing the command to connect to the instance.

Destroy the instance with `./scripts/destroy-instance.sh`.
