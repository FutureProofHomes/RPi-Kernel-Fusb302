# RPi Kernel FUSB302

Builds Debian packages for Raspberry Pi kernels with FUSB302 USB-C Power
Delivery support enabled for Satellite1.

## Supported Targets

| Target | OS track | Source ref | Kernel version | Package suffix |
| --- | --- | --- | --- | --- |
| `bookworm` | Raspberry Pi OS Legacy / Debian 12 | `6d15a1029d425b15c59463910ebdccc4afe760d6` | 6.12.96 | `-fusb302-bookworm-rpi-v8` |
| `trixie` | Raspberry Pi OS Current / Debian 13 | `stable_20260609` | 6.18.34 | `-fusb302-trixie-rpi-v8` |

The source ref is the only source-selection input. The build derives and
checks the kernel version after checkout. A manifest records the resolved
commit for every package build.

Each target enables these modules:

```text
CONFIG_TYPEC=m
CONFIG_TYPEC_TCPM=m
CONFIG_TYPEC_TCPCI=m
CONFIG_TYPEC_FUSB302=m
```

## Build

Docker, Buildx, and an ARM64-capable Docker host are required.

```sh
make deb TARGET=bookworm
make deb TARGET=trixie
```

`trixie` is the default target, so `make deb` builds the Trixie package.

Artifacts are written to `out/<target>/`, together with
`build-manifest.txt`. The package names are derived from the selected source,
for example:

```text
linux-image-6.12.96-fusb302-bookworm-rpi-v8_2_arm64.deb
linux-image-6.18.34-fusb302-trixie-rpi-v8_2_arm64.deb
```

## Installation

Install the image package with APT so dependencies are resolved normally:

```sh
sudo apt install ./linux-image-<release>_2_arm64.deb
```

Debian's `raspi-firmware` package provides the kernel post-install hook. It
copies the newest `-rpi-v8` image to `/boot/firmware/kernel8.img`. After
installation, reboot and verify the selected release:

```sh
uname -r
```

Keep the previous kernel installed until boot, FUSB302 binding, and the USB-C
PD contract are validated.

## Release Policy

CI builds Bookworm and Trixie on every change and publishes both only from a
repository release tag. The Raspberry Pi Linux source refs are updated only
through a reviewed change followed by hardware validation.
