# Makefile for building Raspberry Pi kernel .deb packages via Docker

# ----- Configuration -------------------------------------------------------
DOCKER        ?= docker
PLATFORM      ?= linux/arm64
override TARGET := bookworm
override KERNEL_REF := 6d15a1029d425b15c59463910ebdccc4afe760d6
override EXPECTED_KERNEL_VERSION := 6.12.96
IMAGE_NAME ?= rpi-kernel-builder-bookworm
META_PACKAGE := linux-image-fusb302-$(TARGET)-rpi-v8

# Path to kernel config on the host (override with: make deb CONFIG=/path/to/config)
THIS_MAKEFILE := $(abspath $(lastword $(MAKEFILE_LIST)))
MAKE_DIR      := $(dir $(THIS_MAKEFILE))
CONFIG        ?= $(MAKE_DIR)/config/kernel.config

# Where to put the resulting .deb files
OUT_DIR       ?= $(PWD)/out
META_PACKAGING_DIR := $(MAKE_DIR)/packaging/$(META_PACKAGE)
NEW_KDEB_PKGVERSION ?=

# Extra env you might want to pass into the build script
# e.g.: make deb LOCALVERSION=-fusb302
override LOCALVERSION := -fusb302-bookworm-rpi-v8
EXTRAVERSION    ?= ""
# ----- Targets -------------------------------------------------------------

.PHONY: help image deb shell update-meta-changelog clean-out clean-all

help:
	@echo "Targets:"
	@echo "  make deb           Build kernel .deb packages using Docker"
	@echo "  make image         Build the Docker image only"
	@echo "  make shell         Open an interactive shell inside the build container"
	@echo "  make clean-out     Remove ./out (deb output directory)"
	@echo "  make clean-all     Remove ./out and the Docker image"
	@echo ""
	@echo "Variables (override like: make deb CONFIG=/path/to/config):"
	@echo "  CONFIG=$(CONFIG)"
	@echo "  OUT_DIR=$(OUT_DIR)"
	@echo "  IMAGE_NAME=$(IMAGE_NAME)"
	@echo "  PLATFORM=$(PLATFORM)"
	@echo "  LOCALVERSION=$(LOCALVERSION)"
	@echo "  META_PACKAGE=$(META_PACKAGE)"
	@echo "  make update-meta-changelog NEW_KDEB_PKGVERSION=<revision>"

# Build the Docker image with the kernel tree and package build scripts
image: Dockerfile build-rpi-kernel-deb.sh build-meta-package.sh
	$(DOCKER) buildx build --platform=$(PLATFORM) --load \
		-t $(IMAGE_NAME) .

# Main target: build .deb packages via Docker
deb: image
	@if [ ! -f "$(CONFIG)" ]; then \
		echo "ERROR: CONFIG file not found: $(CONFIG)"; \
		echo "       Set CONFIG=... or place kernel.config in ./config"; \
		exit 1; \
	fi
	mkdir -p "$(OUT_DIR)"
	echo "*" > "$(OUT_DIR)"/.gitignore
	@KDEB_PKGVERSION="$$($(DOCKER) run --rm --platform=$(PLATFORM) \
		-e META_PACKAGE="$(META_PACKAGE)" \
		-e META_CHANGELOG="/meta/debian/changelog" \
		-e EXPECTED_KERNEL_VERSION="$(EXPECTED_KERNEL_VERSION)" \
		-v "$(META_PACKAGING_DIR)":/meta:ro \
		$(IMAGE_NAME) \
		/usr/local/bin/build-meta-package.sh --print-kdeb-pkgversion)" && \
	$(DOCKER) run --rm --platform=$(PLATFORM) \
		-e LOCALVERSION="$(LOCALVERSION)" \
		-e EXTRAVERSION="$(EXTRAVERSION)" \
		-e KDEB_PKGVERSION="$$KDEB_PKGVERSION" \
		-e TARGET="$(TARGET)" \
		-e KERNEL_REF="$(KERNEL_REF)" \
		-e EXPECTED_KERNEL_VERSION="$(EXPECTED_KERNEL_VERSION)" \
		-v "$(dir $(CONFIG))":/config:ro \
		-v "$(OUT_DIR)":/out \
		$(IMAGE_NAME) \
		/usr/local/bin/build-rpi-kernel-deb.sh && \
	$(DOCKER) run --rm --platform=$(PLATFORM) \
		-e TARGET="$(TARGET)" \
		-e EXPECTED_KERNEL_VERSION="$(EXPECTED_KERNEL_VERSION)" \
		-e META_PACKAGE="$(META_PACKAGE)" \
		-e META_CHANGELOG="/meta/debian/changelog" \
		-e META_COPYRIGHT="/meta/debian/copyright" \
		-e RELEASE_TAG="$(RELEASE_TAG)" \
		-v "$(META_PACKAGING_DIR)":/meta:ro \
		-v "$(OUT_DIR)":/out \
		$(IMAGE_NAME) \
		/usr/local/bin/build-meta-package.sh


# Drop into a shell inside the build container (for debugging / manual makes)
shell: image
	$(DOCKER) run --rm -it \
		-e LOCALVERSION="$(LOCALVERSION)" \
		-e TARGET="$(TARGET)" \
		-e KERNEL_REF="$(KERNEL_REF)" \
		-e EXPECTED_KERNEL_VERSION="$(EXPECTED_KERNEL_VERSION)" \
		-v "$(dir $(CONFIG))":/config:ro \
		-v "$(OUT_DIR)":/out \
		$(IMAGE_NAME) \
		/bin/bash

update-meta-changelog: image
	@if [ -z "$(NEW_KDEB_PKGVERSION)" ]; then \
		echo "ERROR: set NEW_KDEB_PKGVERSION to the next image package revision." >&2; \
		exit 1; \
	fi
	$(DOCKER) run --rm --platform=$(PLATFORM) \
		-e META_VERSION="$(EXPECTED_KERNEL_VERSION)-$(NEW_KDEB_PKGVERSION)" \
		-v "$(META_PACKAGING_DIR)":/meta \
		$(IMAGE_NAME) \
		bash -lc 'export DEBFULLNAME="FutureProofHomes Inc." DEBEMAIL="info@futureproofhomes.net"; \
		  cd /meta; \
		  dch --newversion "$$META_VERSION" --distribution bookworm --force-distribution \
		    "Track the matching FUSB302 Bookworm kernel image."'

clean-out:
	rm -rf "$(OUT_DIR)"

clean-all: clean-out
	-$(DOCKER) rmi $(IMAGE_NAME) || true
