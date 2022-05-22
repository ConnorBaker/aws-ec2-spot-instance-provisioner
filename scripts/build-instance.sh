#! /usr/bin/env bash

source ./scripts/utils.sh

ROOT_WORKSPACE="$PWD"
LOG="$ROOT_WORKSPACE/$(iso_time)-build-instance.log"
log_info "Starting build-instance.sh and logging to $LOG..."
log_info "Workspace is $ROOT_WORKSPACE"

TERRAFORM_DIR="$ROOT_WORKSPACE/terraform"
[[ -d "$TERRAFORM_DIR" ]] ||
    log_error_and_exit "Expected terraform directory does not exist: $TERRAFORM_DIR"
log_info "Terraform directory is $TERRAFORM_DIR"

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

EC2_USERNAME=$(terraform -chdir="$TERRAFORM_DIR" output -raw instance_username)
log_info "EC2 username is $EC2_USERNAME"

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

log_info "Running commands to install nix..."
(
    ssh -T -i "$TERRAFORM_DIR/pk.pem" \
        -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
        "$EC2_USERNAME@$EC2_HOSTNAME" 2>&1 <<BUILD_INSTANCE_COMMANDS
set -eu -o pipefail
if command -v nix &> /dev/null
then
    echo "nix is already installed."
    exit 0
fi
mkdir -p ~/.config/{nix,nixpkgs,htop}
cat >~/.config/nix/nix.conf <<EOF
bash-prompt = λ.
experimental-features = nix-command flakes
system-features = benchmark big-parallel
max-jobs = auto
http-connections = 0
substitute = true
fallback = true
substituters = https://cache.nixos.org https://nix-community.cachix.org https://hydra.iohk.io https://cache.ngi0.nixos.org
trusted-public-keys = cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY= nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs= hydra.iohk.io:f/Ea+s+dFdN+3Y/G+FDgSq+a5NEWhJGzdjvKNGv0/EQ= cache.ngi0.nixos.org-1:KqH5CBLNSyX184S9BKZJo1LxrxJ9ltnY2uAs5c/f1MA=
EOF
cat >~/.config/htop/htoprc <<EOF
# Beware! This file is rewritten by htop when settings are changed in the interface.
# The parser is also very primitive, and not human-friendly.
htop_version=3.1.2
config_reader_min_version=2
fields=0 48 17 18 38 39 40 2 46 47 49 1
sort_key=46
sort_direction=-1
tree_sort_key=0
tree_sort_direction=1
hide_kernel_threads=1
hide_userland_threads=0
shadow_other_users=0
show_thread_names=0
show_program_path=1
highlight_base_name=1
highlight_deleted_exe=1
highlight_megabytes=1
highlight_threads=1
highlight_changes=0
highlight_changes_delay_secs=5
find_comm_in_cmdline=1
strip_exe_from_cmdline=1
show_merged_command=0
tree_view=0
tree_view_always_by_pid=0
all_branches_collapsed=0
header_margin=0
detailed_cpu_time=0
cpu_count_from_one=0
show_cpu_usage=1
show_cpu_frequency=1
show_cpu_temperature=0
degree_fahrenheit=0
update_process_names=0
account_guest_in_cpu_meter=0
color_scheme=0
enable_mouse=1
delay=15
hide_function_bar=0
header_layout=two_50_50
column_meters_0=LeftCPUs DiskIO NetworkIO
column_meter_modes_0=1 1 1
column_meters_1=RightCPUs CPU Memory
column_meter_modes_1=1 1 1
EOF
curl -L https://nixos.org/nix/install | sh
. ~/.nix-profile/etc/profile.d/nix.sh
nix profile install nixpkgs/nixpkgs-unstable#{git,htop,cachix}
BUILD_INSTANCE_COMMANDS
) | sed "s/^/    /" | tee -a "$LOG" || terraform_cleanup
log_info "Finished updating instance."
log_info "Finished build-instance.sh."
log_info "Instance is running and available with ssh -i $TERRAFORM_DIR/pk.pem $EC2_USERNAME@$EC2_HOSTNAME"
exit 0
