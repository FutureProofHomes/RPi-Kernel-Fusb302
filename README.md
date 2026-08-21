# RPi Kernel FUSB302: Trixie

> **Deprecation notice:** Raspberry Pi Linux includes FUSB302 USB-C PD support
> from `6.18.42`. Once that version is available through the Trixie APT
> repository and validated on Satellite1, this custom Trixie kernel will be
> deprecated in favor of the stock `linux-image-rpi-v8` package.

This `trixie` branch builds the Debian 13 Trixie Raspberry Pi kernel
with FUSB302 USB-C Power Delivery support for Satellite1.

## Kernel

| Source ref | Kernel version | Package suffix |
| --- | --- | --- |
| `stable_20260609` | 6.18.34 | `-fusb302-trixie-rpi-v8` |

The build checks the version after checkout and records the resolved commit in
`build-manifest.txt`.

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
linux-image-6.18.34-fusb302-trixie-rpi-v8_1_arm64.deb
linux-headers-6.18.34-fusb302-trixie-rpi-v8_1_arm64.deb
build-manifest.txt
```

`linux-libc-dev` is not exported.

## Installation

```sh
sudo apt install ./linux-image-6.18.34-fusb302-trixie-rpi-v8_1_arm64.deb
```

Install the matching headers package only when the system uses DKMS or builds
other out-of-tree kernel modules.

`raspi-firmware` installs the kernel image as `/boot/firmware/kernel8.img`.
Reboot and verify the release:

```sh
uname -r
```

## Release Policy

Create the tag `6.18.34-fusb302-trixie-rpi-v8-1` on an approved commit to
build and publish its image and headers packages as one GitHub Release. Use
manual workflow dispatch for a build without creating a release. Per-run
workflow artifacts also include `build-manifest.txt` for provenance.
