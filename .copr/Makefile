# COPR build Makefile
# This downloads the upstream source tarball and builds an SRPM

PACKAGE ?= $(notdir $(spec))
SPEC_DIR := $(dir $(spec))

# Extract version from spec file
VERSION := $(shell grep '^Version:' $(spec) | awk '{print $$2}')

# Determine package name from spec file path
PKGNAME := $(basename $(notdir $(spec)))

srpm:
	@echo "Building SRPM for $(PKGNAME) version $(VERSION)"
	
	# Create rpmbuild directory structure
	mkdir -p $(outdir)
	mkdir -p ~/rpmbuild/{SOURCES,SPECS}
	
	# Download the source tarball
	@if [ "$(PKGNAME)" = "flux-security" ]; then \
		echo "Downloading flux-security source..."; \
		curl -L -o ~/rpmbuild/SOURCES/$(PKGNAME)-$(VERSION).tar.gz \
			https://github.com/flux-framework/flux-security/releases/download/v$(VERSION)/$(PKGNAME)-$(VERSION).tar.gz; \
	elif [ "$(PKGNAME)" = "flux-core" ]; then \
		echo "Downloading flux-core source..."; \
		curl -L -o ~/rpmbuild/SOURCES/$(PKGNAME)-$(VERSION).tar.gz \
			https://github.com/flux-framework/flux-core/releases/download/v$(VERSION)/$(PKGNAME)-$(VERSION).tar.gz; \
	fi
	
	# Copy spec file
	cp $(spec) ~/rpmbuild/SPECS/
	
	# Build SRPM
	rpmbuild -bs ~/rpmbuild/SPECS/$(PKGNAME).spec --define "_srcrpmdir $(outdir)"
	
	@echo "SRPM built successfully in $(outdir)"

