# RPi Kernel FUSB302: Bookworm

This `release/bookworm` branch builds the Debian 12 Bookworm Raspberry Pi
kernel with FUSB302 USB-C Power Delivery support for Satellite1.

## Kernel

| Source ref | Kernel version | Package suffix |
| --- | --- | --- |
| `6d15a1029d425b15c59463910ebdccc4afe760d6` | 6.12.96 | `-fusb302-bookworm-rpi-v8` |

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
linux-image-6.12.96-fusb302-bookworm-rpi-v8_2_arm64.deb
linux-headers-6.12.96-fusb302-bookworm-rpi-v8_2_arm64.deb
build-manifest.txt
```

`linux-libc-dev` is not exported.

## Installation

```sh
sudo apt install ./linux-image-6.12.96-fusb302-bookworm-rpi-v8_2_arm64.deb
```

Install the matching headers package only when the system uses DKMS or builds
other out-of-tree kernel modules.

`raspi-firmware` installs the kernel image as `/boot/firmware/kernel8.img`.
Reboot and verify the release:

```sh
uname -r
```

## Release Policy

Pushes and pull requests targeting `release/bookworm` build only Bookworm.
Create the tag `6.12.96-fusb302-bookworm-rpi-v8-2` on an approved commit to
publish its image and headers packages as one GitHub Release. Per-run workflow
artifacts also include `build-manifest.txt` for provenance.
