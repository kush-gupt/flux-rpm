Name:    flux-accounting
Version: 0.55.0
Release: 1%{?dist}
Summary: Bank/Accounting Interface for the Flux Resource Manager
License: LGPL-3.0-only
URL:     https://github.com/flux-framework/flux-accounting
Source0: %{url}/releases/download/v%{version}/%{name}-%{version}.tar.gz

BuildRequires: pkgconfig(jansson) >= 2.10
BuildRequires: pkgconfig(sqlite3)
BuildRequires: python3
BuildRequires: python3-devel
BuildRequires: python3-cffi
BuildRequires: python3-pyyaml
BuildRequires: python3-sphinx
BuildRequires: python3-sphinx_rtd_theme
BuildRequires: python3-docutils
BuildRequires: flux-core
BuildRequires: flux-core-devel

BuildRequires: autoconf
BuildRequires: automake
BuildRequires: libtool
BuildRequires: make
BuildRequires: gcc
BuildRequires: gcc-c++

# for _unitdir
BuildRequires: systemd-rpm-macros

# Required for en_US.UTF-8 locale during documentation build
BuildRequires: glibc-langpack-en

Requires: flux-core
Requires: python3-flux
Requires: sqlite >= 3.6.0
Requires: python3
Requires: python3-cffi
Requires: python3-pyyaml

%description
Flux Framework is a suite of projects, tools and libraries which may
be used to build site-custom resource managers at High Performance
Computing sites.

flux-accounting manages user/bank accounts and calculates and updates
job priorities, job usage values, and fairshare values. It consists of
a SQLite database and a set of libraries and front-end services to
interact with this database.

%prep
%autosetup -n %{name}-%{version} -p1

%build
export LC_ALL=en_US.UTF-8

%configure \
    --with-systemdsystemunitdir=%{_unitdir} \
    --disable-static

%make_build

%install
# Disable automake's Python byte-compilation (uses deprecated 'imp' module)
# rpm will handle byte-compilation automatically via brp-python-bytecompile
%make_install am_cv_python_pyc_compile=:

# Remove libtool archives
find %{buildroot} -name '*.la' -delete

%ldconfig_scriptlets

%files
%license DISCLAIMER.LLNS
%doc README.md NEWS

# Python fluxacct package
%{python3_sitelib}/fluxacct

# priority plugin
%{_libdir}/flux/job-manager/plugins/mf_priority.so

# fluxacct namespace package in flux python dir
%{_libdir}/flux/python%{python3_version}/fluxacct

# commands + other executables
%{_libexecdir}/flux/cmd/flux-account.py
%{_libexecdir}/flux/cmd/flux-account-update-fshare
%{_libexecdir}/flux/cmd/flux-account-priority-update.py
%{_libexecdir}/flux/cmd/flux-account-update-db.py
%{_libexecdir}/flux/cmd/flux-account-service.py
%{_libexecdir}/flux/cmd/flux-account-fetch-job-records.py
%{_libexecdir}/flux/cmd/flux-account-update-usage.py

# rc scripts
%{_sysconfdir}/flux/rc1.d/01-flux-account-priority-update

# systemd unit file
%{_unitdir}/flux-accounting.service

# manpages
%{_mandir}/man1/*.1*

%changelog
* Sun Jan 11 2026 Kushal Gupta <kugupta@redhat.com> - 0.55.0-1
- Initial Fedora package based on upstream v0.55.0
