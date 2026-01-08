#!/bin/bash
# Fetch and update spec files from upstream SRPMs
# Applies Fedora packaging adaptations as documented in FEDORA_CHANGES.md
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
CONTAINER_RUNTIME="${CONTAINER_RUNTIME:-podman}"

log() { echo -e "\033[0;32m[INFO]\033[0m $1"; }
warn() { echo -e "\033[0;33m[WARN]\033[0m $1"; }
die() { echo -e "\033[0;31m[ERROR]\033[0m $1" >&2; exit 1; }

for cmd in curl jq "$CONTAINER_RUNTIME"; do
    command -v "$cmd" &>/dev/null || die "Missing: $cmd"
done

get_latest_release() {
    # Note: flux-framework marks all releases as prereleases, so /releases/latest returns 404
    # Instead, fetch from /releases and get the first (most recent) release
    local response
    response=$(curl -sf "https://api.github.com/repos/flux-framework/$1/releases?per_page=1") || {
        echo ""
        return 1
    }
    echo "$response" | jq -r '.[0].tag_name // empty'
}

get_srpm_url() {
    local assets=$(curl -s "https://api.github.com/repos/flux-framework/$1/releases/tags/$2")
    echo "$assets" | jq -r '.assets[] | select(.name | endswith(".src.rpm")) | .browser_download_url' | head -1
}

