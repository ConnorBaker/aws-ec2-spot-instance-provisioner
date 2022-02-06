#! /usr/bin/env bash

# Error on failure
set -eu -o pipefail

function iso_time() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

LOG="$(pwd)/$(iso_time)-run.log"

function log_msg() {
  echo "[$(iso_time)]$1 $2" 2>&1 | tee -a "$LOG"
}

function log_info() {
  log_msg "[INFO]" "$1"
}

function log_warning() {
  log_msg "[WARNING]" "$1"
}

function log_error() {
  log_msg "[ERROR]" "$1"
}

function log_error_and_exit() {
  log_error "$1"
  exit 1
}

function terraform_cleanup() {
  log_error "An error occurred. Please check the logs."
  log_info "Destroying deployed infrastructure..."
  terraform -chdir="$TERRAFORM_DIR" destroy -auto-approve -no-color 2>&1 |
    sed "s/^/    /" | tee -a "$LOG" ||
    log_error_and_exit "terraform destroy failed: Manual intervention is required!"
  log_info "Deployed infrastructure was successfully destroyed."
  exit 1
}

log_info "Starting..."

ROOT_WORKSPACE="$(pwd)"
log_info "Workspace is $ROOT_WORKSPACE"

TERRAFORM_DIR="$ROOT_WORKSPACE/terraform"
[[ -d "$TERRAFORM_DIR" ]] ||
  log_error_and_exit "Expected terraform directory does not exist: $TERRAFORM_DIR"
log_info "Terraform directory is $TERRAFORM_DIR"

NIX_OUTPUT_DIR="$ROOT_WORKSPACE/result"
[[ -d "$NIX_OUTPUT_DIR" ]] ||
  log_error_and_exit "Expected nix build output directory does not exist: $NIX_OUTPUT_DIR"
log_info "Nix build output directory is $NIX_OUTPUT_DIR"

log_info "Running terraform init..."
terraform -chdir="$TERRAFORM_DIR" init -no-color 2>&1 |
  sed "s/^/    /" | tee -a "$LOG" ||
  log_error_and_exit "terraform init failed!"
log_info "Completed terraform init."

log_info "Running terraform apply..."
terraform -chdir="$TERRAFORM_DIR" apply -auto-approve -no-color 2>&1 |
  sed "s/^/    /" | tee -a "$LOG" ||
  log_error_and_exit "terraform apply failed!"
log_info "Completed terraform apply."
log_info "Finished provisioning EC2"

EC2_HOSTNAME=$(terraform -chdir="$TERRAFORM_DIR" output -raw instance_public_dns)
log_info "EC2 hostname is $EC2_HOSTNAME"

log_info "Waiting for $EC2_HOSTNAME ssh to open..."
((count = 60)) # Maximum number to try.
ssh_port_status="$(nmap -Pn "$EC2_HOSTNAME" -p ssh | grep open || echo "closed")"
while [[ $count -ne 0 && $ssh_port_status != "22/tcp open  ssh" ]]; do
  log_info "SSH port is not open yet. Retrying in 10 seconds."
  sleep 10 # Minimise network storm.
  ssh_port_status="$(nmap -Pn "$EC2_HOSTNAME" -p ssh | grep open || echo "closed")"
  ((count--)) # So we don't go forever.
done

if [[ $ssh_port_status != "22/tcp open  ssh" ]]; then # Make final determination.
  log_error "$EC2_HOSTNAME still doesn't have SSH open."
  terraform_cleanup
else
  log_info "$EC2_HOSTNAME has SSH open."
fi

log_info "Running inititialization commands..."
(
  ssh -i "$NIX_OUTPUT_DIR/ssh/id_ed25519" \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    "root@$EC2_HOSTNAME" 2>&1 <<INIT_SCRIPT
set -eu

mkdir -p ~/.config/nixpkgs
cat >~/.config/nixpkgs/config.nix <<EOF
{
  allowUnfree = true;
}
EOF

nix-channel --add https://nixos.org/channels/nixos-unstable nixos
nixos-rebuild switch --upgrade
mkdir -p ~/.config/nix
cat >~/.config/nix/nix.conf <<EOF
system-features = nixos-test benchmark big-parallel kvm
experimental-features = nix-command flakes
EOF
INIT_SCRIPT
) | sed "s/^/    /" | tee -a "$LOG" || terraform_cleanup
log_info "Finished running init.sh"

log_info "Running build command..."
(
  ssh -i "$NIX_OUTPUT_DIR/ssh/id_ed25519" \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    "root@$EC2_HOSTNAME" 2>&1 <<"INIT_SCRIPT"
set -eu

# Own /dev/kvm
chmod 0666 /dev/kvm

# Make ramdisk
mkdir ~/ramdisk
mount -t tmpfs none ~/ramdisk
mkdir -p ~/ramdisk/workspace/nixpkgs

# Point nix to the local store on the ramdisk and enable more features
(
  cat >>~/.config/nix/nix.conf <<EOF
store = $HOME/ramdisk
EOF
)

# Copy and unpack nixpkgs
curl --silent -L https://github.com/ConnorBaker/nixpkgs/archive/refs/heads/nixpkgs-unstable.tar.gz |
  tar -xz --directory ~/ramdisk/workspace/nixpkgs --strip-components 1

# Build the test for hadoop
cd ~/ramdisk/workspace

nix build -f ./nixpkgs/nixos/tests/hadoop/hadoop.nix --print-build-logs 2>&1
INIT_SCRIPT
) | sed "s/^/    /" | tee -a "$LOG" || terraform_cleanup
log_info "Finished running build script"

log_info "Destroying deployed infrastructure..."
terraform -chdir="$TERRAFORM_DIR" destroy -auto-approve -no-color 2>&1 |
  sed "s/^/    /" | tee -a "$LOG" ||
  log_error_and_exit "terraform destroy failed: Manual intervention is required!"
log_info "Deployed infrastructure was successfully destroyed."
log_info "All done!"
exit 0
