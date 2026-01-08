#!/bin/bash
# Build SRPMs for flux-security, flux-core, and flux-sched
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

get_version() {
    grep '^Version:' "$REPO_DIR/$1/$1.spec" | awk '{print $2}'
}

FLUX_SECURITY_VERSION=$(get_version flux-security)
FLUX_CORE_VERSION=$(get_version flux-core)
FLUX_SCHED_VERSION=$(get_version flux-sched)

log() { echo -e "\033[0;32m[INFO]\033[0m $1"; }
die() { echo -e "\033[0;31m[ERROR]\033[0m $1" >&2; exit 1; }

for cmd in rpmbuild rpmdev-setuptree wget; do
    command -v "$cmd" &>/dev/null || die "Missing: $cmd"
done

rpmdev-setuptree

download_source() {
    local pkg=$1 ver=$2
    local dest=~/rpmbuild/SOURCES/${pkg}-${ver}.tar.gz
    [ -f "$dest" ] && return 0
    log "Downloading ${pkg}-${ver}.tar.gz"
    wget -q -O "$dest" "https://github.com/flux-framework/${pkg}/releases/download/v${ver}/${pkg}-${ver}.tar.gz"
}

build_srpm() {
    local pkg=$1
    log "Building SRPM for ${pkg}"
    cp "$REPO_DIR/${pkg}/${pkg}.spec" ~/rpmbuild/SPECS/
    # Copy any patches if they exist
    cp "$REPO_DIR/${pkg}"/*.patch ~/rpmbuild/SOURCES/ 2>/dev/null || true
    rpmbuild -bs ~/rpmbuild/SPECS/${pkg}.spec
}

case "${1:-all}" in
    flux-security)
        download_source flux-security "$FLUX_SECURITY_VERSION"
        build_srpm flux-security
        ;;
    flux-core)
        download_source flux-core "$FLUX_CORE_VERSION"
        build_srpm flux-core
        ;;
    flux-sched)
        download_source flux-sched "$FLUX_SCHED_VERSION"
        build_srpm flux-sched
        ;;
    all)
        download_source flux-security "$FLUX_SECURITY_VERSION"
        build_srpm flux-security
        download_source flux-core "$FLUX_CORE_VERSION"
        build_srpm flux-core
        download_source flux-sched "$FLUX_SCHED_VERSION"
        build_srpm flux-sched
        ;;
    -h|--help)
        echo "Usage: $0 [flux-security|flux-core|flux-sched|all]"
        exit 0
        ;;
    *)
        die "Unknown target: $1"
        ;;
esac

log "SRPMs built in ~/rpmbuild/SRPMS/"
ls ~/rpmbuild/SRPMS/*.src.rpm 2>/dev/null
