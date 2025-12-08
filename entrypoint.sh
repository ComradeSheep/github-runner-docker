#!/bin/bash
set -e

# =============================================================================
# GitHub Actions Runner Entrypoint Script
# Handles first-time configuration and subsequent starts
# =============================================================================

RUNNER_DIR="/home/runner/actions-runner"
CONFIG_FILE="${RUNNER_DIR}/.runner"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# =============================================================================
# Graceful shutdown handler
# =============================================================================
cleanup() {
    log_info "Caught shutdown signal, removing runner..."
    if [ -f "${CONFIG_FILE}" ] && [ -n "${RUNNER_TOKEN}" ]; then
        ./config.sh remove --token "${RUNNER_TOKEN}" || true
    fi
    exit 0
}

trap 'cleanup' SIGTERM SIGINT

# =============================================================================
# Check if runner is already configured
# =============================================================================
if [ -f "${CONFIG_FILE}" ]; then
    log_info "Runner is already configured. Starting runner..."
    log_info "To reconfigure, remove the container volume and restart."
else
    # =============================================================================
    # First-time configuration
    # =============================================================================
    log_info "Runner not configured. Starting configuration..."
    
    # Validate required environment variables
    if [ -z "${RUNNER_URL}" ]; then
        log_error "RUNNER_URL environment variable is required!"
        log_error "Example: -e RUNNER_URL=https://github.com/owner/repo"
        exit 1
    fi
    
    if [ -z "${RUNNER_TOKEN}" ]; then
        log_error "RUNNER_TOKEN environment variable is required!"
        log_error "Generate one at: ${RUNNER_URL}/settings/actions/runners/new"
        exit 1
    fi
    
    # Set defaults for optional variables
    RUNNER_NAME="${RUNNER_NAME:-$(hostname)}"
    RUNNER_LABELS="${RUNNER_LABELS:-docker,linux,x64}"
    RUNNER_WORKDIR="${RUNNER_WORKDIR:-_work}"
    RUNNER_GROUP="${RUNNER_GROUP:-Default}"
    
    log_info "Configuring runner with:"
    log_info "  URL: ${RUNNER_URL}"
    log_info "  Name: ${RUNNER_NAME}"
    log_info "  Labels: ${RUNNER_LABELS}"
    log_info "  Work Directory: ${RUNNER_WORKDIR}"
    
    # Build configuration command
    CONFIG_CMD="./config.sh --url ${RUNNER_URL} --token ${RUNNER_TOKEN}"
    CONFIG_CMD="${CONFIG_CMD} --name ${RUNNER_NAME}"
    CONFIG_CMD="${CONFIG_CMD} --labels ${RUNNER_LABELS}"
    CONFIG_CMD="${CONFIG_CMD} --work ${RUNNER_WORKDIR}"
    CONFIG_CMD="${CONFIG_CMD} --runnergroup ${RUNNER_GROUP}"
    CONFIG_CMD="${CONFIG_CMD} --unattended"
    CONFIG_CMD="${CONFIG_CMD} --replace"
    
    # Execute configuration
    log_info "Running configuration..."
    eval ${CONFIG_CMD}
    
    if [ $? -eq 0 ]; then
        log_info "Configuration successful!"
    else
        log_error "Configuration failed!"
        exit 1
    fi
fi

# =============================================================================
# Start the runner
# =============================================================================
log_info "Starting GitHub Actions Runner..."
log_info "Runner is ready and waiting for jobs."

# Run the runner (this blocks until the runner exits)
./run.sh &

# Wait for the runner process
wait $!
