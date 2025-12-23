# Flux Framework RPM Packaging

[![Build and Test RPMs](https://github.com/kush-gupt/flux-rpm/actions/workflows/build-test.yml/badge.svg)](https://github.com/kush-gupt/flux-rpm/actions/workflows/build-test.yml)

RPM packaging for [Flux Framework](https://flux-framework.org/) components, targeting Fedora and eventually EPEL.

Heavily assisted through Cursor IDE with Claude 4.5 Opus, but all code is reviewed by a human! 

## Packages

| Package | Description |
|---------|-------------|
| [flux-security](https://github.com/flux-framework/flux-security) | Flux security components and IMP executable |
| [flux-core](https://github.com/flux-framework/flux-core) | Flux resource manager core framework |

## Build Status

Testing against:
- **Fedora**: 40, 41, 42, 43, Rawhide
- **EPEL**: 9, 10

## Quick Start

### Install from COPR

```bash
sudo dnf copr enable YOUR_USERNAME/flux-framework
sudo dnf install flux-core
```

### Build Locally

```bash
# Prerequisites (Fedora)
sudo dnf install rpm-build rpmdevtools mock wget podman
sudo usermod -a -G mock $USER

# Build SRPMs
./scripts/build-srpm.sh all

# Build with mock
mock -r fedora-41-x86_64 --rebuild ~/rpmbuild/SRPMS/flux-security-*.src.rpm
mock -r fedora-41-x86_64 --install /var/lib/mock/fedora-41-x86_64/result/flux-security-*.rpm
mock -r fedora-41-x86_64 --rebuild ~/rpmbuild/SRPMS/flux-core-*.src.rpm
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
├── flux-core/
│   └── flux-core.spec
├── flux-security/
│   └── flux-security.spec
├── scripts/
│   ├── build-srpm.sh
│   └── update-specs.sh
└── .github/workflows/
    ├── build-test.yml
    └── check-updates.yml
```

## COPR Setup

1. Create project at [COPR](https://copr.fedorainfracloud.org/)
2. Upload SRPMs or configure SCM source
3. Enable webhook for automatic builds

## EPEL Considerations

For EPEL 8/9/10, additional conditionals may be needed for dependency differences.

## License

This packaging: MIT | Flux Framework: LGPL-3.0

## Links

- [Flux Framework](https://flux-framework.org/)
- [Fedora Packaging Guidelines](https://docs.fedoraproject.org/en-US/packaging-guidelines/)
- [COPR](https://copr.fedorainfracloud.org/)
