#!/bin/bash
# Fetch and update spec files from upstream SRPMs
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
CONTAINER_RUNTIME="${CONTAINER_RUNTIME:-podman}"

log() { echo -e "\033[0;32m[INFO]\033[0m $1"; }
die() { echo -e "\033[0;31m[ERROR]\033[0m $1" >&2; exit 1; }

for cmd in curl jq "$CONTAINER_RUNTIME"; do
    command -v "$cmd" &>/dev/null || die "Missing: $cmd"
done

get_latest_release() {
    curl -s "https://api.github.com/repos/flux-framework/$1/releases/latest" | jq -r '.tag_name'
}

get_srpm_url() {
    local assets=$(curl -s "https://api.github.com/repos/flux-framework/$1/releases/tags/$2")
    echo "$assets" | jq -r '.assets[] | select(.name | endswith(".src.rpm")) | .browser_download_url' | head -1
}

apply_fedora_patches() {
    local spec=$1
    # SPDX license
    sed -i 's/^License:.*/License: LGPL-3.0-only/' "$spec"
    # GitHub source URL
    sed -i 's|^Source0:.*|Source0: %{url}/releases/download/v%{version}/%{name}-%{version}.tar.gz|' "$spec"
    # URL tag case
    sed -i 's|^Url:|URL:|' "$spec"
    # Remove deprecated tags
    sed -i '/^BuildRoot:/d' "$spec"
    sed -i '/^Group:/d' "$spec"
    # Remove %clean section
    sed -i '/^%clean$/,/^$/d' "$spec"
    # Use ldconfig_scriptlets
    sed -i 's/%post -p \/sbin\/ldconfig/%ldconfig_scriptlets/' "$spec"
    sed -i '/^%postun -p \/sbin\/ldconfig/d' "$spec"
    # Use %global instead of %define
    sed -i 's/^%define /%global /' "$spec"
    # Remove LLNL-specific patches
    sed -i '/^Patch0:/d' "$spec"
    # Remove bl6 conditionals
    sed -i '/0%{?bl6}/,/%endif/d' "$spec"
}

update_package() {
    local pkg=$1 ver=${2:-}
    
    [ -z "$ver" ] && ver=$(get_latest_release "$pkg")
    [ -z "$ver" ] || [ "$ver" = "null" ] && die "Could not get version for $pkg"
    
    log "Updating $pkg to $ver"
    
    local srpm_url=$(get_srpm_url "$pkg" "$ver")
    [ -z "$srpm_url" ] || [ "$srpm_url" = "null" ] && die "No SRPM for $pkg $ver"
    
    local srpm_file="${REPO_DIR}/${pkg}.src.rpm"
    curl -sL -o "$srpm_file" "$srpm_url"
    
    log "Extracting spec from SRPM"
    $CONTAINER_RUNTIME run --rm -v "${REPO_DIR}:/work:Z" fedora:latest \
        bash -c "dnf install -y cpio >/dev/null 2>&1 && cd /work/${pkg} && rpm2cpio /work/${pkg}.src.rpm | cpio -idmv '*.spec' 2>&1"
    
    rm -f "$srpm_file"
    
    log "Applying Fedora adaptations"
    apply_fedora_patches "${REPO_DIR}/${pkg}/${pkg}.spec"
    
    log "$pkg updated to $ver"
}

case "${1:-}" in
    -v|--version) shift; VERSION="$1"; shift ;;
esac

case "${1:-all}" in
    flux-security) update_package flux-security "$VERSION" ;;
    flux-core)     update_package flux-core "$VERSION" ;;
    all)
        update_package flux-security "$VERSION"
        update_package flux-core "$VERSION"
        ;;
    -h|--help)
        echo "Usage: $0 [-v VERSION] [flux-core|flux-security|all]"
        exit 0
        ;;
    *) die "Unknown: $1" ;;
esac
