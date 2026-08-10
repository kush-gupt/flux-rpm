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

# Returns non-zero on SHA256 mismatch; hard-fails only on a missing or
# incomplete sources file, which no retry can fix.
verify_checksum() {
    local pkg=$1 ver=$2
    local tarball=~/rpmbuild/SOURCES/${pkg}-${ver}.tar.gz
    local sources_file="$REPO_DIR/${pkg}/sources"
    [ -f "$sources_file" ] || die "Missing sources file: $sources_file"
    local expected actual
    expected=$(grep -F "(${pkg}-${ver}.tar.gz)" "$sources_file" | awk '{print $4}')
    [ -n "$expected" ] || die "No SHA256 entry for ${pkg}-${ver}.tar.gz in $sources_file"
    actual=$(sha256sum "$tarball" | awk '{print $1}')
    if [ "$actual" != "$expected" ]; then
        echo "SHA256 mismatch for ${pkg}-${ver}.tar.gz (expected $expected, got $actual)" >&2
        return 1
    fi
}

download_source() {
    local pkg=$1 ver=$2
    local dest=~/rpmbuild/SOURCES/${pkg}-${ver}.tar.gz
    local url="https://github.com/flux-framework/${pkg}/releases/download/v${ver}/${pkg}-${ver}.tar.gz"

    # A pre-existing tarball that fails verification (e.g. a partial
    # download restored from a CI cache) is discarded and fetched fresh
    # instead of failing every run until the cache entry expires.
    if [ -f "$dest" ] && ! verify_checksum "$pkg" "$ver"; then
        log "Existing ${pkg}-${ver}.tar.gz failed verification; re-downloading"
        rm -f "$dest"
    fi

    if [ ! -f "$dest" ]; then
        log "Downloading ${pkg}-${ver}.tar.gz"
        # Remove any partial file on failure so it can't poison a later
        # run (or the CI tarball cache).
        wget -q -O "$dest" "$url" || { rm -f "$dest"; die "Failed to download $url"; }
    fi

    verify_checksum "$pkg" "$ver" || die "SHA256 verification failed for freshly downloaded ${pkg}-${ver}.tar.gz"
    log "Verified SHA256 for ${pkg}-${ver}.tar.gz"
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
