#! /usr/bin/env bash

# Error on failure
set -eu -o pipefail

function iso_time() {
    date -u +"%Y-%m-%dT%H:%M:%SZ"
}

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

ROOT_WORKSPACE="$(pwd)"
LOG="$ROOT_WORKSPACE/$(iso_time)-run-tests.log"
log_info "Starting run-tests.sh and logging to $LOG..."
log_info "Workspace is $ROOT_WORKSPACE"

TERRAFORM_DIR="$ROOT_WORKSPACE/terraform"
[[ -d "$TERRAFORM_DIR" ]] ||
    log_error_and_exit "Expected terraform directory does not exist: $TERRAFORM_DIR"
log_info "Terraform directory is $TERRAFORM_DIR"

SSH_KEYS_DIR="$ROOT_WORKSPACE/ssh_keys"
[[ -d "$SSH_KEYS_DIR" ]] ||
    log_error_and_exit "Expected ssh_keys directory does not exist: $SSH_KEYS_DIR"
log_info "SSH keys directory is $SSH_KEYS_DIR"

[[ -f "$SSH_KEYS_DIR/id_ed25519" && -f "$SSH_KEYS_DIR/id_ed25519.pub" ]] ||
    log_error_and_exit "SSH keys don't exist in $SSH_KEYS_DIR, make sure you run build-instance.sh first."
log_info "Found SSH keys $SSH_KEYS_DIR/id_ed25519 and $SSH_KEYS_DIR/id_ed25519.pub"

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

log_info "Running build command on $EC2_HOSTNAME..."
(
    ssh -T -i "$SSH_KEYS_DIR/id_ed25519" \
        -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
        "root@$EC2_HOSTNAME" 2>&1 <<"TESTS_SCRIPT"
set -eu -o pipefail

# Own /dev/kvm
echo "Owning /dev/kvm"
chmod 0666 /dev/kvm
echo "Successfully owned /dev/kvm"

# Clean up the ramdisk if it already exists
echo "Checking if ~/ramdisk exists..."
if [[ -d ~/ramdisk ]]; then
    echo "~/ramdisk exists, umounting and cleaning it up..."
    umount ~/ramdisk
    mount -t tmpfs none ~/ramdisk
    echo "Cleaned up and re-mounted ~/ramdisk."
else
    echo "~/ramdisk does not exist, creating it and mounting it..."
    mkdir ~/ramdisk
    mount -t tmpfs none ~/ramdisk
    echo "Created and mounted ~/ramdisk."
fi

# Point nix to the local store on the ramdisk and enable more features
sed -i "s#^store.*#store = $HOME/ramdisk#" ~/.config/nix/nix.conf
echo "Pointed nix to the local store on the ramdisk."

# Copy and unpack nixpkgs
mkdir -p ~/ramdisk/workspace/nixpkgs
echo "Created workspace for nixpkgs at ~/ramdisk/workspace/nixpkgs"
echo "Copying nixpkgs from https://github.com/ConnorBaker/nixpkgs/archive/refs/heads/nixpkgs-unstable..."
curl --silent -L https://github.com/ConnorBaker/nixpkgs/archive/refs/heads/nixpkgs-unstable.tar.gz |
  tar -xz --directory ~/ramdisk/workspace/nixpkgs --strip-components 1
echo "Extracted nixpkgs from https://github.com/ConnorBaker/nixpkgs/archive/refs/heads/nixpkgs-unstable.tar.gz"

# Build the test for hadoop
cd ~/ramdisk/workspace
echo "Entered workspace ~/ramdisk/workspace."

# nix build -f ./nixpkgs/nixos/tests/hadoop/hadoop.nix --print-build-logs 2>&1
TESTS_SCRIPT
) | sed "s/^/    /" | tee -a "$LOG" || terraform_cleanup
log_info "Running build command."
log_info "Finished run-tests.sh"
log_info "Instance is running and available with ssh -i $SSH_KEYS_DIR/id_ed25519 root@$EC2_HOSTNAME"

exit 0