# Apply all Fedora packaging adaptations to an upstream spec file
# Reference: FEDORA_CHANGES.md
apply_fedora_patches() {
    local spec=$1
    local pkg=$(basename "$spec" .spec)

    log "Applying Fedora adaptations to $spec"

    # ================================================================
    # REQUIRED CHANGES
    # ================================================================

    # 1. SPDX License (Fedora 40+)
    sed -i 's/^License:.*/License: LGPL-3.0-only/' "$spec"

    # 2. Full GitHub Source URL
    sed -i 's|^Source0:.*|Source0: %{url}/releases/download/v%{version}/%{name}-%{version}.tar.gz|' "$spec"

    # 3. URL tag capitalization
    sed -i 's|^Url:|URL:|' "$spec"

    # 4. Release tag with conditional dist
    sed -i 's/^Release:[[:space:]]*\([0-9]*\)%{dist}/Release: \1%{?dist}/' "$spec"

    # 5. Remove deprecated BuildRoot tag
    sed -i '/^BuildRoot:/d' "$spec"

    # 6. Remove deprecated Group tag
    sed -i '/^Group:/d' "$spec"

    # 7. Remove deprecated %defattr
    sed -i '/%defattr/d' "$spec"

    # 8. Remove deprecated %clean section
    sed -i '/^%clean$/,/^$/d' "$spec"

    # 9. ldconfig scriptlets - replace both %post and %postun
    # First, remove %post -p /sbin/ldconfig and %postun -p /sbin/ldconfig
    sed -i '/^%post[[:space:]]*-p[[:space:]]*\/sbin\/ldconfig/d' "$spec"
    sed -i '/^%postun[[:space:]]*-p[[:space:]]*\/sbin\/ldconfig/d' "$spec"
    # Add %ldconfig_scriptlets if not present (will be added after %install section)
    if ! grep -q '%ldconfig_scriptlets' "$spec"; then
        sed -i '/^%install$/,/^%/{/^%[a-z]/!b; /^%install/b; /^%ldconfig_scriptlets/b; i\
%ldconfig_scriptlets
}' "$spec"
    fi

    # 10. Remove debug package disabling (Fedora policy: debug packages enabled)
    sed -i '/^%define[[:space:]]*debug_package/d' "$spec"
    sed -i '/^%global[[:space:]]*debug_package/d' "$spec"
    sed -i '/^%define[[:space:]]*__spec_install_post/d' "$spec"
    sed -i '/^%global[[:space:]]*__spec_install_post/d' "$spec"

    # 11. Python package naming: python3-yaml -> python3-pyyaml
    sed -i 's/python3-yaml/python3-pyyaml/g' "$spec"

    # 12-14. Remove LLNL multi-Python build setup (version-specific python builds)
    # Remove hardcoded python sitearch definitions
    sed -i '/^%define[[:space:]]*python3_sitearch/d' "$spec"
    sed -i '/^%global[[:space:]]*python3_sitearch/d' "$spec"
    sed -i '/^%define[[:space:]]*python3[0-9]*_sitearch/d' "$spec"
    sed -i '/^%global[[:space:]]*python3[0-9]*_sitearch/d' "$spec"
    # Remove versioned python BuildRequires (python3.9, python3.11, python3.12)
    sed -i '/^BuildRequires:[[:space:]]*python3\.[0-9]/d' "$spec"
    # Remove versioned python packages/subpackages
    sed -i '/^%package[[:space:]]*python3\.[0-9]/,/^%package\|^%prep\|^$/d' "$spec"
    sed -i '/^%description[[:space:]]*python3\.[0-9]/,/^%package\|^%description\|^%prep\|^$/d' "$spec"
    sed -i '/^%files[[:space:]]*python3\.[0-9]/,/^%files\|^%changelog\|^$/d' "$spec"

    # 15. Remove LLNL conditionals
    sed -i '/0%{?bl6}/,/%endif/d' "$spec"
    # Also remove other LLNL-specific conditionals
    sed -i '/0%{?toss}/,/%endif/d' "$spec"

    # 16. Remove custom CFLAGS blocks (upstream handles these, %configure sets appropriate flags)
    # Remove CFLAGS/LDFLAGS export blocks
    sed -i '/^CFLAGS=/d' "$spec"
    sed -i '/^LDFLAGS=/d' "$spec"
    sed -i '/^export CFLAGS/d' "$spec"
    sed -i '/^export LDFLAGS/d' "$spec"
    sed -i '/^CFLAGS="${KOJI_CFLAGS}"/d' "$spec"
    # Remove architecture-specific CFLAGS blocks
    sed -i '/^%ifarch.*$/,/^%endif.*CFLAGS\|LDFLAGS/{/^%ifarch/d; /^%endif/d; /CFLAGS/d; /LDFLAGS/d}' "$spec"

    # 17. Remove LLNL-specific patches
    sed -i '/^Patch[0-9]*:/d' "$spec"
    # Remove %patch applications
    sed -i '/^%patch[0-9]/d' "$spec"

    # 18. Remove pip-based sphinx installation (use packaged sphinx)
    sed -i '/pip3[[:space:]]*install.*sphinx\|requirements\.txt/d' "$spec"
    sed -i '/pip[[:space:]]*install.*sphinx\|requirements\.txt/d' "$spec"
    sed -i '/export PATH=\$HOME\/.local\/bin:\$PATH/d' "$spec"

    # 19. Remove pip BuildRequires
    sed -i '/^BuildRequires:[[:space:]]*python3-pip/d' "$spec"
    sed -i '/^BuildRequires:[[:space:]]*python3\.[0-9]*-pip/d' "$spec"

    # 20. Modern build macros
    # %make_build instead of make %{?_smp_mflags}
    sed -i 's/make[[:space:]]*%{?_smp_mflags}/%make_build/g' "$spec"
    sed -i 's/make[[:space:]]*%{_smp_mflags}/%make_build/g' "$spec"
    # %make_install instead of make install DESTDIR=...
    sed -i 's/make[[:space:]]*install[[:space:]]*DESTDIR=[^[:space:]]*/\%make_install/g' "$spec"
    sed -i 's/make[[:space:]]*DESTDIR=[^[:space:]]*[[:space:]]*install/%make_install/g' "$spec"

    # 21. Path variables: use %{buildroot} instead of $RPM_BUILD_ROOT
    sed -i 's/\${RPM_BUILD_ROOT}/%{buildroot}/g' "$spec"
    sed -i 's/\$RPM_BUILD_ROOT/%{buildroot}/g' "$spec"

    # 22. Use %global instead of %define
    sed -i 's/^%define /%global /' "$spec"

    # 23. Fix double-slash typo in cron file path (if present)
    sed -i 's|flux//system|flux/system|g' "$spec"

    # 24. Improve error suppression in chrpath command
    sed -i 's/xargs[[:space:]]*-ti[[:space:]]*chrpath/xargs -I{} chrpath -d {} 2>\/dev\/null || true/g' "$spec"

    # 25. Improve systemctl check (add error suppression)
    sed -i 's|systemctl is-active --quiet|systemctl is-active --quiet 2>/dev/null|g' "$spec"

    # ================================================================
    # PACKAGE-SPECIFIC CHANGES
    # ================================================================

    if [ "$pkg" = "flux-security" ]; then
        # Update Summary to be more accurate
        sed -i 's/^Summary:.*Flux Resource Manager Framework.*/Summary: Flux Framework Security Components/' "$spec"
    fi

    if [ "$pkg" = "flux-core" ]; then
        # Ensure flux-security-devel is used (not flux-security)
        sed -i 's/^BuildRequires:[[:space:]]*flux-security[[:space:]]*>=/BuildRequires: flux-security-devel >=/' "$spec"
    fi

    if [ "$pkg" = "flux-sched" ]; then
        # Remove gcc-toolset (Fedora has modern GCC)
        sed -i '/^BuildRequires:[[:space:]]*gcc-toolset/d' "$spec"
        sed -i '/source.*gcc-toolset/d' "$spec"
        # Use flux-core-devel instead of flux-core for BuildRequires
        sed -i 's/^BuildRequires:[[:space:]]*flux-core[[:space:]]*>=/BuildRequires: flux-core-devel >=/' "$spec"
        # Use cmake macros
        sed -i 's/%make_build/%cmake_build/g' "$spec"
        sed -i 's/%make_install/%cmake_install/g' "$spec"
    fi

    # ================================================================
    # CLEANUP
    # ================================================================

    # Remove any trailing whitespace
    sed -i 's/[[:space:]]*$//' "$spec"

    # Remove multiple consecutive blank lines (keep max 2)
    sed -i '/^$/N;/^\n$/d' "$spec"

    log "Fedora adaptations applied to $spec"
}

