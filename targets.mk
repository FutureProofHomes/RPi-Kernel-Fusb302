# Supported Raspberry Pi OS kernel tracks. Source refs select the kernel;
# expected versions are verified after checkout rather than configured.
BOOKWORM_DEBIAN_RELEASE := bookworm
BOOKWORM_KERNEL_REF := 6d15a1029d425b15c59463910ebdccc4afe760d6
BOOKWORM_EXPECTED_KERNEL_VERSION := 6.12.96
BOOKWORM_LOCALVERSION := -fusb302-bookworm-rpi-v8

TRIXIE_DEBIAN_RELEASE := trixie
TRIXIE_KERNEL_REF := stable_20260609
TRIXIE_EXPECTED_KERNEL_VERSION := 6.18.34
TRIXIE_LOCALVERSION := -fusb302-trixie-rpi-v8
