# Flux RPM Builder Container
# Pre-installed with all dependencies needed for RPM building and testing
#
# This container significantly speeds up CI workflows by eliminating
# the need to install packages on every run.

FROM fedora:latest

LABEL org.opencontainers.image.source="https://github.com/kush-gupt/flux-rpm"
LABEL org.opencontainers.image.description="Flux RPM build environment with pre-installed dependencies"
LABEL org.opencontainers.image.licenses="LGPL-3.0-only"

# Install all build dependencies in a single layer
RUN dnf install -y --setopt=install_weak_deps=False \
    # Core RPM build tools
    rpm-build \
    rpmdevtools \
    rpmlint \
    mock \
    # Source download tools
    wget \
    curl \
    # Spec file processing
    cpio \
    jq \
    # Git operations (for PRs)
    git \
    # Fast compression for actions/cache save/restore
    zstd \
    && dnf clean all \
    && rm -rf /var/cache/dnf

# Setup rpmbuild tree for root user
RUN rpmdev-setuptree

# Add root to mock group
RUN usermod -a -G mock root

# Create a non-root builder user with mock access
RUN useradd -m builder \
    && usermod -a -G mock builder \
    && mkdir -p /home/builder/rpmbuild/{BUILD,BUILDROOT,RPMS,SOURCES,SPECS,SRPMS} \
    && chown -R builder:builder /home/builder/rpmbuild

# Note: compiler caching for mock builds is configured in CI via mock's
# ccache plugin (the cache lives in the chroot's /var/cache/mock tree and
# is persisted with actions/cache); a host-side /etc/ccache.conf has no
# effect on builds inside the mock chroot.

# Set working directory
WORKDIR /workspace

# Default command
CMD ["/bin/bash"]


