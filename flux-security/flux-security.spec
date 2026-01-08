Name:    flux-security
Version: 0.14.0
Release: 2%{?dist}

Summary: Flux Framework Security Components
License: LGPL-3.0-only
URL:     https://github.com/flux-framework/flux-security
Source0: %{url}/releases/download/v%{version}/%{name}-%{version}.tar.gz

# Fix GCC 16 const-correctness build failure (based on PR #211)
# https://github.com/flux-framework/flux-security/pull/211
# Note: Includes additional fix for missing const in payload_decode_cpy
Patch0:  211.patch

BuildRequires: pkgconfig(libsodium) >= 1.0.14
BuildRequires: pkgconfig(jansson) >= 2.6
BuildRequires: munge-devel
BuildRequires: pam-devel
BuildRequires: libuuid-devel
BuildRequires: python3-sphinx
BuildRequires: python3-sphinx_rtd_theme
BuildRequires: python3-docutils
BuildRequires: autoconf
BuildRequires: automake
BuildRequires: libtool
BuildRequires: make
BuildRequires: gcc

# Required for en_US.UTF-8 locale during build
BuildRequires: glibc-langpack-en

%description
Flux Framework is a suite of projects, tools and libraries which may
be used to build site-custom resource managers at High Performance
Computing sites.

flux-security implements Flux security code and APIs, including the
privileged IMP executable.

%package devel
Summary: Development files for %{name}
Requires: %{name}%{?_isa} = %{version}-%{release}

%description devel
Development files for %{name}.

%prep
%autosetup -n %{name}-%{version} -p1

%build
export LC_ALL=en_US.UTF-8

%configure \
    --enable-pam \
    --disable-static

%make_build

%install
%make_install
find %{buildroot} -name '*.la' -delete

# Create packaged directories
mkdir -p %{buildroot}%{_sysconfdir}/flux/imp/conf.d

%check
# Tests require running munge daemon and setuid capabilities that are not
# available in mock/koji build environments. Skip tests in this environment.
# Tests pass locally with proper munge setup.
:

%ldconfig_scriptlets

%files
%license LICENSE
%doc README.md NEWS.md

# IMP executable - must own parent directory
%dir %{_libexecdir}/flux
%attr(04755, root, root) %{_libexecdir}/flux/flux-imp

# libs
%{_libdir}/lib%{name}.so.1
%{_libdir}/lib%{name}.so.1.0.0

# conf
%dir %{_sysconfdir}/flux
%dir %{_sysconfdir}/flux/security
%dir %{_sysconfdir}/flux/security/conf.d
%dir %{_sysconfdir}/flux/imp
%dir %{_sysconfdir}/flux/imp/conf.d

%config(noreplace) %{_sysconfdir}/flux/security/conf.d/sign.toml

# docs
%{_mandir}/man5/*.5*
%{_mandir}/man8/*.8*

%files devel
# devel
%{_libdir}/pkgconfig/%{name}.pc
%{_libdir}/*.so
%{_includedir}/flux
%{_mandir}/man3/*.3*

%changelog
* Tue Jan  6 2026 Kush Gupta <kugupta@redhat.com> - 0.14.0-2
- Add patch based on PR #211 to fix GCC 16 build failure on Fedora Rawhide
- Includes fix for missing const in payload_decode_cpy (potentially incomplete in upstream PR)
- Fixes const-correctness issues in sign.c (upstream issue #210)

* Thu Feb 27 2025 Mark A. Grondona <mgrondona@llnl.gov> - 0.14.0-1
- update to flux-security v0.14.0

* Wed Nov  6 2024 Mark A. Grondona <mgrondona@llnl.gov> - 0.13.0-1
- update flux-security v0.13.0
- drop configure.patch

* Mon Nov  4 2024 Mark A. Grondona <mgrondona@llnl.gov> - 0.12.0-1
- Update to flux-security v0.12.0
- Install sphinx via pip3 since packaged sphinx is too old
- Add configure patch to replace StrictVersion with Version

* Tue Sep  5 2023 Mark A. Grondona <mgrondona@llnl.gov> - 0.10.0-1
- Update to flux-security v0.10.0

* Fri Jun  9 2023 Mark A. Grondona <mgrondona@llnl.gov> - 0.9.0-2
- Restore sign.toml config file as %%config(noreplace)

* Mon May 22 2023 Mark A. Grondona <mgrondona@llnl.gov> - 0.9.0-1
- Update to flux-security v0.9.0

* Wed Sep 14 2022 Mark A. Grondona <mgrondona@llnl.gov> - 0.8.0-1
- Update to flux-security v0.8.0
- Build with --enable-pam and add pam-devel BuildRequires
- Add patch for Issue #154

* Mon Jun  6 2022 Mark A. Grondona <mgrondona@llnl.gov> - 0.7.0-1
- Update to flux-security v0.7.0
- Package section 3 manpages

* Mon Jan 31 2022 Mark A. Grondona <mgrondona@llnl.gov> - 0.6.0-1
- Update to flux-security v0.6.0
- Add sphinx buildrequires and package man pages

* Sat Sep  4 2021 Mark A. Grondona <mgrondona@llnl.gov> - 0.5.0-1
- Update to flux-security v0.5.0
- Package missing /etc/flux/{security,imp,imp/conf.d} directories

* Thu Dec 17 2020 Mark A. Grondona <mgrondona@llnl.gov> - 0.4.0-2
- Add sign.toml config file to package
- Remove custom CFLAGS (does not compile on TOSS4)

* Thu Oct 22 2020 Jim Garlick <garlick@llnl.gov> - 0.4.0-1
- Initial package for TOSS
