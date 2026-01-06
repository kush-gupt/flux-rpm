# Fedora Spec File Adaptations

This document describes the changes made to upstream LLNL spec files for Fedora packaging compliance.

## Summary of Changes

| Change | Upstream | Fedora | Reason |
|--------|----------|--------|--------|
| License tag | `LGPL-3.0` or `LGPLv3` | `LGPL-3.0-only` | SPDX identifier required (Fedora 40+) |
| Source0 URL | `%{name}-%{version}.tar.gz` | Full GitHub URL with `%{url}` | Fedora requires fetchable source URLs |
| URL tag | `Url:` | `URL:` | Consistent capitalization |
| Release tag | `1%{dist}` | `1%{?dist}` | Conditional dist tag (standard practice) |
| BuildRoot | Present | Removed | Deprecated since RHEL 6 |
| Group tag | Present | Removed | Deprecated in Fedora |
| %defattr | `%defattr(-,root,root)` | Removed | Deprecated, rpmbuild sets defaults |
| %clean section | Present | Removed | Deprecated, handled by rpmbuild |
| %post/%postun ldconfig | `-p /sbin/ldconfig` | `%ldconfig_scriptlets` | Modern Fedora macro |
| %define | `%define` | Removed (or `%global`) | Fedora prefers %global; debug package lines removed |
| Debug packages | Disabled via `%define` | Enabled (default) | Fedora policy |
| Python package name | `python3-yaml` | `python3-pyyaml` | Fedora package naming |
| Python paths | Hardcoded versions | `%{python3_sitearch}` | Portable across Fedora versions |
| Python subpackages | `python3.11` (version-specific) | `python3-flux` (generic) | Fedora Python packaging guidelines |
| Multi-Python builds | Builds for 3.9, 3.11, 3.12 | Single system Python | Fedora uses single Python version |
| LLNL conditionals | `%if 0%{?bl6}` blocks | Removed | Not applicable to Fedora |
| Custom CFLAGS | Architecture-specific overrides | Removed | Fedora handles via %configure |
| Patches | `systemd-no-linger.patch` | Removed | LLNL-specific, not needed for Fedora |
| Sphinx docs | `pip3 install --user` | Packaged `python3-sphinx` | Mock builds have no network access |
| Build dependencies | `flux-security >= 0.14` | `flux-security-devel >= 0.14` | Proper -devel package naming |
| Build macros | `make %{?_smp_mflags}` | `%make_build` | Modern Fedora macro |
| Install macros | `make install DESTDIR=...` | `%make_install` | Modern Fedora macro |
| Path variables | `$RPM_BUILD_ROOT`, `${RPM_BUILD_ROOT}` | `%{buildroot}` | Modern Fedora macro |
| -devel subpackage | Not present (flux-core) / not present (flux-security) | Separate `-devel` subpackage | Fedora packaging guidelines |
| %license/%doc | Not present | `%license COPYING` `%doc README.md NEWS.md` | Fedora file marking |
| Changelog format | `0.81.0-1` (no hyphen before version) | `- 0.81.0-1` (hyphen before version) | Fedora changelog format |
| Summary (flux-security) | "Flux Resource Manager Framework" | "Flux Framework Security Components" | More accurate description |

## Detailed Changes

### 1. License Tag (Required)

```diff
- License: LGPL-3.0
+ License: LGPL-3.0-only
```
or
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

### 3. URL Tag Capitalization (Required)

```diff
- Url: https://github.com/flux-framework/flux-core
+ URL:     https://github.com/flux-framework/flux-core
```

### 4. Release Tag (Required)

```diff
- Release: 1%{dist}
+ Release: 1%{?dist}
```

The `?` makes the dist tag conditional, which is standard practice in Fedora.

### 5. Deprecated Tags (Required)

```diff
- BuildRoot: %{_tmppath}/%{name}-%{version}-root-%(%{__id_u} -n)
- Group: System Environment/Base
```

These tags are ignored by modern rpmbuild and should be removed.

### 6. %defattr (Removed)

```diff
  %files
- %defattr(-,root,root)
```

`%defattr` is deprecated. Modern rpmbuild sets appropriate defaults automatically.

### 7. %clean Section (Required)

```diff
- %clean
- rm -rf $RPM_BUILD_ROOT
```

The `%clean` section is deprecated. rpmbuild handles cleanup automatically.

### 8. ldconfig Scriptlets (Required)

```diff
- %post -p /sbin/ldconfig
- %postun -p /sbin/ldconfig
+ %ldconfig_scriptlets
```

The `%ldconfig_scriptlets` macro is the modern Fedora way to handle shared library cache updates.

### 9. Debug Package Handling (Required)

Upstream disables debug packages with custom macros:
```spec
%define debug_package %{nil}
%define __spec_install_post /usr/lib/rpm/brp-compress || :
```

