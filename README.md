# Flux Framework RPM Packaging

[![Build and Test RPMs](https://github.com/kush-gupt/flux-rpm/actions/workflows/build-test.yml/badge.svg)](https://github.com/kush-gupt/flux-rpm/actions/workflows/build-test.yml)

RPM packaging for [Flux Framework](https://flux-framework.org/) components, targeting Fedora and EPEL. 

Flux is a next-generation resource management framework for HPC clusters, developed at Lawrence Livermore National Laboratory.

Heavily assisted through Cursor IDE with Claude Opus, but all code is reviewed by a human!

## Packages

| Package | Description | COPR |
|---------|-------------|------|
| [flux-security](https://github.com/flux-framework/flux-security) | Flux security components and IMP executable | [repo](https://copr.fedorainfracloud.org/coprs/kushgupta/flux-security/) |
| [flux-core](https://github.com/flux-framework/flux-core) | Flux resource manager core framework | [repo](https://copr.fedorainfracloud.org/coprs/kushgupta/flux-core/) |
| [flux-sched](https://github.com/flux-framework/flux-sched) | Fluxion graph-based scheduler | [repo](https://copr.fedorainfracloud.org/coprs/kushgupta/flux-sched/) |
| [flux-accounting](https://github.com/flux-framework/flux-accounting) | Bank/accounting interface for job priorities and fairshare | [repo](https://copr.fedorainfracloud.org/coprs/kushgupta/flux-accounting/) |

## Installation

Available for **Fedora** 43, 44, Rawhide and **EPEL** 9, 10 via COPR. Packages must be installed in dependency order:

```
flux-security → flux-core → flux-sched
                          → flux-accounting
```

```bash
# Install flux-security first
sudo dnf copr enable kushgupta/flux-security
sudo dnf install flux-security flux-security-devel

# Then install flux-core
sudo dnf copr enable kushgupta/flux-core
sudo dnf install flux-core

# Finally install flux-sched
sudo dnf copr enable kushgupta/flux-sched
sudo dnf install flux-sched

# Optional: install flux-accounting
sudo dnf copr enable kushgupta/flux-accounting
sudo dnf install flux-accounting
```

## Building Locally

```bash
# Prerequisites (Fedora)
sudo dnf install rpm-build rpmdevtools mock wget podman
sudo usermod -a -G mock $USER

# Build SRPMs
./scripts/build-srpm.sh all

# Build with mock (in order: security -> core -> sched/accounting)
mock -r fedora-43-x86_64 --rebuild ~/rpmbuild/SRPMS/flux-security-*.src.rpm
mock -r fedora-43-x86_64 --install /var/lib/mock/fedora-43-x86_64/result/flux-security-*.rpm
mock -r fedora-43-x86_64 --rebuild ~/rpmbuild/SRPMS/flux-core-*.src.rpm
mock -r fedora-43-x86_64 --install /var/lib/mock/fedora-43-x86_64/result/flux-core-*.rpm
mock -r fedora-43-x86_64 --rebuild ~/rpmbuild/SRPMS/flux-sched-*.src.rpm
mock -r fedora-43-x86_64 --rebuild ~/rpmbuild/SRPMS/flux-accounting-*.src.rpm
```

Source tarballs are verified against the SHA256 checksum in each package's `sources` file during SRPM builds.

## CI/CD

**Build targets:**
- **Fedora**: 43, 44, Rawhide (rawhide builds are expected to fail until [luaposix supports Lua 5.5](https://github.com/luaposix/luaposix/issues/394))
- **EPEL**: 9, 10 (CentOS Stream)

**Automation:**
- Daily checks for new upstream releases
- Automatic PR creation when new versions are available
- COPR rebuilds triggered automatically on merge to `main`
- Mock chroot/package caches and ccache persist across CI runs via GitHub Actions cache, so repeat builds skip most chroot setup, package downloads, and compilation (on EL9, cmake builds route the gcc-toolset compiler through ccache via `CMAKE_*_COMPILER_LAUNCHER`); smoke tests likewise reuse a cached dnf package cache

## Repository Structure

```
flux-rpm/
├── .copr/
│   └── Makefile                 # COPR SCM build script
├── .github/
│   ├── containers/
│   │   └── Dockerfile.builder   # Build container image
│   ├── workflows/
│   │   ├── build-containers.yml
│   │   ├── build-test.yml
│   │   ├── check-updates.yml
│   │   └── trigger-copr.yml
│   └── dependabot.yml
├── flux-core/                   # Each package dir contains:
├── flux-security/               #   .spec, .rpmlintrc, sources,
├── flux-sched/                  #   and any patches
├── flux-accounting/
├── scripts/
│   ├── build-srpm.sh
│   └── update-specs.sh
├── FEDORA_CHANGES.md
└── LICENSE
```

## Fedora Adaptations

See [FEDORA_CHANGES.md](FEDORA_CHANGES.md) for a detailed breakdown of all changes made to the upstream LLNL spec files for Fedora packaging compliance (SPDX licensing, modern macros, Python packaging, systemd scriptlets, etc.).

## License

Same as Flux Framework: LGPL-3.0

## Links

- [Flux Framework](https://flux-framework.org/)
- [Fedora Packaging Guidelines](https://docs.fedoraproject.org/en-US/packaging-guidelines/)
- [COPR](https://copr.fedorainfracloud.org/)
