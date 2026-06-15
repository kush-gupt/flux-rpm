# Fedora Spec File Adaptations

This document describes changes made to the upstream LLNL/TOSS spec files for Fedora packaging compliance. The upstream specs are distributed as SRPMs attached to GitHub releases; our Fedora specs diverge from those as described below.

## Upstream Baseline

Upstream SRPMs used as comparison baseline (from GitHub release assets):

| Package | Upstream SRPM | Fedora Version |
|---------|---------------|----------------|
| flux-core | `flux-core-0.81.0-1.t4.src.rpm` (v0.81.0) | 0.85.0 |
| flux-security | `flux-security-0.14.0-1.t4.src.rpm` (v0.14.0) | 0.15.0 |
| flux-sched | `flux-sched-0.47.0-1.t4.src.rpm` (v0.47.0) | 0.52.0 |
| flux-accounting | `flux-accounting-0.51.0-1.t4.src.rpm` (v0.51.0) | 0.57.2 |

## Common Changes

These adaptations apply across the four packages where applicable. Not every item applies to every package -- some upstream specs already used the modern form.

### Metadata and Tags

- **License**: Upstream uses `LGPL-3.0`, `LGPLv3`, `GPLv2+`, or `GPLv3+` -- changed to SPDX `LGPL-3.0-only` (required since Fedora 38)
- **Source0**: Changed from local filename (`%{name}-%{version}.tar.gz`) to full fetchable GitHub URL using `%{url}` macro
- **URL**: Capitalized `Url:` to `URL:` for consistency
- **Release**: Changed `1%{dist}` to `1%{?dist}` (conditional dist tag; flux-core only -- other packages already used `%{?dist}`)
- **Removed**: `BuildRoot`, `Group` tags (deprecated)

### Removed Deprecated Constructs

- `%defattr(-,root,root)` -- rpmbuild sets defaults automatically
- `%clean` section -- rpmbuild handles cleanup
- `%define debug_package %{nil}` and `%define __spec_install_post` -- debug packages must be enabled per Fedora policy (upstream disables them for LLNL launchmon compatibility)

### Modern Macros

| Upstream | Fedora | Notes |
|----------|--------|-------|
| `make %{?_smp_mflags}` | `%make_build` | flux-sched already used `%make_build`; flux-security had no `make` in `%build` |
| `make install DESTDIR=$RPM_BUILD_ROOT` | `%make_install` | flux-sched already used `%make_install`; Fedora flux-sched uses `%cmake_install` |
| `$RPM_BUILD_ROOT` / `${RPM_BUILD_ROOT}` | `%{buildroot}` | In `%install`, `%check`, and `%files` sections |
| `%post -p /sbin/ldconfig` | `%ldconfig_scriptlets` | flux-sched had no ldconfig at all; `%ldconfig_scriptlets` was added |
| `%define` | `%global` (where kept) | `%define` is local to each section; `%global` spans the whole spec |
| `\|\| (cat config.log && exit 1)` after `%configure` | removed | rpmbuild handles configure failures natively |

### Build Dependencies

- Use `pkgconfig()` for libraries where available (e.g. `pkgconfig(uuid)` instead of `libuuid-devel`, `pkgconfig(liblz4)` instead of `lz4-devel`, `pkgconfig(ncurses)` instead of `ncurses-devel`, `pkgconfig(yaml-cpp)` instead of `yaml-cpp-devel`)
- Add explicit build tools: `autoconf`, `automake`, `libtool`, `make`, `gcc` (and `gcc-c++` where needed)
- Replace `pip3 install --user -r doc/requirements.txt` with packaged `python3-sphinx`, `python3-sphinx_rtd_theme`, `python3-docutils` (mock builds have no network access)
- Remove `python3-pip` BuildRequires
- Use `pkgconfig(flux-security)` and `pkgconfig(flux-core)` instead of bare package names (pulls in `-devel` automatically)
- Add `glibc-langpack-en` for `LC_ALL=en_US.UTF-8` during doc builds

### Python Packaging

- **Single Python**: Remove multi-version build loop (upstream builds for 3.6, 3.8, 3.9, 3.11, 3.12 simultaneously)
- **Naming**: `python3-yaml` changed to `python3-pyyaml` (Fedora package name)
- **Portable paths**: Replace hardcoded version-specific Python paths (e.g. `%define python38_sitearch /usr/lib64/python3.8/site-packages`, `%{_libdir}/flux/python3.6/*`) with `%{python3_sitearch}` / `%{python3_sitelib}` / `%{_libdir}/flux/python*`
- **Explicit files**: Use `%{python3_sitearch}/flux` instead of `%{python3_sitearch}/*` (Fedora packaging committee requirement)
- **Version-specific subpackages removed**: Upstream `%package python3.11` etc. replaced with single system Python

### Subpackages

- Add `-devel` subpackages for flux-core and flux-security (upstream bundles development files with the main package)

### File Marking and Ownership

- Add `%license LICENSE` and `%doc README.md NEWS.md`
- Add `%config(noreplace)` for config and rc scripts
- Add `%dir` directives for directories the package creates (e.g. `/etc/flux/system/`, `/etc/flux/system/cron.d/`)

### Systemd Scriptlets

Packages with service files use proper scriptlets (`%systemd_post`, `%systemd_preun`, `%systemd_postun_with_restart`) -- upstream had none.

### Removed Upstream Items