For Fedora, these lines are **removed entirely**. Debug packages should be enabled (the default behavior). The upstream comment explains they disable it due to "problems with symbol resolution in tools like launchmon" - this is LLNL-specific and not applicable to Fedora.

### 10. Python Package Naming (Required)

```diff
- Requires: python3-yaml
- BuildRequires: python3-yaml
+ Requires: python3-pyyaml
+ BuildRequires: python3-pyyaml
```

In Fedora, the PyYAML package is named `python3-pyyaml`, not `python3-yaml`.

### 11. Python Packaging (Required for flux-core)

Upstream uses hardcoded Python version paths and builds multiple Python versions:
```spec
%define python3_sitearch /usr/lib64/python3.9/site-packages
%define python311_sitearch /usr/lib64/python3.11/site-packages
%define python312_sitearch /usr/lib64/python3.12/site-packages

BuildRequires: python3.11
BuildRequires: python3.11-pip
BuildRequires: python3.11-devel
# ... etc

%package python3.11
Summary: Python 3.11 bindings for flux-core
Group: System Environment/Base
```

Fedora uses portable macros and a single `python3-flux` subpackage:
```spec
%package -n python3-flux
Summary: Python 3 bindings for flux-core
Requires: %{name}%{?_isa} = %{version}-%{release}

%files -n python3-flux
%{python3_sitearch}/*
%{_libdir}/flux/python*
```

The multi-Python build loop in `%install` is also removed.

### 12. -devel Subpackage (Required)

Upstream flux-core puts devel files in the main package. Fedora separates them:

```spec
%package devel
Summary: Development files for %{name}
Requires: %{name}%{?_isa} = %{version}-%{release}

%description devel
Development files for %{name}.

%files devel
%{_libdir}/pkgconfig/%{name}.pc
%{_libdir}/pkgconfig/flux-pmi.pc
%{_libdir}/pkgconfig/flux-optparse.pc
%{_libdir}/pkgconfig/flux-idset.pc
%{_libdir}/pkgconfig/flux-schedutil.pc
%{_libdir}/pkgconfig/flux-hostlist.pc
%{_libdir}/pkgconfig/flux-taskmap.pc
%{_libdir}/*.so
%{_includedir}/flux
%{_mandir}/man3/*.3*
```

Similarly, flux-security gets a `-devel` subpackage for its development files.

### 13. LLNL-Specific Conditionals (Removed)

Upstream contains LLNL build farm conditionals:
```spec
%if 0%{?bl6}
BuildRequires: ibm_smpi-devel
BuildRequires: libevent
export LDFLAGS="-L/opt/ibm/spectrum_mpi/lib"
export CPPFLAGS="-I/opt/ibm/spectrum_mpi/include"
%endif
```

These are removed as they're not applicable to Fedora.

### 14. Custom CFLAGS (Removed)

Upstream sets extensive custom CFLAGS for different architectures:
```spec
%ifarch x86_64
CFLAGS="${CFLAGS:--O2 -g -pipe -Wall -Werror=format-security -Wp,-D_FORTIFY_SOURCE=2 ...}"
LDFLAGS="${LDFLAGS:--Wl,-z,relro  -Wl,-z,now}";
%endif
%ifarch aarch64
...
%endif
%ifarch ppc64le
...
%endif
export CFLAGS
export LDFLAGS
```

And also:
```spec
CFLAGS="${KOJI_CFLAGS}"
export CFLAGS
export PATH=$HOME/.local/bin:$PATH
```

All of this is removed. Fedora's `%configure` macro handles compiler flags appropriately.

### 15. Patches (Removed)

Upstream includes LLNL-specific patches:
```spec
Patch0: systemd-no-linger.patch
```

This patch comments out `ExecStartPre=/usr/bin/loginctl enable-linger flux` in the systemd service file. This is LLNL-specific and removed for Fedora.

### 16. Sphinx Documentation Build (Required)

Upstream installs sphinx via pip during the build:
```spec
# Need to install sphinx deps with pip3 so manpages are built correctly
pip3 install --user -r doc/requirements.txt

%build
export PATH=$HOME/.local/bin:$PATH
```

Fedora uses packaged sphinx (network access is not available in mock builds):
```spec
BuildRequires: python3-sphinx
BuildRequires: python3-sphinx_rtd_theme
BuildRequires: python3-docutils
```

### 17. Build Dependency Naming (Required)

```diff
- BuildRequires: flux-security >= 0.14
+ BuildRequires: flux-security-devel >= 0.14
```

Fedora naming convention uses `-devel` suffix for development packages.

### 18. Modern Build Macros (Recommended)

```diff
- make %{?_smp_mflags}
+ %make_build

- rm -rf $RPM_BUILD_ROOT
- mkdir -p $RPM_BUILD_ROOT
- make install DESTDIR=$RPM_BUILD_ROOT
+ %make_install

- find ${RPM_BUILD_ROOT} -name *.la | while read f; do rm -f $f; done
+ find %{buildroot} -name '*.la' -delete
```

