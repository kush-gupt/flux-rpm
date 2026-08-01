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
	@echo "Downloading $(PKGNAME) source..."
	curl -fL -o ~/rpmbuild/SOURCES/$(PKGNAME)-$(VERSION).tar.gz \
		https://github.com/flux-framework/$(PKGNAME)/releases/download/v$(VERSION)/$(PKGNAME)-$(VERSION).tar.gz
	
	# Verify tarball checksum against the sources file
	@expected=$$(grep -F "($(PKGNAME)-$(VERSION).tar.gz)" $(SPEC_DIR)sources | awk '{print $$4}'); \
	if [ -z "$$expected" ]; then \
		echo "ERROR: no SHA256 entry for $(PKGNAME)-$(VERSION).tar.gz in $(SPEC_DIR)sources"; \
		exit 1; \
	fi; \
	actual=$$(sha256sum ~/rpmbuild/SOURCES/$(PKGNAME)-$(VERSION).tar.gz | awk '{print $$1}'); \
	if [ "$$actual" != "$$expected" ]; then \
		echo "ERROR: SHA256 mismatch for $(PKGNAME)-$(VERSION).tar.gz"; \
		echo "  expected: $$expected"; \
		echo "  actual:   $$actual"; \
		exit 1; \
	fi; \
	echo "SHA256 verified for $(PKGNAME)-$(VERSION).tar.gz"
	
	# Copy spec file
	cp $(spec) ~/rpmbuild/SPECS/
	
	# Copy any patches from spec directory to SOURCES
	@if ls $(SPEC_DIR)*.patch 1>/dev/null 2>&1; then \
		echo "Copying patches..."; \
		cp $(SPEC_DIR)*.patch ~/rpmbuild/SOURCES/; \
	fi
	
	# Build SRPM (define _topdir so rpmbuild finds our sources)
	rpmbuild -bs ~/rpmbuild/SPECS/$(PKGNAME).spec --define "_topdir $$HOME/rpmbuild" --define "_srcrpmdir $(outdir)"
	
	@echo "SRPM built successfully in $(outdir)"