update_package() {
    local pkg=$1 ver=${2:-}

    [ -z "$ver" ] && ver=$(get_latest_release "$pkg")
    [ -z "$ver" ] || [ "$ver" = "null" ] && die "Could not get version for $pkg"

    log "Updating $pkg to $ver"

    local srpm_url=$(get_srpm_url "$pkg" "$ver")
    if [ -z "$srpm_url" ] || [ "$srpm_url" = "null" ]; then
        warn "No SRPM available for $pkg $ver"
        warn "flux-sched spec is manually maintained in this repo"
        warn "Please update flux-sched/flux-sched.spec manually"
        return 1
    fi

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
    flux-sched)    update_package flux-sched "$VERSION" ;;
    all)
        update_package flux-security "$VERSION"
        update_package flux-core "$VERSION"
        update_package flux-sched "$VERSION" || true  # flux-sched may not have SRPM
        ;;
    -h|--help)
        echo "Usage: $0 [-v VERSION] [flux-core|flux-security|flux-sched|all]"
        echo ""
        echo "Options:"
        echo "  -v, --version VERSION   Update to specific version (applies to next package)"
        echo "  -h, --help              Show this help"
        echo ""
        echo "Packages:"
        echo "  flux-security           Update flux-security spec"
        echo "  flux-core               Update flux-core spec"
        echo "  flux-sched              Update flux-sched spec (note: may not have upstream SRPM)"
        echo "  all                     Update all packages (default)"
        echo ""
        echo "This script downloads upstream SRPMs and applies Fedora packaging"
        echo "adaptations as documented in FEDORA_CHANGES.md"
        echo ""
        echo "Note: flux-sched upstream releases may not include SRPMs."
        echo "The flux-sched spec file in this repo may need manual updates."
        exit 0
        ;;
    *) die "Unknown: $1" ;;
esac