### 19. Path Variables (Recommended)

```diff
- ${RPM_BUILD_ROOT}
- $RPM_BUILD_ROOT
+ %{buildroot}
```

### 20. License and Documentation Files (Required)

```diff
  %files
+ %license COPYING
+ %doc README.md NEWS.md
```

### 21. Changelog Format (Recommended)

```diff
- * Wed Dec  3 2025 Mark A. Grondona <mgrondona@llnl.gov> 0.81.0-1
+ * Wed Dec  3 2025 Mark A. Grondona <mgrondona@llnl.gov> - 0.81.0-1
```

Fedora changelog format includes a hyphen before the version-release.

### 22. Additional BuildRequires (Required for Fedora)

Fedora spec files need explicit build tool requirements:
```spec
BuildRequires: autoconf
BuildRequires: automake
BuildRequires: libtool
BuildRequires: make
BuildRequires: gcc
BuildRequires: gcc-c++  # flux-core only
```

### 23. Removed pip BuildRequires

```diff
- BuildRequires: python3-pip
- BuildRequires: python3.11-pip
```

pip is not used in Fedora builds.

### 24. Cron File Path Typo (Fixed)

Upstream has a double-slash typo:
```diff
- %{_sysconfdir}/flux//system/cron.d/kvs-backup.cron
+ %{_sysconfdir}/flux/system/cron.d/kvs-backup.cron
```

### 25. Improved Error Suppression in chrpath

```diff
- xargs -ti chrpath -d {}
+ xargs -I{} chrpath -d {} 2>/dev/null || true
```

The `-t` flag for xargs is BSD-specific and causes issues. The `2>/dev/null || true` handles cases where chrpath finds no rpath.

### 26. Improved systemctl Check

```diff
- if /usr/bin/systemctl is-active --quiet flux.service; then
+ if /usr/bin/systemctl is-active --quiet flux.service 2>/dev/null; then
```

Suppresses error output if systemctl is not available.

## Current Spec File Compliance Status

Both `flux-core.spec` and `flux-security.spec` in this repository implement:

| Requirement | Status | Notes |
|-------------|--------|-------|
| SPDX License (`LGPL-3.0-only`) | ✅ | |
| Full Source0 URL | ✅ | Uses `%{url}` macro |
| `URL:` capitalization | ✅ | |
| `%{?dist}` conditional | ✅ | |
| No `BuildRoot` tag | ✅ | |
| No `Group` tag | ✅ | |
| No `%defattr` | ✅ | |
| No `%clean` section | ✅ | |
| `%ldconfig_scriptlets` | ✅ | |
| Debug packages enabled | ✅ | No `%define debug_package %{nil}` |
| `%{python3_sitearch}` | ✅ | For Python files |
| `python3-pyyaml` naming | ✅ | Correct Fedora package name |
| `-devel` subpackage | ✅ | Proper separation |
| `python3-flux` subpackage | ✅ | Generic Python bindings package |
| `%config(noreplace)` | ✅ | For config files |
| Standard macros | ✅ | `%{_bindir}`, `%{_libdir}`, etc. |
| `%attr` for setuid | ✅ | `flux-imp` is 4755 |
| `%autosetup` | ✅ | Modern setup macro |
| `%make_build` / `%make_install` | ✅ | Modern build macros |
| `%{buildroot}` | ✅ | Modern path variable |
| Packaged sphinx | ✅ | No pip during build |
| `%license` / `%doc` | ✅ | Proper file marking |
| `flux-security-devel` dependency | ✅ | Correct -devel naming |
| Explicit build tools | ✅ | autoconf, automake, libtool, make, gcc |
| Changelog format with hyphen | ✅ | `- 0.81.0-1` format |
| No LLNL patches | ✅ | `systemd-no-linger.patch` removed |
| No custom CFLAGS | ✅ | Uses %configure defaults |
| No LLNL conditionals | ✅ | No `%if 0%{?bl6}` blocks |

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
3. **Add %check section** with actual test execution (currently not present)
4. **Consider splitting large docs** into `-doc` subpackage if size warrants
5. **Add EPEL conditionals** when submitting to EPEL

## References

- [Fedora Packaging Guidelines](https://docs.fedoraproject.org/en-US/packaging-guidelines/)
- [RPM Macros](https://docs.fedoraproject.org/en-US/packaging-guidelines/RPMMacros/)
- [SPDX License List](https://spdx.org/licenses/)
- [Fedora Python Packaging](https://docs.fedoraproject.org/en-US/packaging-guidelines/Python/)
- [Fedora Systemd Packaging](https://docs.fedoraproject.org/en-US/packaging-guidelines/Systemd/)
- [rpmautospec Documentation](https://docs.fedoraproject.org/en-US/packaging-guidelines/Autospec/)
