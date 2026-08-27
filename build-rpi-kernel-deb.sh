#!/usr/bin/env bash
set -euo pipefail

### --- CONFIG INPUT ------------------------------------------------------
# This script expects:
#  - a kernel config at /config/kernel.config (mounted from host)
#  - an output directory mounted at /out (for .deb files and build metadata)

KERNEL_TREE="/usr/src/rpi-linux"
CONFIG_IN_CONTAINER="/config/kernel.config"
OUT_DIR="/out"

ARCH="${ARCH:-arm64}"
LOCALVERSION="${LOCALVERSION:--fusb302}"
JOBS="${JOBS:-$(nproc)}"
TARGET="${TARGET:?TARGET must be set}"
KERNEL_REF="${KERNEL_REF:?KERNEL_REF must be set}"
EXPECTED_KERNEL_VERSION="${EXPECTED_KERNEL_VERSION:?EXPECTED_KERNEL_VERSION must be set}"
KDEB_PKGVERSION="${KDEB_PKGVERSION:?KDEB_PKGVERSION must be set}"

echo "==> KERNEL_TREE:       $KERNEL_TREE"
echo "==> CONFIG:            $CONFIG_IN_CONTAINER"
echo "==> OUT_DIR:           $OUT_DIR"
echo "==> ARCH:              $ARCH"
echo "==> LOCALVERSION:      $LOCALVERSION"
echo "==> TARGET:            $TARGET"
echo "==> KERNEL_REF:        $KERNEL_REF"
echo "==> EXPECTED VERSION:  $EXPECTED_KERNEL_VERSION"
echo "==> KDEB_PKGVERSION:   $KDEB_PKGVERSION"
echo "==> JOBS:              $JOBS"
echo

if [[ ! -f "$CONFIG_IN_CONTAINER" ]]; then
  echo "ERROR: kernel config '$CONFIG_IN_CONTAINER' not found." >&2
  echo "Mount your config as /config/kernel.config" >&2
  exit 1
fi

if [[ ! -d "$OUT_DIR" ]]; then
  echo "ERROR: output directory '$OUT_DIR' does not exist." >&2
  echo "Mount an output directory as /out" >&2
  exit 1
fi

cd "$KERNEL_TREE"

echo "==> Installing .config..."
cp "$CONFIG_IN_CONTAINER" .config

echo "==> Syncing config (olddefconfig)..."
make ARCH="$ARCH" olddefconfig

kernel_version="$(make -s ARCH="$ARCH" kernelversion)"
if [[ "$kernel_version" != "$EXPECTED_KERNEL_VERSION" ]]; then
  echo "ERROR: expected kernel $EXPECTED_KERNEL_VERSION, got $kernel_version" >&2
  exit 1
fi
kernel_release="$(make -s ARCH="$ARCH" kernelrelease)"

for option in CONFIG_TYPEC CONFIG_TYPEC_TCPM CONFIG_TYPEC_TCPCI CONFIG_TYPEC_FUSB302; do
  if ! grep -qx "${option}=m" .config; then
    echo "ERROR: $option must be built as a module" >&2
    exit 1
  fi
done

echo "==> Building kernel + Debian packages (bindeb-pkg)..."
make -j"$JOBS" \
  ARCH="$ARCH" \
  LOCALVERSION="$LOCALVERSION" \
  KDEB_PKGVERSION="$KDEB_PKGVERSION" \
  bindeb-pkg

echo "==> Validating image and headers packages..."
# bindeb-pkg also generates linux-libc-dev, which is not needed for this kernel.
shopt -s nullglob
image_packages=(/usr/src/linux-image-"$kernel_release"_*.deb)
headers_packages=(/usr/src/linux-headers-"$kernel_release"_*.deb)
if (( ${#image_packages[@]} != 1 || ${#headers_packages[@]} != 1 )); then
  echo "ERROR: expected one image and one headers package for $kernel_release" >&2
  printf 'Images: %s\n' "${image_packages[@]:-none}" >&2
  printf 'Headers: %s\n' "${headers_packages[@]:-none}" >&2
  exit 1
fi

image_deb="${image_packages[0]}"
headers_deb="${headers_packages[0]}"
image_package="$(dpkg-deb -f "$image_deb" Package)"
image_version="$(dpkg-deb -f "$image_deb" Version)"
image_arch="$(dpkg-deb -f "$image_deb" Architecture)"
expected_image_package="linux-image-${kernel_release}"

if [[ "$image_package" != "$expected_image_package" || "$image_arch" != "$ARCH" ]]; then
  echo "ERROR: unexpected image package: $image_package $image_version $image_arch" >&2
  exit 1
fi

echo "==> Copying image and headers packages to $OUT_DIR..."
cp -v "$image_deb" "$headers_deb" "$OUT_DIR"/

cat > "$OUT_DIR/kernel-build-manifest.txt" <<EOF
target=$TARGET
kernel_ref=$KERNEL_REF
resolved_commit=$(git rev-parse HEAD)
kernel_version=$kernel_version
kernel_release=$kernel_release
localversion=$LOCALVERSION
kdeb_pkgversion=$KDEB_PKGVERSION
image_package=$image_package
image_version=$image_version
image_filename=$(basename "$image_deb")
config_sha256=$(sha256sum .config | cut -d' ' -f1)
EOF

echo
echo "==> Kernel build complete. Files in /out:"
ls -1 "$OUT_DIR"
