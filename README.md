# RPi Kernel FUSB302: Bookworm

This `bookworm` branch builds the Debian 12 Bookworm Raspberry Pi
kernel with FUSB302 USB-C Power Delivery support for Satellite1.

## Kernel

| Source ref | Kernel version | Package suffix |
| --- | --- | --- |
| `6d15a1029d425b15c59463910ebdccc4afe760d6` | 6.12.96 | `-fusb302-bookworm-rpi-v8` |

The build checks the version after checkout and records the resolved commit in
`build-manifest.txt`.

`make deb` runs separate kernel and meta-package build stages. The kernel stage
builds the image and headers packages, then writes a handoff manifest. The meta
stage reads the committed changelog, validates that manifest, and creates the
meta package with an exact dependency on the image package.

The FUSB302 stack is enabled as modules:

```text
CONFIG_TYPEC=m
CONFIG_TYPEC_TCPM=m
CONFIG_TYPEC_TCPCI=m
CONFIG_TYPEC_FUSB302=m
```

## Build

Docker, Buildx, and an ARM64-capable Docker host are required.

```sh
make deb
```

Artifacts are written to `out/`:

```text
linux-image-6.12.96-fusb302-bookworm-rpi-v8_2_arm64.deb
linux-headers-6.12.96-fusb302-bookworm-rpi-v8_2_arm64.deb
linux-image-fusb302-bookworm-rpi-v8_6.12.96-2_arm64.deb
build-manifest.txt
```

`linux-libc-dev` is not exported.

## Installation

```sh
sudo apt install \
  ./linux-image-6.12.96-fusb302-bookworm-rpi-v8_2_arm64.deb \
  ./linux-image-fusb302-bookworm-rpi-v8_6.12.96-2_arm64.deb
```

Install the matching headers package only when the system uses DKMS or builds
other out-of-tree kernel modules.

The stable `linux-image-fusb302-bookworm-rpi-v8` meta package depends on the
release-specific kernel image. Install both packages together when using GitHub
Release assets directly.

`raspi-firmware` installs the kernel image as `/boot/firmware/kernel8.img`.
Reboot and verify the release:

```sh
uname -r
```

## Versioning

`packaging/linux-image-fusb302-bookworm-rpi-v8/debian/changelog` is the release
version source for the stable meta package. Its version has this format:

```text
<kernel-version>-<image-package-revision>
```

Before a release, update it locally and commit the result:

```sh
make update-meta-changelog NEW_KDEB_PKGVERSION=2
```

The meta-package stage derives the versioned image package revision from that
committed changelog and verifies that its kernel version matches the kernel
build manifest.

## Release Policy

Create the tag `6.12.96-fusb302-bookworm-rpi-v8-2` on an approved `bookworm`
commit to build and publish its image, headers, and stable meta package as one
GitHub Release. CI verifies that the tag matches the kernel release and the
changelog-derived image package revision. Use manual workflow dispatch for a
build without creating a release. Per-run workflow artifacts also include
`build-manifest.txt` for provenance.
