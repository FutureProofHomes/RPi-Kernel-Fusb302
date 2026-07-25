# rpi-kernel-fusb302 — Custom Raspberry Pi Kernel with USB-C PD Support

Builds a Debian-packaged Raspberry Pi kernel with USB-C Power Delivery (FUSB302) support enabled for the Satellite1 HAT.

> **⚠️ Early-stage development:**
> This is early-stage experimental software. No official support is provided yet. 
> For issues and feature requests, open an issue on the GitHub repository: https://github.com/futureproofhomes/Satellite1-RPi/issues

## Overview

The default Raspberry Pi OS kernel does **not** include USB-C Power Delivery support. This repository provides a custom kernel built from the Raspberry Pi Linux 6.18.y branch with the necessary drivers enabled as modules:

- `CONFIG_TYPEC=m`
- `CONFIG_TYPEC_TCPM=m`
- `CONFIG_TYPEC_TCPCI=m`
- `CONFIG_TYPEC_FUSB302=m`

## Kernel Package

The build produces standard Debian kernel packages:

- `linux-image-6.18.34-fusb302-rpi-v8_2_arm64.deb` — kernel image and modules
- `linux-headers-6.18.34-fusb302-rpi-v8_2_arm64.deb` — development headers (optional)

The version string `6.18.34-fusb302-rpi-v8` consists of:
- Base version: `6.18.34` (Raspberry Pi branch revision)
- Local version suffix: `-fusb302-rpi-v8`
- Debian revision: `2` (the third component in the `.deb` filename)

## Installation

The default Raspberry Pi OS kernel lacks USB-C Power Delivery support.

Install the custom kernel package:

```bash
sudo dpkg -i linux-image-6.18.34-fusb302-rpi-v8_*_arm64.deb
```

The kernel enables these modules:

```
CONFIG_TYPEC=m
CONFIG_TYPEC_TCPM=m
CONFIG_TYPEC_TCPCI=m
CONFIG_TYPEC_FUSB302=m
```

Reboot to load the new kernel:

```bash
sudo reboot
```

Verify after reboot:

```bash
uname -r
# Should display: 6.18.34-fusb302-rpi-v8
```

4. Check that FUSB302 module is loaded:

```bash
lsmod | grep fusb302
```

## Build Process

### Dependencies

Build dependencies (installed in Docker image):
- `bc`, `bison`, `flex`, `build-essential`
- `libncurses-dev`, `libssl-dev`, `libelf-dev`, `dwarves`
- `debhelper`, `dpkg-dev`, `fakeroot`, `devscripts`
- `device-tree-compiler` (for overlays, though not used here)
- Git, rsync, cpio, kmod

Runtime dependencies on target:
- None beyond standard Raspberry Pi OS kernel infrastructure

### Prerequisites

- Docker
- `make`
- Git
- Internet connection (for downloading Raspberry Pi Linux source on first build)

### Source Layout

```
rpi-kernel-fusb302/
├── config/
│   └── kernel.config   # Kernel configuration (defconfig + enabled modules)
├── Dockerfile          # Build environment (Debian Trixie + kernel build deps)
├── build-rpi-kernel-deb.sh  # Build script executed inside container
├── builddeb.patch      # Patches Raspberry Pi's debian/rules for custom LOCALVERSION
└── Makefile            # Build orchestration
```

### Quick start

```bash
make deb
```

This will:
1. Build the Docker image (if not already built)
2. Run the build script inside the container
3. Copy resulting `.deb` packages to the local `out/` directory

### Detailed steps

```bash
# Build the Docker image
make image

# Build the kernel packages
make deb
```

The build script:
1. Copies your `config/kernel.config` into the kernel tree
2. Runs `make olddefconfig` to merge with defaults
3. Executes `make -j$(nproc) bindeb-pkg` to produce `.deb` packages
4. Copies the packages from `/usr/src/` in the container to the mounted `out/` directory on the host

### Output

Built packages appear in `out/`:

```
out/
├── linux-image-6.18.34-fusb302-rpi-v8_2_arm64.deb
├── linux-headers-6.18.34-fusb302-rpi-v8_2_arm64.deb
└── linux-libc-dev-arm64-cross_6.18.34-2_arm64.deb (if cross-built)
```

### Build variables

| Variable | Default | Description |
|----------|---------|-------------|
| `CONFIG` | `config/kernel.config` | Path to kernel config file |
| `OUT_DIR` | `$(PWD)/out` | Where to copy `.deb` files |
| `IMAGE_NAME` | `rpi-kernel-builder` | Docker image name |
| `PLATFORM` | `linux/arm64` | Docker platform |
| `LOCALVERSION` | `-fusb302-rpi-v8` | Kernel `LOCALVERSION` string |
| `KDEB_PKGVERSION` | `2` | Debian package revision |
| `JOBS` | `$(nproc)` | Parallel build jobs |

Example customization:

```bash
make deb LOCALVERSION="-fusb302-rpi-v8-custom" KDEB_PKGVERSION=3
```

### Shell access

Enter the build container for debugging or manual builds:

```bash
make shell
```

Inside the container, the kernel tree is at `/usr/src/rpi-linux`.

### Kernel Configuration

The kernel config is based on Raspberry Pi's default configuration for the 6.12.y branch, with the following USB-C PD related options enabled as modules (`=m`):

```
CONFIG_TYPEC=m
CONFIG_TYPEC_TCPM=m
CONFIG_TYPEC_TCPCI=m
CONFIG_TYPEC_FUSB302=m
```

Other notable options:
- ARM 64-bit (AArch64) architecture
- Multi-platform support for various Raspberry Pi boards
- Standard Raspberry Pi peripherals (I²C, SPI, I²S, etc.)

The config file is automatically generated via `make savedefconfig` from a working tree and can be updated as needed.

### Building on different architectures

The Docker build uses `linux/arm64` platform emulation via `buildx`. This works on x86_64 hosts with QEMU emulation enabled. For native ARM builds, omit `--platform` or adjust accordingly in the Makefile.

### Updating the kernel

To update to a newer Raspberry Pi kernel branch:

1. Update the branch in `Dockerfile` (line cloning `rpi-6.18.y` or newer)
2. Re-run the build; the new kernel will be installed side-by-side
3. Update `/boot/firmware/config.txt` to load the new kernel image (if not auto-selected by `rpi-eeprom-update`)

## Troubleshooting

### Build fails with "cannot find -l..."

Ensure all build dependencies are installed in the Docker image (they are defined in `Dockerfile`). Rebuild the image:

```bash
make clean-all
make image
```

### Kernel doesn't boot

Confirm you installed the correct package for your board (Zero W2 uses `arm64`). Check that `/boot/firmware/kernel8-fusb302.img` exists after installation. If not, you may need to manually copy the kernel image from `/usr/lib/linux-image-<version>/` to `/boot/firmware/`.

### FUSB302 module not loaded

Check that the `fusb302` module exists:

```bash
modprobe fusb302
lsmod | grep fusb302
```

If `modprobe` fails, the kernel may not have been built with `CONFIG_TYPEC_FUSB302=m`. Verify your kernel config.

## Notes

- The kernel package follows Debian kernel naming conventions and integrates with the Raspberry Pi bootloader
- `LOCALVERSION` ensures this kernel is distinguishable from the stock Raspberry Pi kernel
- The patch `builddeb.patch` modifies Raspberry Pi's upstream `debian/rules` to apply the custom `LOCALVERSION` correctly

## License

See the top-level LICENSE file. This package contains Raspberry Pi Linux kernel sources which are GPLv2.

## Repository

https://github.com/futureproofhomes/Satellite1-RPi/
