#!/usr/bin/env bash
set -euo pipefail

### --- CONFIG INPUT ------------------------------------------------------
# This script expects:
#  - a kernel config at /config/kernel.config (mounted from host)
#  - an output directory mounted at /out (for .deb files)

KERNEL_TREE="/usr/src/rpi-linux"
CONFIG_IN_CONTAINER="/config/kernel.config"
OUT_DIR="/out"

ARCH="${ARCH:-arm64}"
LOCALVERSION="${LOCALVERSION:--fusb302}"
JOBS="${JOBS:-$(nproc)}"
TARGET="${TARGET:?TARGET must be set}"
KERNEL_REF="${KERNEL_REF:?KERNEL_REF must be set}"
EXPECTED_KERNEL_VERSION="${EXPECTED_KERNEL_VERSION:?EXPECTED_KERNEL_VERSION must be set}"
META_PACKAGE="${META_PACKAGE:?META_PACKAGE must be set}"
META_CHANGELOG="${META_CHANGELOG:?META_CHANGELOG must be set}"
META_COPYRIGHT="${META_COPYRIGHT:?META_COPYRIGHT must be set}"

echo "==> KERNEL_TREE:       $KERNEL_TREE"
echo "==> CONFIG:            $CONFIG_IN_CONTAINER"
echo "==> OUT_DIR:           $OUT_DIR"
echo "==> ARCH:              $ARCH"
echo "==> LOCALVERSION:      $LOCALVERSION"
echo "==> TARGET:            $TARGET"
echo "==> KERNEL_REF:        $KERNEL_REF"
echo "==> EXPECTED VERSION:  $EXPECTED_KERNEL_VERSION"
echo "==> META PACKAGE:      $META_PACKAGE"
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

if [[ ! -f "$META_CHANGELOG" || ! -f "$META_COPYRIGHT" ]]; then
  echo "ERROR: meta package changelog and copyright must be available." >&2
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
meta_source="$(dpkg-parsechangelog -l "$META_CHANGELOG" -S Source)"
meta_version="$(dpkg-parsechangelog -l "$META_CHANGELOG" -S Version)"
if [[ "$meta_source" != "$META_PACKAGE" || "$meta_version" != "${kernel_version}-"* ]]; then
  echo "ERROR: meta changelog must describe $META_PACKAGE version ${kernel_version}-<revision>." >&2
  exit 1
fi
KDEB_PKGVERSION="${meta_version#"${kernel_version}-"}"
if [[ -z "$KDEB_PKGVERSION" ]]; then
  echo "ERROR: meta changelog is missing the image package revision." >&2
  exit 1
fi
canonical_kernel_release="${EXPECTED_KERNEL_VERSION}-fusb302-${TARGET}-rpi-v8"
if [[ "$kernel_release" != "$canonical_kernel_release" ]]; then
  echo "ERROR: stable meta package requires production kernel $canonical_kernel_release, got $kernel_release." >&2
  exit 1
fi

if [[ -n "${RELEASE_TAG:-}" ]]; then
  expected_tag="${kernel_release}-${KDEB_PKGVERSION}"
  if [[ "$RELEASE_TAG" != "$expected_tag" ]]; then
    echo "ERROR: expected release tag $expected_tag, got $RELEASE_TAG." >&2
    exit 1
  fi
fi

echo "==> KDEB_PKGVERSION:   $KDEB_PKGVERSION"
echo "==> META VERSION:      $meta_version"

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

meta_dependency="${image_package} (= ${image_version})"
meta_root="$(mktemp -d)"
trap 'rm -rf "$meta_root"' EXIT
mkdir -p "$meta_root/DEBIAN" "$meta_root/usr/share/doc/$META_PACKAGE"
cat > "$meta_root/DEBIAN/control" <<EOF
Package: $META_PACKAGE
Version: $meta_version
Architecture: $ARCH
Maintainer: Future Proof Homes <info@futureproofhomes.com>
Section: kernel
Priority: optional
Depends: $meta_dependency
Description: FUSB302 Trixie Raspberry Pi kernel meta package
 Tracks the current FUSB302 Trixie Raspberry Pi v8 kernel.
EOF
cp "$META_COPYRIGHT" "$meta_root/usr/share/doc/$META_PACKAGE/copyright"
gzip -9n -c "$META_CHANGELOG" > "$meta_root/usr/share/doc/$META_PACKAGE/changelog.Debian.gz"

meta_deb="$OUT_DIR/${META_PACKAGE}_${meta_version}_${ARCH}.deb"
dpkg-deb --build "$meta_root" "$meta_deb"
test "$(dpkg-deb -f "$meta_deb" Package)" = "$META_PACKAGE"
test "$(dpkg-deb -f "$meta_deb" Version)" = "$meta_version"
test "$(dpkg-deb -f "$meta_deb" Architecture)" = "$ARCH"
test "$(dpkg-deb -f "$meta_deb" Depends)" = "$meta_dependency"

cat > "$OUT_DIR/build-manifest.txt" <<EOF
target=$TARGET
kernel_ref=$KERNEL_REF
resolved_commit=$(git rev-parse HEAD)
kernel_version=$kernel_version
kernel_release=$kernel_release
localversion=$LOCALVERSION
kdeb_pkgversion=$KDEB_PKGVERSION
image_package=$image_package
image_version=$image_version
meta_package=$META_PACKAGE
meta_version=$meta_version
meta_dependency=$meta_dependency
config_sha256=$(sha256sum .config | cut -d' ' -f1)
EOF

echo
echo "==> Build complete. Files in /out:"
ls -1 "$OUT_DIR"
