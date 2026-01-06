Name:    flux-core
Version: 0.81.0
Release: 1%{?dist}
Summary: Flux Resource Manager Framework
License: LGPL-3.0-only
URL:     https://github.com/flux-framework/flux-core
Source0: %{url}/releases/download/v%{version}/%{name}-%{version}.tar.gz

# Redhat only provides /usr/bin/false, but tests look for /bin/false
%global __requires_exclude /bin/false

# Disable strict-aliasing errors - upstream uses bundled libev which has
# known strict-aliasing violations. Upstream already uses -Wno-strict-aliasing
# in their build but Fedora's optflags may override this with -Werror variants.
%global optflags %{optflags} -Wno-error=strict-aliasing

BuildRequires: flux-security-devel >= 0.14

BuildRequires: pkgconfig(libzmq) >= 4.1.4
BuildRequires: pkgconfig(jansson) >= 2.6
BuildRequires: pkgconfig(hwloc) >= 2.1
BuildRequires: pkgconfig(sqlite3) >= 3.6.0
BuildRequires: pkgconfig(bash-completion)
BuildRequires: lua-devel >= 5.1
BuildRequires: lz4-devel
BuildRequires: munge-devel
BuildRequires: lua-posix
BuildRequires: libuuid-devel
BuildRequires: ncurses-devel
BuildRequires: libarchive-devel
BuildRequires: systemd-devel

# for _tmpfilesdir
BuildRequires: systemd-rpm-macros

# for chrpath
BuildRequires: chrpath

# requirements specifically for 'make check'
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
BuildRequires: procps-ng

# libtool CCLD of libflux-core.la adds -lsodium -lpgm -lgssapi_krb5
BuildRequires: libsodium-devel >= 0.4.5
BuildRequires: openpgm-devel
BuildRequires: krb5-devel

# rely on autoreq for most dependencies
Requires: lua >= 5.1
Requires: lua-posix >= 5.1
Requires: sqlite >= 3.6.0
Requires: libuuid
Requires: ncurses
Requires: python3
Requires: python3-cffi
Requires: python3-pyyaml
Requires: python3-ply

BuildRequires: python3
BuildRequires: python3-devel
BuildRequires: python3-cffi
BuildRequires: python3-pyyaml
BuildRequires: python3-ply
BuildRequires: python3-setuptools
BuildRequires: python3-sphinx
BuildRequires: python3-sphinx_rtd_theme
BuildRequires: python3-docutils

BuildRequires: autoconf
BuildRequires: automake
BuildRequires: libtool
BuildRequires: make
BuildRequires: gcc
BuildRequires: gcc-c++

%description
Flux Framework is a suite of projects, tools and libraries which may
be used to build site-custom resource managers at High Performance
Computing sites.

flux-core implements the communication layer and lowest level services
and interfaces for the Flux resource manager framework. It consists of
a distributed message broker and plug-in comms modules that implement
various distributed services.

%package devel
Summary: Development files for %{name}
Requires: %{name}%{?_isa} = %{version}-%{release}

%description devel
Development files for %{name}.

%package -n python3-flux
Summary: Python 3 bindings for flux-core
Requires: %{name}%{?_isa} = %{version}-%{release}
Requires: python3-cffi
Requires: python3-pyyaml
Requires: python3-ply

%description -n python3-flux
Python 3 bindings for flux-core resource manager framework.

%prep
%autosetup -n %{name}-%{version} -p1

%build
export LC_ALL=en_US.UTF-8

%configure \
    --with-systemdsystemunitdir=%{_unitdir} \
    --with-flux-security \
    --enable-broken-locale-mode \
    --disable-static

%make_build

%install
%make_install

# Remove rpath from all binaries and libraries
find %{buildroot} \
    -type f -exec \
    sh -c "file {} | grep -Pi ': elf (32|64)-bit' > /dev/null" \; -print | \
    xargs -I{} chrpath -d {} 2>/dev/null || true

# do not package .la files
find %{buildroot} -name '*.la' -delete

# Create directories owned by package
mkdir -p -m 0755 %{buildroot}%{_sysconfdir}/flux/rc3.d
mkdir -p -m 0755 %{buildroot}%{_sysconfdir}/flux/rc1.d

%ldconfig_scriptlets

%preun
# Stop the flux service on both removal and upgrade if active
if /usr/bin/systemctl is-active --quiet flux.service 2>/dev/null; then
    echo "Stopping Flux systemd unit due to upgrade/removal..."
    echo "For progress, check: systemctl status flux"
    /usr/bin/systemctl stop flux.service
fi

%files
%license LICENSE
%doc README.md NEWS.md