- LLNL build-farm conditionals (`%if 0%{?bl6}` for IBM Spectrum MPI)
- Per-architecture custom CFLAGS/LDFLAGS blocks (Fedora's `%configure` handles this; upstream also used `KOJI_CFLAGS`)
- LLNL-specific patches (e.g. `systemd-touch-linger.patch` in flux-core)
- Explicit library Requires (`libuuid`, `sqlite`, `ncurses`) -- rpm auto-requires handles ELF dependencies
- Transitive BuildRequires (`libsodium-devel`, `openpgm-devel`, `krb5-devel` in flux-core) -- pulled in by `pkgconfig(libzmq)`
- `export PATH=$HOME/.local/bin:$PATH` (pip artifact; flux-core and flux-security only)

### Changelog Format

Upstream omits hyphen before version-release; Fedora requires it:

```
Upstream: * Wed Dec  3 2025 Name <email> 0.81.0-1
Fedora:   * Wed Dec  3 2025 Name <email> - 0.81.0-1
```

### rpmlintrc Files

Each package has a `.rpmlintrc` file alongside its spec to suppress known false positives (domain-specific spelling warnings, intentional devel-file placement, setuid binary warnings).

## Package-Specific Notes

### flux-core

- **LTO disabled**: `%global _lto_cflags %{nil}` -- LTO causes test failures
- **Strict-aliasing disabled**: `%global build_cflags %{build_cflags} -fno-strict-aliasing` -- bundled libev has known violations
- **~~Requires filter~~**: ~~`%global __requires_exclude /bin/false`~~ -- removed; upstream no longer uses `#!/bin/false` shebangs (flux-core#7643)
- **~~Shebang mangling exclusion~~**: ~~`%global __brp_mangle_shebangs_exclude_from ^%{_libexecdir}/flux/`~~ -- removed; cmd scripts now have proper shebangs (flux-core#7643, flux-accounting#873)
- **rpath removal**: Uses `chrpath -d` with improved error handling (`xargs -I{}` instead of deprecated `-ti`, `2>/dev/null || true`)
- **Custom preun**: Stops `flux.service` gracefully before upgrade/removal, with `2>/dev/null` on systemctl check
- **Lua paths**: Changed from hardcoded `5.3` to wildcard `*` for portability
- **EPEL 10**: Conditional for `aspell-en` (not available in EPEL 10)

### flux-security

- **Summary corrected**: "Flux Resource Manager Framework" changed to "Flux Framework Security Components"
- **Setuid binary**: `flux-imp` uses `%attr(04755, root, root)` with rpmlintrc filter for setuid warnings
- **Directory ownership**: `%dir %{_libexecdir}/flux` owned by this package
- **Dropped patch**: `211.patch` (GCC 16 const-correctness fix) was carried for v0.14.0; merged upstream and dropped in v0.15.0

### flux-sched

- **Patches**: `cmake-install-libdir-fix.patch` (CMake 4.0+ GNUInstallDirs conflict; `set(CACHE FORCE)` no longer removes a same-named normal variable under policy CMP0126 NEW)
- **Dropped patch**: `gcc15-ice-workaround.patch` (GCC 15 ICE in `scope_guard.hpp`) was carried for v0.48.0; the ICE was fixed in GCC 15.2.1 and the patch dropped in v0.52.0
- **Architecture exclusion** (retained from upstream): `ExcludeArch: ppc64le`
- **Build annotation** (retained from upstream): `%undefine _annotated_build` (binary annotations cause build failures)
- **C++20 toolchain**: Upstream uses `gcc-toolset-12` unconditionally; changed to conditional `gcc-toolset-13` on EL9 only (`%if 0%{?rhel} == 9`); Fedora uses system GCC
- **Build system**: Uses `%cmake`/`%cmake_build`/`%cmake_install` (upstream uses `%cmake` for configure but `%make_build`/`%make_install` for build/install)
- **License corrected**: Upstream says `GPLv2+` but project is actually LGPL-3.0
- **Python sitelib**: `%{python3_sitelib}/fluxion` instead of `%{python3_sitelib}/*`
- **Python path hardcoding**: `%{_libdir}/flux/python*` instead of `%{_libdir}/flux/python3.6/*`
- **Requires added**: `flux-core >= %{flux_core_minver}` and `python3-pyyaml` (upstream has no explicit Requires)
- **Macro style**: `%global nopatchversion` instead of `%define nopatchversion`

### flux-accounting

- **Dropped patch**: `py-compile-python312.patch` (Python 3.12+ `imp` module fix) was carried for v0.56.0; fixed upstream in v0.57.x and dropped
- **License corrected**: Upstream says `GPLv3+` but project is actually LGPL-3.0
- **Shebang removal**: Non-executable Python modules have shebangs stripped in `%install` to avoid rpmlint `E: non-executable-script`
- **Python subcommand permissions**: `.py` files in `%{_libexecdir}/flux/cmd` set executable (flux checks `R_OK|X_OK`)
- **BuildRequires removed**: `python36`, `python3-cffi`, `python3-six`, `python3-yaml`, `python3-jsonschema` (not needed; Python deps come transitively via `pkgconfig(flux-core)`)
- **BuildRequires added**: `gcc-c++` (C++ plugins), `pkgconfig(systemd)`, `systemd-rpm-macros`
- **`--disable-static` added**: Upstream does not pass `--disable-static` to `%configure`; Fedora adds it
- **Requires added**: `flux-core >= %{flux_core_minver}` (runtime dependency for Python bindings and plugin)

## References

- [Fedora Packaging Guidelines](https://docs.fedoraproject.org/en-US/packaging-guidelines/)
- [Fedora Python Packaging](https://docs.fedoraproject.org/en-US/packaging-guidelines/Python/)
- [Fedora Systemd Packaging](https://docs.fedoraproject.org/en-US/packaging-guidelines/Systemd/)
- [SPDX License List](https://spdx.org/licenses/)
