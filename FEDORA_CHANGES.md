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
| Systemd scriptlets | Not present | `%systemd_post`, `%systemd_preun`, `%systemd_postun` | Required for systemd service files |
| Python %files paths | Wildcards (`%{python3_sitearch}/*`) | Explicit paths (`flux`, `_flux`) | Fedora packaging committee requirement |
| Explicit lib deps | `Requires: libuuid` | Removed | Let auto-requires handle library deps |
| rpmlintrc files | Not present | Package-specific filters | Suppress false-positive warnings |
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

## Package-Specific Notes

### flux-accounting

The `flux-accounting` package was added to this repository based on the upstream SRPM from GitHub releases (v0.51.0). The following additional adaptations were required:

| Change | Upstream | Fedora | Reason |
|--------|----------|--------|--------|
| License tag | `GPLv3+` | `LGPL-3.0-only` | SPDX identifier required (Fedora 40+) |
| Python path | `%{_libdir}/python3.6/*` | `%{python3_sitelib}/fluxacct` | Portable Python site-packages |
| Python hardcoding | `python3.6` paths | `python%{python3_version}` | Fedora Python packaging guidelines |
| BuildRequires | `python36` | `python3` | Fedora Python packaging |
| BuildRequires | `python3-six` | Removed | Not needed |
| BuildRequires | `python3-jsonschema` | Removed | Build-time only |
| Debug packages | Disabled | Enabled (default) | Fedora policy |
| Sphinx docs | `pip3 install --user` | Packaged sphinx | Mock builds have no network access |
| C++ support | Implicit | Explicit `gcc-c++` | flux-accounting uses C++ for plugins |
| Requires | `sqlite3` | `sqlite >= 3.6.0` | Correct package name |
| Runtime deps | Missing | `python3-flux`, `python3`, `python3-cffi`, `python3-pyyaml` | Explicit runtime dependencies |

flux-accounting requires flux-core at both build time and runtime since it provides a flux plugin (mf_priority.so) and uses the flux Python bindings. The build order is:

