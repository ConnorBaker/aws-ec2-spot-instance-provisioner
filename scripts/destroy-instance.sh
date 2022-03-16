#! /usr/bin/env bash

source ./scripts/utils.sh

ROOT_WORKSPACE="$(pwd)"
LOG="$ROOT_WORKSPACE/$(iso_time)-destroy-instance.log"
log_info "Starting destroy-instance.sh and logging to $LOG..."
log_info "Workspace is $ROOT_WORKSPACE"

TERRAFORM_DIR="$ROOT_WORKSPACE/terraform"
[[ -d "$TERRAFORM_DIR" ]] ||
    log_error_and_exit "Expected terraform directory does not exist: $TERRAFORM_DIR"
log_info "Terraform directory is $TERRAFORM_DIR"

log_info "Running terraform destroy..."
terraform -chdir="$TERRAFORM_DIR" destroy -auto-approve -no-color 2>&1 |
    sed "s/^/    /" | tee -a "$LOG" ||
    log_error_and_exit "terraform destroy failed!"
log_info "Completed terraform destroy."
log_info "Finished destroy-instance.sh."

exit 0
