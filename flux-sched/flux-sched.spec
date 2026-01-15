Name:    flux-sched
Version: 0.48.0
Release: 1%{?dist}
Summary: Job Scheduling Facility for Flux Resource Manager Framework
License: LGPL-3.0-only
URL:     https://github.com/flux-framework/flux-sched
Source0: %{url}/releases/download/v%{version}/%{name}-%{version}.tar.gz

# Can't use binary annotations for some reason:
%undefine _annotated_build

ExcludeArch: ppc64le

BuildRequires: flux-core-devel >= 0.75.0
BuildRequires: cmake
BuildRequires: gcc-c++
# flux-sched requires GCC 12+ for C++20 features
%if 0%{?rhel} == 9
BuildRequires: gcc-toolset-13-gcc-c++
%endif
BuildRequires: pkgconfig(libzmq) >= 4.1.4
BuildRequires: pkgconfig(jansson) >= 2.6
BuildRequires: pkgconfig(hwloc) >= 2.1
BuildRequires: pkgconfig(libxml-2.0) >= 2.9
BuildRequires: yaml-cpp-devel >= 0.5.1
BuildRequires: libedit-devel
BuildRequires: libuuid-devel

BuildRequires: boost >= 1.53.0
BuildRequires: boost-devel
BuildRequires: boost-graph

BuildRequires: python3-pyyaml
BuildRequires: python3-sphinx
BuildRequires: python3-sphinx_rtd_theme
BuildRequires: python3-docutils
BuildRequires: python3-jsonschema

# Should be pulled in by flux-core, but isn't
BuildRequires: python3-cffi

# Should be pulled in by flux-core
BuildRequires: python3 >= 3.6

# Required only by configure?
BuildRequires: python3-devel

# Required for 'make check'
BuildRequires: aspell
# aspell-en is not available in EPEL 10
%if 0%{?fedora} || 0%{?rhel} < 10
BuildRequires: aspell-en
%endif
BuildRequires: hostname
BuildRequires: man-db
BuildRequires: jq
BuildRequires: which
BuildRequires: file
BuildRequires: gdb

# Required for en_US.UTF-8 locale during build
BuildRequires: glibc-langpack-en

Requires: flux-core >= 0.75.0

%description
flux-sched contains the Fluxion graph-based scheduler for the Flux
Resource Manager Framework. It consists of the sched-fluxion-resource
and sched-fluxion-qmanager modules which handle graph-based resource
matching and queue management services, respectively.

%prep
%autosetup -p1 -n %{name}-%{version}

%build
export LC_ALL=en_US.UTF-8

# Enable gcc-toolset-13 on EL9 for C++20 support
%if 0%{?rhel} == 9
. /opt/rh/gcc-toolset-13/enable
%endif

# Avoid picking up non-system Python, which makes later detection of
# python libs and headers fail (since python3-devel package is specific
# to system Python)
export PYTHON=/usr/bin/python3

%cmake \
  -DCMAKE_INSTALL_SYSCONFDIR=%{_sysconfdir} \
  -DCMAKE_INSTALL_LIBDIR=%{_libdir} \
  -DCMAKE_BUILD_TYPE=RelWithDebInfo

%cmake_build

%check
export LC_ALL=en_US.UTF-8
# Run basic sharness framework test (verifies test infrastructure)
# Full test suite requires a running flux broker instance with modprobe
# support which isn't available in mock/koji build environments.

# Build directory contains the test scripts
cd %{_vpath_builddir}/t

# t0000-sharness.t tests the sharness test framework itself - should always pass
./t0000-sharness.t

%install
%cmake_install
find %{buildroot} -name '*.la' -delete

%ldconfig_scriptlets

%files
%license LICENSE
%doc README.md NEWS.md

# rc1,3 files for fluxion
%config(noreplace) %{_sysconfdir}/flux/rc1.d/01-sched-fluxion
%config(noreplace) %{_sysconfdir}/flux/rc3.d/01-sched-fluxion
%config(noreplace) %{_sysconfdir}/flux/modprobe/modprobe.d/fluxion.toml
%{_sysconfdir}/flux/modprobe/rc1.d/fluxion.py
%{_libdir}/flux/modules/sched-fluxion-qmanager.so
%{_libdir}/flux/modules/sched-fluxion-resource.so
%{_libdir}/flux/modules/sched-fluxion-feasibility.so
%{_libdir}/flux/libreapi_cli.so

# flux-ion-R
%{_libexecdir}/flux/cmd/flux-ion-R.py
# flux-ion-resource
%{_libexecdir}/flux/cmd/flux-ion-resource.py
%{python3_sitelib}/fluxion
%{_libdir}/flux/python*