1. flux-security
2. flux-core
3. flux-sched (can build parallel with flux-accounting)
4. flux-accounting (can build parallel with flux-sched)

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
%{python3_sitearch}/flux
%{python3_sitearch}/_flux
%{_libdir}/flux/python*
```

**Important**: Python `%files` sections must use explicit paths, not wildcards. The Fedora Packaging Committee [requires explicit paths](https://pagure.io/packaging-committee/issue/782) rather than `%{pythonX_site(lib|arch)}/*` to ensure proper file ownership and avoid conflicts.

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

### 27. Systemd Service Scriptlets (Required)

Packages with systemd service files must use the proper scriptlets. This is separate from `%ldconfig_scriptlets` which handles shared libraries.

```spec
%post
%systemd_post flux.service

%preun
%systemd_preun flux.service

%postun
%systemd_postun_with_restart flux.service
```

For flux-core, we also include custom logic to stop the service gracefully:
```spec
%preun
# Stop the flux service on both removal and upgrade if active
if /usr/bin/systemctl is-active --quiet flux.service 2>/dev/null; then
    echo "Stopping Flux systemd unit due to upgrade/removal..."
    /usr/bin/systemctl stop flux.service
fi
%systemd_preun flux.service
```

See: https://docs.fedoraproject.org/en-US/packaging-guidelines/Scriptlets/#_scriptlets

### 28. Explicit Library Dependencies (Removed)

```diff
- Requires: libuuid
```

Do not explicitly require libraries that are automatically detected by rpm's auto-requires. The `libuuid` library is pulled in automatically from the ELF dependencies. Explicit library requires cause rpmlint error `E: explicit-lib-dependency`.

### 29. Python Shebang Removal (flux-accounting)

Python modules that are not directly executable should not have shebangs. This causes rpmlint error `E: non-executable-script`. Remove shebangs from non-executable Python files in `%install`:

```spec
%install
%make_install

# Remove shebangs from non-executable Python modules
find %{buildroot}%{python3_sitearch}/fluxacct -name '*.py' -type f ! -perm /111 \
    -exec sed -i '1{/^#!/d}' {} \;
```

### 30. Directory Ownership (Required)

Packages must own all directories they create, and must not own directories owned by other packages. For directories under `/etc/flux/system/`:

```spec
%files
%dir %{_sysconfdir}/flux/system
%dir %{_sysconfdir}/flux/system/cron.d
%{_sysconfdir}/flux/system/cron.d/kvs-backup.cron
```

### 31. rpmlintrc Files for False Positives

Create `.rpmlintrc` files to suppress known false-positive warnings. These are placed alongside the spec files.

**flux-core.rpmlintrc:**
```python
# Spelling errors for domain-specific terms
addFilter("spelling-error.*comms")
# libpmi*.so are intentionally in main package (PMI interface)
addFilter("devel-file-in-non-devel-package.*/usr/lib64/flux/libpmi")
# Cross-directory hard links are from upstream Python packaging
addFilter("cross-directory-hard-link")
```

**flux-sched.rpmlintrc:**
```python
# Domain-specific terms
addFilter("spelling-error.*(fluxion|qmanager)")
# Internal libraries without standard soname
addFilter("invalid-soname.*libsched-fluxion")
```

**flux-accounting.rpmlintrc:**
```python
# Domain-specific term for fair share scheduling
addFilter("spelling-error.*fairshare")
```

These filters ensure that domain-specific terminology and intentional packaging decisions don't generate spurious warnings during Fedora Review.

## Current Spec File Compliance Status

All spec files in this repository (`flux-security.spec`, `flux-core.spec`, `flux-sched.spec`, and `flux-accounting.spec`) implement:

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
| Systemd scriptlets | ✅ | `%systemd_post`, `%systemd_preun`, `%systemd_postun` |
| Debug packages enabled | ✅ | No `%define debug_package %{nil}` |
| `%{python3_sitearch}` | ✅ | For Python files |
| Python explicit paths | ✅ | No wildcards in `%files` |
| `python3-pyyaml` naming | ✅ | Correct Fedora package name |
| `-devel` subpackage | ✅ | Proper separation |
| `python3-flux` subpackage | ✅ | Generic Python bindings package |
| `%config(noreplace)` | ✅ | For config files and rc scripts |
| Directory ownership | ✅ | `%dir` for `/etc/flux/system{,/cron.d}` |
| No explicit lib deps | ✅ | Auto-requires handles libraries |
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
| rpmlintrc files | ✅ | Filter domain-specific false positives |
| `%check` section | ✅ | Present (tests may be skipped in mock) |

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
- ✅ Uses `%systemd_post`, `%systemd_preun`, `%systemd_postun` scriptlets
- ✅ No SysV initscripts (forbidden in Fedora)

### File Ownership
- ✅ Package owns all directories it creates (`%dir` directives)
- ✅ Config files use `%config(noreplace)`
- ✅ RC scripts in `/etc/flux/rc*.d/` marked as `%config(noreplace)`
- ✅ Directory ownership for `/etc/flux/system/` hierarchy

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
3. **Enable actual test execution** in `%check` (tests are skipped or non-fatal due to mock environment limitations)
4. **Consider splitting large docs** into `-doc` subpackage if size warrants
5. **Add EPEL conditionals** when submitting to EPEL
6. **GPG signature verification** using `gpgverify` in `%prep`

## References

- [Fedora Packaging Guidelines](https://docs.fedoraproject.org/en-US/packaging-guidelines/)
- [RPM Macros](https://docs.fedoraproject.org/en-US/packaging-guidelines/RPMMacros/)
- [SPDX License List](https://spdx.org/licenses/)
- [Fedora Python Packaging](https://docs.fedoraproject.org/en-US/packaging-guidelines/Python/)
- [Fedora Systemd Packaging](https://docs.fedoraproject.org/en-US/packaging-guidelines/Systemd/)
- [rpmautospec Documentation](https://docs.fedoraproject.org/en-US/packaging-guidelines/Autospec/)
