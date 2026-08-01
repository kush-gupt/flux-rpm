#!/bin/bash
# Build SRPMs for flux-security, flux-core, flux-sched, and flux-accounting
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

get_version() {
    grep '^Version:' "$REPO_DIR/$1/$1.spec" | awk '{print $2}'
}

FLUX_SECURITY_VERSION=$(get_version flux-security)
FLUX_CORE_VERSION=$(get_version flux-core)
FLUX_SCHED_VERSION=$(get_version flux-sched)
FLUX_ACCOUNTING_VERSION=$(get_version flux-accounting)

log() { echo -e "\033[0;32m[INFO]\033[0m $1"; }
die() { echo -e "\033[0;31m[ERROR]\033[0m $1" >&2; exit 1; }

for cmd in rpmbuild rpmdev-setuptree wget sha256sum; do
    command -v "$cmd" &>/dev/null || die "Missing: $cmd"
done

rpmdev-setuptree

verify_checksum() {
    local pkg=$1 ver=$2
    local tarball=~/rpmbuild/SOURCES/${pkg}-${ver}.tar.gz
    local sources_file="$REPO_DIR/${pkg}/sources"
    [ -f "$sources_file" ] || die "Missing sources file: $sources_file"
    local expected
    expected=$(grep -F "(${pkg}-${ver}.tar.gz)" "$sources_file" | awk '{print $4}')
    [ -n "$expected" ] || die "No SHA256 entry for ${pkg}-${ver}.tar.gz in $sources_file"
    local actual
    actual=$(sha256sum "$tarball" | awk '{print $1}')
    [ "$actual" = "$expected" ] || die "SHA256 mismatch for ${pkg}-${ver}.tar.gz (expected $expected, got $actual)"
    log "Verified SHA256 for ${pkg}-${ver}.tar.gz"
}

download_source() {
    local pkg=$1 ver=$2
    local dest=~/rpmbuild/SOURCES/${pkg}-${ver}.tar.gz
    if [ ! -f "$dest" ]; then
        log "Downloading ${pkg}-${ver}.tar.gz"
        wget -q -O "$dest" "https://github.com/flux-framework/${pkg}/releases/download/v${ver}/${pkg}-${ver}.tar.gz"
    fi
    verify_checksum "$pkg" "$ver"
}

build_srpm() {
    local pkg=$1
    log "Building SRPM for ${pkg}"
    cp "$REPO_DIR/${pkg}/${pkg}.spec" ~/rpmbuild/SPECS/
    # Copy any patches if they exist
    cp "$REPO_DIR/${pkg}"/*.patch ~/rpmbuild/SOURCES/ 2>/dev/null || true
    rpmbuild -bs ~/rpmbuild/SPECS/"${pkg}.spec"
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
    flux-accounting)
        download_source flux-accounting "$FLUX_ACCOUNTING_VERSION"
        build_srpm flux-accounting
        ;;
    all)
        download_source flux-security "$FLUX_SECURITY_VERSION"
        build_srpm flux-security
        download_source flux-core "$FLUX_CORE_VERSION"
        build_srpm flux-core
        download_source flux-sched "$FLUX_SCHED_VERSION"
        build_srpm flux-sched
        download_source flux-accounting "$FLUX_ACCOUNTING_VERSION"
        build_srpm flux-accounting
        ;;
    -h|--help)
        echo "Usage: $0 [flux-security|flux-core|flux-sched|flux-accounting|all]"
        exit 0
        ;;
    *)
        die "Unknown target: $1"
        ;;
esac

log "SRPMs built in ~/rpmbuild/SRPMS/"
ls ~/rpmbuild/SRPMS/*.src.rpm 2>/dev/null