# other libs
%global nopatchversion %(longver=%{version}; shortver=${longver%.*}; echo ${shortver})
%{_libdir}/libfluxion-data.so.%{version}
%{_libdir}/libfluxion-data.so.%{nopatchversion}
%{_libdir}/libsched-fluxion-resource-module.so

# docs
%{_mandir}/man5/*

%changelog
* Wed Jan 7 2026 Kush Gupta <kush-gupt@users.noreply.github.com> - 0.48.0-1
- Update to flux-sched v0.48.0
- Add gcc-toolset-13 for EL9 builds (requires GCC 12+)
- Adapt spec for Fedora packaging

* Mon Sep 8 2025 James Corbett <corbett8@llnl.gov> - 0.47.0-1
- Bump release to flux-sched v0.47.0

* Tue Aug 5 2025 James Corbett <corbett8@llnl.gov> - 0.46.0-1
- Bump release to flux-sched v0.46.0

* Thu May 8 2025 James Corbett <corbett8@llnl.gov> - 0.45.0-1
- Bump release to flux-sched v0.45.0

* Mon Mar 31 2025 James Corbett <corbett8@llnl.gov> - 0.44.0-1
- Bump release to flux-sched v0.44.0

* Tue Mar 4 2025 James Corbett <corbett8@llnl.gov> - 0.43.0-1
- Bump release to flux-sched v0.43.0

* Mon Feb 10 2025 James Corbett <corbett8@llnl.gov> - 0.42.2-1
- Bump release to flux-sched v0.42.2

* Sat Feb 8 2025 James Corbett <corbett8@llnl.gov> - 0.42.1-1
- Bump release to flux-sched v0.42.1

* Thu Feb 6 2025 James Corbett <corbett8@llnl.gov> - 0.42.0-1
- Bump release to flux-sched v0.42.0

* Thu Jan 16 2025 James Corbett <corbett8@llnl.gov> - 0.41.0-2
- Drop unused boost dependencies

* Wed Jan 15 2025 James Corbett <corbett8@llnl.gov> - 0.41.0-1
- Bump release to flux-sched v0.41.0

* Wed Nov 6 2024 James Corbett <corbett8@llnl.gov> - 0.40.0-1
- Bump release to flux-sched v0.40.0

* Tue Oct 1 2024 James Corbett <corbett8@llnl.gov> - 0.39.0-1
- Bump release to flux-sched v0.39.0

* Wed Sep 4 2024 James Corbett <corbett8@llnl.gov> - 0.38.0-1
- Bump release to flux-sched v0.38.0
- Increase gcc-toolset requirement to 12

* Tue Aug 13 2024 James Corbett <corbett8@llnl.gov> - 0.37.0-1
- Bump release to flux-sched v0.37.0
- Increase flux-core version to v0.64.0

* Wed Jul 10 2024 James Corbett <corbett8@llnl.gov> - 0.36.1-1
- Bump release to flux-sched v0.36.1

* Thu Jul 4 2024 James Corbett <corbett8@llnl.gov> - 0.36.0-1
- Bump release to flux-sched v0.36.0

* Thu Jun 6 2024 Mark A. Grondona <mgrondona@llnl.gov> - 0.35.0-1
- Bump release to flux-sched v0.35.0
- Add -DCMAKE_BUILD_TYPE=RelWithDebInfo

* Wed May 8 2024 James Corbett <corbett8@llnl.gov> - 0.34.0-1
- Bump release to flux-sched v0.34.0

* Tue Apr 9 2024 James Corbett <corbett8@llnl.gov> - 0.33.1-1
- Bump release to flux-sched v0.33.1

* Mon Mar 4 2024 James Corbett <corbett8@llnl.gov> - 0.33.0-1
- Bump release to flux-sched v0.33.0
- Add reapi_cli.so to package

* Tue Jan 23 2024 Mark A. Grondona <mgrondona@llnl.gov> - 0.32.0-2
- add patch for issue #1129
- set PYTHON=/usr/bin/python3 to ensure we get system Python

* Tue Nov 7 2023 James Corbett <corbett8@llnl.gov> - 0.30.0-1
- Bump release to flux-sched v0.30.0
- Remove data-staging plugin

* Tue Oct 3 2023 James Corbett <corbett8@llnl.gov> - 0.29.0-1
- Bump release to flux-sched v0.29.0
- Update flux-core requires to v0.53.0

* Fri Mar 31 2023 James Corbett <corbett8@llnl.gov> - 0.27.0-1
- Bump release to flux-sched v0.27.0
- Update flux-core requires to v0.48.0

* Tue Feb 14 2023 Mark A. Grondona <mgrondona@llnl.gov> - 0.26.0-2
- Apply performance fixes from PR #1007

* Wed Feb  8 2023 Mark A. Grondona <mgrondona@llnl.gov> - 0.26.0-1
- Bump release to flux-sched v0.26.0
- Update flux-core requires to v0.47.0
