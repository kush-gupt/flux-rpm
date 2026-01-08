# Flux Framework RPM Packaging

[![Build and Test RPMs](https://github.com/kush-gupt/flux-rpm/actions/workflows/build-test.yml/badge.svg)](https://github.com/kush-gupt/flux-rpm/actions/workflows/build-test.yml)

RPM packaging for [Flux Framework](https://flux-framework.org/) components, targeting Fedora and eventually EPEL.

Heavily assisted through Cursor IDE with Claude 4.5 Opus, but all code is reviewed by a human! 

## Packages

| Package | Description |
|---------|-------------|
| [flux-security](https://github.com/flux-framework/flux-security) | Flux security components and IMP executable |
| [flux-core](https://github.com/flux-framework/flux-core) | Flux resource manager core framework |
| [flux-sched](https://github.com/flux-framework/flux-sched) | Fluxion graph-based scheduler |

## Build Status

Testing against:
- **Fedora**: 41, 42, Rawhide (COPR)
- **EPEL**: 9, 10 (CentOS Stream)

## Quick Start

### Install from COPR

```bash
# Install flux-security first (dependency)
sudo dnf copr enable Kushgupta/flux-security
sudo dnf install flux-security flux-security-devel

# Then install flux-core
sudo dnf copr enable Kushgupta/flux-core
sudo dnf install flux-core

# Finally install flux-sched (Fluxion scheduler)
sudo dnf copr enable Kushgupta/flux-sched
sudo dnf install flux-sched
```

### Build Locally

```bash
# Prerequisites (Fedora)
sudo dnf install rpm-build rpmdevtools mock wget podman
sudo usermod -a -G mock $USER

# Build SRPMs
./scripts/build-srpm.sh all

# Build with mock (in order: security -> core -> sched)
mock -r fedora-41-x86_64 --rebuild ~/rpmbuild/SRPMS/flux-security-*.src.rpm
mock -r fedora-41-x86_64 --install /var/lib/mock/fedora-41-x86_64/result/flux-security-*.rpm
mock -r fedora-41-x86_64 --rebuild ~/rpmbuild/SRPMS/flux-core-*.src.rpm
mock -r fedora-41-x86_64 --install /var/lib/mock/fedora-41-x86_64/result/flux-core-*.rpm
mock -r fedora-41-x86_64 --rebuild ~/rpmbuild/SRPMS/flux-sched-*.src.rpm
```

## Automated Updates

This repository includes automated version checking via GitHub Actions:

- **Daily checks** for new upstream releases
- **Automatic PR creation** when new versions are available
- **Spec file extraction** from upstream SRPMs with Fedora adaptations applied

### Manual Update

```bash
# Update to latest versions
./scripts/update-specs.sh all

# Update specific package
./scripts/update-specs.sh flux-core

# Update to specific version
./scripts/update-specs.sh -v v0.82.0 flux-core
```

The update script:
1. Downloads the SRPM from the upstream release
2. Extracts the spec file
3. Applies Fedora-required modifications (SPDX license, macros, etc.)

## Repository Structure

```
flux-rpm/
├── .copr/
│   └── Makefile            # COPR native SCM build script
├── flux-core/
│   └── flux-core.spec
├── flux-security/
│   └── flux-security.spec
├── flux-sched/
│   └── flux-sched.spec
├── scripts/
│   ├── build-srpm.sh
│   └── update-specs.sh
└── .github/workflows/
    ├── build-test.yml      # CI: lint, mock builds, tests
    └── check-updates.yml   # Daily upstream version checks
```

## COPR Setup

This repository uses **COPR's native SCM integration** to automatically build packages directly from GitHub - no GitHub Actions or API tokens needed!

### Projects

- **flux-security**: https://copr.fedorainfracloud.org/coprs/kushgupta/flux-security/
- **flux-core**: https://copr.fedorainfracloud.org/coprs/kushgupta/flux-core/
- **flux-sched**: https://copr.fedorainfracloud.org/coprs/kushgupta/flux-sched/

### How It Works

1. COPR pulls directly from this GitHub repository
2. The `.copr/Makefile` downloads upstream tarballs and builds SRPMs
3. COPR builds RPMs for all configured chroots
4. Packages with "auto-rebuild" enabled will rebuild on git push

### Triggering Builds

**Automatic** (if auto-rebuild is enabled):
- Push to `main` branch triggers automatic rebuild

**Manual**:
1. Go to the COPR project → Packages
2. Click "Rebuild" next to the package

### Manual COPR Build (Alternative)

You can also manually upload SRPMs:

```bash
# Build SRPMs locally
./scripts/build-srpm.sh all

# Upload to COPR
copr-cli build kushgupta/flux-security ~/rpmbuild/SRPMS/flux-security-*.src.rpm
copr-cli build kushgupta/flux-core ~/rpmbuild/SRPMS/flux-core-*.src.rpm
copr-cli build kushgupta/flux-sched ~/rpmbuild/SRPMS/flux-sched-*.src.rpm
```
## License

Same as Flux Framework: LGPL-3.0

## Links

- [Flux Framework](https://flux-framework.org/)
- [Fedora Packaging Guidelines](https://docs.fedoraproject.org/en-US/packaging-guidelines/)
- [COPR](https://copr.fedorainfracloud.org/)
