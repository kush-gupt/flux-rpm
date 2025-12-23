# Fedora Spec File Adaptations

This document describes the changes made to upstream LLNL spec files for Fedora packaging compliance.

> **Verified**: All changes below have been verified against Fedora Packaging Guidelines as of December 2024, including requirements for Fedora 40-43 and Rawhide.

## Summary of Changes

| Change | Upstream | Fedora | Reason |
|--------|----------|--------|--------|
| License tag | `LGPLv3` or `LGPL-3.0` | `LGPL-3.0-only` | SPDX identifier required (Fedora 40+) |
| Source0 URL | `%{name}-%{version}.tar.gz` | Full GitHub URL | Fedora requires fetchable source URLs |
| URL tag | `Url:` | `URL:` | Consistent capitalization |
| BuildRoot | Present | Removed | Deprecated since RHEL 6 |
| Group tag | Present | Removed | Deprecated in Fedora |
| %clean section | Present | Removed | Deprecated, handled by rpmbuild |
| %post/%postun ldconfig | `-p /sbin/ldconfig` | `%ldconfig_scriptlets` | Modern Fedora macro |
| %define | `%define` | `%global` | Fedora prefers %global |
| Debug packages | Disabled | Enabled (default) | Fedora policy |
| Python paths | Hardcoded versions | `%{python3_sitearch}` | Portable across Fedora versions |
| LLNL conditionals | `%if 0%{?bl6}` blocks | Removed | Not applicable to Fedora |
| Custom CFLAGS | Architecture-specific | Removed | Fedora handles via %configure |
| Patches | LLNL-specific patches | Removed | Not needed for Fedora |

## Detailed Changes

### 1. License Tag (Required)

```diff
- License: LGPLv3
+ License: LGPL-3.0-only
```

Fedora 40+ requires SPDX license identifiers. See: https://docs.fedoraproject.org/en-US/legal/allowed-licenses/

### 2. Source URL (Required)

```diff
- Source0: %{name}-%{version}.tar.gz
+ Source0: %{url}/releases/download/v%{version}/%{name}-%{version}.tar.gz
```

Fedora requires complete, fetchable URLs for source files. Using `%{url}` macro keeps it DRY.

### 3. Deprecated Tags (Required)

```diff
- BuildRoot: %{_tmppath}/%{name}-%{version}-root-%(%{__id_u} -n)
- Group: System Environment/Base
```

These tags are ignored by modern rpmbuild and should be removed.

### 4. %clean Section (Required)

```diff
- %clean
- rm -rf $RPM_BUILD_ROOT
```

The `%clean` section is deprecated. rpmbuild handles cleanup automatically.

### 5. ldconfig Scriptlets (Required)

```diff
- %post -p /sbin/ldconfig
- %postun -p /sbin/ldconfig
+ %ldconfig_scriptlets
```

The `%ldconfig_scriptlets` macro is the modern Fedora way to handle shared library cache updates.

### 6. %define vs %global (Recommended)

```diff
- %define debug_package %{nil}
+ %global debug_package %{nil}
```

Fedora packaging guidelines recommend `%global` over `%define` for consistency.

### 7. Python Packaging (Required for flux-core)

Upstream uses hardcoded Python version paths:
```spec
%define python3_sitearch /usr/lib64/python3.9/site-packages
%define python311_sitearch /usr/lib64/python3.11/site-packages
```

Fedora uses portable macros:
```spec
%{python3_sitearch}
```

### 8. LLNL-Specific Conditionals (Removed)

Upstream contains LLNL build farm conditionals:
```spec
%if 0%{?bl6}
BuildRequires: ibm_smpi-devel
%endif
```

These are removed as they're not applicable to Fedora.

### 9. Custom CFLAGS (Removed)

Upstream sets custom CFLAGS for different architectures to work around launchmon issues:
```spec
%ifarch x86_64
CFLAGS="${CFLAGS:--O2 -g -pipe -Wall ...}"
%endif
```

Fedora's `%configure` macro handles compiler flags appropriately.

### 10. Debug Packages (Policy Decision)

Upstream disables debug packages:
```spec
%define debug_package %{nil}
```

For Fedora, debug packages should generally be enabled (default behavior). However, if there are legitimate reasons (like symbol resolution issues with debugging tools), this can be kept with documentation.

### 11. Patches (Removed)

Upstream includes LLNL-specific patches:
```spec
Patch0: systemd-no-linger.patch
```

These are removed unless they fix issues relevant to Fedora.

## Changes Applied by update-specs.sh

The `scripts/update-specs.sh` script automatically applies these transformations when updating from upstream:

```bash
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
```

## Manual Review Required

After automatic updates, these items need manual review:

