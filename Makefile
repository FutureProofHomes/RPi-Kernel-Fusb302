# Makefile for building Raspberry Pi kernel .deb packages via Docker

# ----- Configuration -------------------------------------------------------
DOCKER        ?= docker
PLATFORM      ?= linux/arm64
TARGET        ?= trixie

include targets.mk

VALID_TARGETS := bookworm trixie
ifeq ($(filter $(TARGET),$(VALID_TARGETS)),)
$(error Unsupported TARGET '$(TARGET)'; choose one of: $(VALID_TARGETS))
endif

TARGET_UPPER := $(shell printf '%s' '$(TARGET)' | tr '[:lower:]' '[:upper:]')
DEBIAN_RELEASE ?= $($(TARGET_UPPER)_DEBIAN_RELEASE)
KERNEL_REF ?= $($(TARGET_UPPER)_KERNEL_REF)
EXPECTED_KERNEL_VERSION ?= $($(TARGET_UPPER)_EXPECTED_KERNEL_VERSION)
IMAGE_NAME ?= rpi-kernel-builder-$(TARGET)

# Path to kernel config on the host (override with: make deb CONFIG=/path/to/config)
THIS_MAKEFILE := $(abspath $(lastword $(MAKEFILE_LIST)))
MAKE_DIR      := $(dir $(THIS_MAKEFILE))
CONFIG        ?= $(MAKE_DIR)/config/kernel.config

# Where to put the resulting .deb files
OUT_DIR       ?= $(PWD)/out/$(TARGET)

# Extra env you might want to pass into the build script
# e.g.: make deb LOCALVERSION=-fusb302 KDEB_PKGVERSION=2
LOCALVERSION    ?= $($(TARGET_UPPER)_LOCALVERSION)
EXTRAVERSION    ?= ""
KDEB_PKGVERSION ?= 2
# ----- Targets -------------------------------------------------------------

.PHONY: help image deb shell clean-out clean-all

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
	@echo "  TARGET=$(TARGET)"
	@echo "  DEBIAN_RELEASE=$(DEBIAN_RELEASE)"
	@echo "  KERNEL_REF=$(KERNEL_REF)"
	@echo "  EXPECTED_KERNEL_VERSION=$(EXPECTED_KERNEL_VERSION)"
	@echo "  OUT_DIR=$(OUT_DIR)"
	@echo "  IMAGE_NAME=$(IMAGE_NAME)"
	@echo "  PLATFORM=$(PLATFORM)"
	@echo "  LOCALVERSION=$(LOCALVERSION)"
	@echo "  KDEB_PKGVERSION=$(KDEB_PKGVERSION)"

# Build the Docker image with the kernel tree and build script
image: Dockerfile build-rpi-kernel-deb.sh
	$(DOCKER) buildx build --platform=$(PLATFORM) --load \
		--build-arg DEBIAN_RELEASE="$(DEBIAN_RELEASE)" \
		--build-arg KERNEL_REF="$(KERNEL_REF)" \
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
	$(DOCKER) run --rm --platform=$(PLATFORM) \
		-e LOCALVERSION="$(LOCALVERSION)" \
		-e EXTRAVERSION="$(EXTRAVERSION)" \
		-e KDEB_PKGVERSION="$(KDEB_PKGVERSION)" \
		-e TARGET="$(TARGET)" \
		-e KERNEL_REF="$(KERNEL_REF)" \
		-e EXPECTED_KERNEL_VERSION="$(EXPECTED_KERNEL_VERSION)" \
		-v "$(dir $(CONFIG))":/config:ro \
		-v "$(OUT_DIR)":/out \
		$(IMAGE_NAME) \
		/usr/local/bin/build-rpi-kernel-deb.sh


# Drop into a shell inside the build container (for debugging / manual makes)
shell: image
	$(DOCKER) run --rm -it \
		-e LOCALVERSION="$(LOCALVERSION)" \
		-e KDEB_PKGVERSION="$(KDEB_PKGVERSION)" \
		-e TARGET="$(TARGET)" \
		-e KERNEL_REF="$(KERNEL_REF)" \
		-e EXPECTED_KERNEL_VERSION="$(EXPECTED_KERNEL_VERSION)" \
		-v "$(dir $(CONFIG))":/config:ro \
		-v "$(OUT_DIR)":/out \
		$(IMAGE_NAME) \
		/bin/bash

clean-out:
	rm -rf "$(OUT_DIR)"

clean-all: clean-out
	-$(DOCKER) rmi $(IMAGE_NAME) || true