# commands + other executables
%{_bindir}/flux
%{_bindir}/flux-python
%{_libexecdir}/flux

# this package owns top level libdir/flux
%dir %{_libdir}/flux

# connectors + comms modules
%{_libdir}/flux/connectors
%{_libdir}/flux/modules

# job-manager plugins
%{_libdir}/flux/job-manager

# libs
%{_libdir}/lib%{name}.so.2
%{_libdir}/lib%{name}.so.2.0.0
%{_libdir}/libflux-idset.so.1
%{_libdir}/libflux-idset.so.1.0.0
%{_libdir}/libflux-optparse.so.1
%{_libdir}/libflux-optparse.so.1.0.0
%{_libdir}/libflux-schedutil.so.1
%{_libdir}/libflux-schedutil.so.1.0.0
%{_libdir}/libflux-hostlist.so.1
%{_libdir}/libflux-hostlist.so.1.0.0
%{_libdir}/libflux-taskmap.so.1
%{_libdir}/libflux-taskmap.so.1.0.0

# pmi libs required in base pkg not devel
%{_libdir}/flux/libpmi.so
%{_libdir}/flux/libpmi.so.0
%{_libdir}/flux/libpmi.so.0.0.0
%{_libdir}/flux/libpmi2.so
%{_libdir}/flux/libpmi2.so.0
%{_libdir}/flux/libpmi2.so.0.0.0

# doc + "flux help" config file (json)
%{_mandir}/man1/*.1*
%{_mandir}/man5/*.5*
%{_mandir}/man7/*.7*
%{_datadir}/flux

# tmpfiles config
%{_tmpfilesdir}/*

# cronfiles
%{_sysconfdir}/flux/system/cron.d/kvs-backup.cron

# bash completions
%{_datadir}/bash-completion/completions/flux

# lua binding/modules
%{_libdir}/lua/*/flux.so
%{_datadir}/lua/*/flux
%{_datadir}/lua/*/fluxometer
%{_datadir}/lua/*/fluxometer.lua

# rc scripts
%dir %{_sysconfdir}/flux
%dir %{_sysconfdir}/flux/rc1.d
%dir %{_sysconfdir}/flux/rc3.d

# modprobe + dirs
%dir %{_sysconfdir}/flux/modprobe
%dir %{_sysconfdir}/flux/modprobe/modprobe.d
%dir %{_sysconfdir}/flux/modprobe/rc1.d
%dir %{_sysconfdir}/flux/modprobe/rc3.d
%dir %{_datadir}/flux/modprobe/modprobe.d
%dir %{_libexecdir}/flux/modprobe/rc1.d
%dir %{_libexecdir}/flux/modprobe/rc3.d
%{_datadir}/flux/modprobe/modprobe.toml
%{_libexecdir}/flux/modprobe/rc1.py
%{_libexecdir}/flux/modprobe/rc3.py

# flux-run-system-scripts + dirs
%{_libexecdir}/flux/flux-run-system-scripts
%dir %{_libexecdir}/flux/prolog.d
%dir %{_libexecdir}/flux/epilog.d
%dir %{_libexecdir}/flux/housekeeping.d

# systemd unit file(s)
%{_unitdir}/*.service

# shell
%dir %{_sysconfdir}/flux/shell
%dir %{_sysconfdir}/flux/shell/lua.d
%dir %{_sysconfdir}/flux/shell/lua.d/mpi
%config(noreplace) %{_sysconfdir}/flux/shell/initrc.lua
%{_sysconfdir}/flux/shell/lua.d/*.lua
%{_sysconfdir}/flux/shell/lua.d/mpi/*.lua

%files devel
# devel
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

%files -n python3-flux
# python binding
%{python3_sitearch}/*
%{_libdir}/flux/python*

%changelog
* Wed Dec  3 2025 Mark A. Grondona <mgrondona@llnl.gov> - 0.81.0-1
- bump version to v0.81.0

* Tue Nov  4 2025 Mark A. Grondona <mgrondona@llnl.gov> - 0.80.0-1
- bump version to v0.80.0
- remove bash completions workaround
- add python3-cffi, python3-yaml, python3-ply to Requires

* Thu Oct  9 2025 Mark A. Grondona <mgrondona@llnl.gov> - 0.79.0-2
- emit message on preun script that Flux will be shut down

* Wed Oct  8 2025 Mark A. Grondona <mgrondona@llnl.gov> - 0.79.0-1
- bump version to v0.79.0
- add systemd postun script to shutdown Flux

* Thu Sep  4 2025 Mark A. Grondona <mgrondona@llnl.gov> - 0.78.0-1
- bump version to v0.78.0