1. **%files section** - Verify all installed files are listed
2. **Dependencies** - Check BuildRequires/Requires against Fedora package names
3. **Subpackages** - Verify devel and python subpackages are correct
4. **Changelog** - Add Fedora-specific changelog entry
5. **Python versions** - Update any remaining hardcoded Python version references

## Current Spec File Compliance Status

Both `flux-core.spec` and `flux-security.spec` in this repository already implement:

| Requirement | Status | Notes |
|-------------|--------|-------|
| SPDX License (`LGPL-3.0-only`) | ✅ | |
| Full Source0 URL | ✅ | Uses `%{url}` macro |
| `URL:` capitalization | ✅ | |
| No `BuildRoot` tag | ✅ | |
| No `Group` tag | ✅ | |
| No `%clean` section | ✅ | |
| `%ldconfig_scriptlets` | ✅ | |
| `%global` macros | ✅ | |
| `%{?dist}` tag | ✅ | Mandatory in Fedora |
| `%{python3_sitearch}` | ✅ | For Python files |
| `%config(noreplace)` | ✅ | For config files |
| Standard macros | ✅ | `%{_bindir}`, `%{_libdir}`, etc. |
| `-devel` subpackage | ✅ | |
| `%attr` for setuid | ✅ | `flux-imp` is 4755 |
| `%autosetup` | ✅ | Modern setup macro |

## Optional Modern Features (Not Required)

### %autochangelog / %autorelease (rpmautospec)

Fedora now offers `rpmautospec` for automated changelog and release management:

```spec
Release: %autorelease

%changelog
%autochangelog
```

**Status**: Not currently used. This is **optional** but recommended for packages maintained in Fedora dist-git.

**Reason**: Our spec files use traditional changelogs which are valid. The automated approach works best when package history is in dist-git.

### %python_provide Macro

```spec
%{?python_provide:%python_provide python3-flux}
```

**Status**: Not used. This macro is being **phased out** in Fedora 42+.

**Reason**: Modern Fedora automatically handles Python package provides. The `python3-flux` naming is sufficient.

## Additional Fedora Guidelines Verified

### Systemd Integration
- ✅ Uses `%{_unitdir}` for systemd unit files
- ✅ Uses `systemd-rpm-macros` for `%{_tmpfilesdir}`
- ✅ No SysV initscripts (forbidden in Fedora)

### File Ownership
- ✅ Package owns all directories it creates (`%dir` directives)
- ✅ Config files use `%config(noreplace)`

### Setuid Binary
- ✅ `flux-imp` uses `%attr(04755, root, root)` per security guidelines

### Build Flags
- ✅ Uses `%configure` which sets appropriate CFLAGS/LDFLAGS
- ✅ Uses `--disable-static` (static libraries require `-static` subpackage)

### Source Verification
- Using `sources` files with SHA256 checksums aligns with Fedora lookaside cache practices

## EPEL Considerations

When targeting EPEL (Extra Packages for Enterprise Linux), additional changes may be needed:

| EPEL Version | Consideration |
|--------------|---------------|
| EPEL 8 | May need `%if 0%{?rhel} == 8` conditionals for older dependencies |
| EPEL 9 | Generally compatible with current Fedora specs |
| EPEL 10 | Expected to align with Fedora 40+ standards |

### Potential EPEL Issues
- **Python version**: EPEL 8 uses Python 3.6/3.8/3.9, EPEL 9 uses Python 3.9/3.11
- **Dependency availability**: Some BuildRequires may not exist in EPEL
- **Lua version**: Verify lua and lua-posix versions are available
- **systemd macros**: Older EPEL may need explicit `systemd` BuildRequires

### EPEL-Safe Conditionals (if needed)
```spec
%if 0%{?rhel} && 0%{?rhel} < 9
# RHEL 8 specific adjustments
%endif
```

## Potential Future Improvements

1. **Add Fedora-specific changelog entries** when submitting to Fedora
2. **Consider %autochangelog** if maintaining in Fedora dist-git
3. **Add %check section** with actual test execution (currently commented)
4. **Consider splitting large docs** into `-doc` subpackage if size warrants
5. **Add EPEL conditionals** when submitting to EPEL

## References

- [Fedora Packaging Guidelines](https://docs.fedoraproject.org/en-US/packaging-guidelines/)
- [RPM Macros](https://docs.fedoraproject.org/en-US/packaging-guidelines/RPMMacros/)
- [SPDX License List](https://spdx.org/licenses/)
- [Fedora Python Packaging](https://docs.fedoraproject.org/en-US/packaging-guidelines/Python/)
- [Fedora Systemd Packaging](https://docs.fedoraproject.org/en-US/packaging-guidelines/Systemd/)
- [rpmautospec Documentation](https://docs.fedoraproject.org/en-US/packaging-guidelines/Autospec/)

