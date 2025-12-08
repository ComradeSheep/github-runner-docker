# GitHub Actions Self-Hosted Runner
# Base: Ubuntu 22.04 LTS (well-supported, stable, works great on Docker Desktop)

FROM ubuntu:22.04

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Runner version - update this when new versions are released
ARG RUNNER_VERSION=2.329.0

# Create a non-root user for the runner (GitHub runners shouldn't run as root)
ARG RUNNER_USER=runner
ARG RUNNER_UID=1000
ARG RUNNER_GID=1000

# Labels for documentation
LABEL description="GitHub Actions Self-Hosted Runner"
LABEL runner.version="${RUNNER_VERSION}"

# =============================================================================
# STEP 1: Install system dependencies
# =============================================================================
RUN apt-get update && apt-get install -y \
    # Essential tools
    curl \
    wget \
    git \
    jq \
    unzip \
    zip \
    # Build essentials (common for CI/CD workflows)
    build-essential \
    # SSL/TLS support
    ca-certificates \
    # Process management
    supervisor \
    # Additional utilities
    sudo \
    gnupg \
    lsb-release \
    software-properties-common \
    # Clean up apt cache to reduce image size
    && rm -rf /var/lib/apt/lists/*

# =============================================================================
# STEP 2: Create runner user and set up directories
# =============================================================================
RUN groupadd -g ${RUNNER_GID} ${RUNNER_USER} \
    && useradd -m -u ${RUNNER_UID} -g ${RUNNER_GID} -s /bin/bash ${RUNNER_USER} \
    && echo "${RUNNER_USER} ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# =============================================================================
# STEP 3: Download and extract GitHub Actions Runner
# =============================================================================
WORKDIR /home/${RUNNER_USER}/actions-runner

RUN curl -o actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz -L \
    https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz \
    && tar xzf actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz \
    && rm actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz

# =============================================================================
# STEP 4: Install runner dependencies
# =============================================================================
RUN ./bin/installdependencies.sh

# =============================================================================
# STEP 5: Set ownership and permissions
# =============================================================================
RUN chown -R ${RUNNER_USER}:${RUNNER_USER} /home/${RUNNER_USER}

# =============================================================================
# STEP 6: Copy entrypoint script
# =============================================================================
COPY --chmod=755 entrypoint.sh /entrypoint.sh

# Switch to non-root user
USER ${RUNNER_USER}
WORKDIR /home/${RUNNER_USER}/actions-runner

# =============================================================================
# STEP 7: Define volumes for persistence
# These directories contain configuration and work data that should persist
# =============================================================================
# .credentials, .credentials_rsaparams, .runner - Authentication & config
# _diag - Diagnostic logs
# _work - Job workspace

VOLUME ["/home/runner/actions-runner/_work"]

# Entrypoint handles configuration and startup
ENTRYPOINT ["/entrypoint.sh"]