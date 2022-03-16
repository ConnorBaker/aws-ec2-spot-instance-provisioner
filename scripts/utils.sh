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
