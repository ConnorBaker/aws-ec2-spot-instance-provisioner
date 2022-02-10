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
LOG="$ROOT_WORKSPACE/$(iso_time)-build-instance.log"
log_info "Starting build-instance.sh and logging to $LOG..."
log_info "Workspace is $ROOT_WORKSPACE"

TERRAFORM_DIR="$ROOT_WORKSPACE/terraform"
[[ -d "$TERRAFORM_DIR" ]] ||
    log_error_and_exit "Expected terraform directory does not exist: $TERRAFORM_DIR"
log_info "Terraform directory is $TERRAFORM_DIR"

SSH_KEYS_DIR="$ROOT_WORKSPACE/ssh_keys"
if [[ -d "$SSH_KEYS_DIR" ]]; then
    log_info "SSH keys directory is $SSH_KEYS_DIR"
else
    log_info "Didn't find SSH keys directory $SSH_KEYS_DIR, creating it..."
    mkdir -p "$SSH_KEYS_DIR" ||
        log_error_and_exit "Unable to create SSH keys directory $SSH_KEYS_DIR"
fi

if [[ -f "$SSH_KEYS_DIR/id_ed25519" && -f "$SSH_KEYS_DIR/id_ed25519.pub" ]]; then
    log_info "Found SSH keys $SSH_KEYS_DIR/id_ed25519 and $SSH_KEYS_DIR/id_ed25519.pub"
else
    log_info "SSH keys don't exist in $SSH_KEYS_DIR, creating them..."
    ssh-keygen -t ed25519 -f "$SSH_KEYS_DIR/id_ed25519" -N "" ||
        log_error_and_exit "Unable to create ssh keys to put in $SSH_KEYS_DIR."
    chmod 0400 "$SSH_KEYS_DIR/id_ed25519" "$SSH_KEYS_DIR/id_ed25519.pub" ||
        log_error_and_exit "Unable to chmod 0400 ssh keys $SSH_KEYS_DIR/id_ed25519 and $SSH_KEYS_DIR/id_ed25519.pub."
    log_info "Created SSH keys $SSH_KEYS_DIR/id_ed25519 and $SSH_KEYS_DIR/id_ed25519.pub."
fi

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
log_info "Finished provisioning EC2."

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

log_info "Running commands to update instance to nixos-unstable..."
(
    ssh -T -i "$SSH_KEYS_DIR/id_ed25519" \
        -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
        "root@$EC2_HOSTNAME" 2>&1 <<BUILD_INSTANCE_COMMANDS
set -eu -o pipefail

mkdir -p ~/.config/{nix,nixpkgs}
cat >~/.config/nixpkgs/config.nix <<EOF
{
  allowUnfree = true;
}
EOF
cat >~/.config/nix/nix.conf <<EOF
system-features = nixos-test benchmark big-parallel kvm
experimental-features = nix-command flakes
EOF

nix-channel --add https://nixos.org/channels/nixos-unstable nixos
nixos-rebuild switch --upgrade
BUILD_INSTANCE_COMMANDS
) | sed "s/^/    /" | tee -a "$LOG" || terraform_cleanup
log_info "Finished updating instance."
log_info "Finished build-instance.sh."
log_info "Instance is running and available with ssh -i $SSH_KEYS_DIR/id_ed25519 root@$EC2_HOSTNAME"

exit 0
