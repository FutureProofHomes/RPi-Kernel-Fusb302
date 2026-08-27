#!/usr/bin/env bash
set -euo pipefail

OUT_DIR="/out"
KERNEL_MANIFEST="$OUT_DIR/kernel-build-manifest.txt"
ARCH="${ARCH:-arm64}"
EXPECTED_KERNEL_VERSION="${EXPECTED_KERNEL_VERSION:?EXPECTED_KERNEL_VERSION must be set}"
META_PACKAGE="${META_PACKAGE:?META_PACKAGE must be set}"
META_CHANGELOG="${META_CHANGELOG:?META_CHANGELOG must be set}"

read_meta_version() {
  local meta_source meta_version
  meta_source="$(dpkg-parsechangelog -l "$META_CHANGELOG" -S Source)"
  meta_version="$(dpkg-parsechangelog -l "$META_CHANGELOG" -S Version)"
  if [[ "$meta_source" != "$META_PACKAGE" || "$meta_version" != "${EXPECTED_KERNEL_VERSION}-"* ]]; then
    echo "ERROR: meta changelog must describe $META_PACKAGE version ${EXPECTED_KERNEL_VERSION}-<revision>." >&2
    exit 1
  fi
  printf '%s\n' "$meta_version"
}

meta_version="$(read_meta_version)"
KDEB_PKGVERSION="${meta_version#"${EXPECTED_KERNEL_VERSION}-"}"
if [[ -z "$KDEB_PKGVERSION" ]]; then
  echo "ERROR: meta changelog is missing the image package revision." >&2
  exit 1
fi

if [[ "${1:-}" == "--print-kdeb-pkgversion" ]]; then
  printf '%s\n' "$KDEB_PKGVERSION"
  exit 0
fi

META_COPYRIGHT="${META_COPYRIGHT:?META_COPYRIGHT must be set}"
TARGET="${TARGET:?TARGET must be set}"
if [[ ! -d "$OUT_DIR" || ! -f "$KERNEL_MANIFEST" ]]; then
  echo "ERROR: kernel build manifest is not available in $OUT_DIR." >&2
  exit 1
fi
if [[ ! -f "$META_COPYRIGHT" ]]; then
  echo "ERROR: meta package copyright must be available." >&2
  exit 1
fi

# This file is produced by the preceding kernel build stage in the same target.
source "$KERNEL_MANIFEST"
canonical_kernel_release="${EXPECTED_KERNEL_VERSION}-fusb302-${TARGET}-rpi-v8"
if [[ "$kernel_version" != "$EXPECTED_KERNEL_VERSION" || "$kernel_release" != "$canonical_kernel_release" ]]; then
  echo "ERROR: kernel build manifest does not describe $canonical_kernel_release." >&2
  exit 1
fi
if [[ "$kdeb_pkgversion" != "$KDEB_PKGVERSION" ]]; then
  echo "ERROR: kernel and meta package revisions differ." >&2
  exit 1
fi

if [[ -n "${RELEASE_TAG:-}" ]]; then
  expected_tag="${kernel_release}-${KDEB_PKGVERSION}"
  if [[ "$RELEASE_TAG" != "$expected_tag" ]]; then
    echo "ERROR: expected release tag $expected_tag, got $RELEASE_TAG." >&2
    exit 1
  fi
fi

image_deb="$OUT_DIR/$image_filename"
if [[ ! -f "$image_deb" ]]; then
  echo "ERROR: expected image package $image_deb is not available." >&2
  exit 1
fi
if [[ "$(dpkg-deb -f "$image_deb" Package)" != "$image_package" || "$(dpkg-deb -f "$image_deb" Version)" != "$image_version" || "$(dpkg-deb -f "$image_deb" Architecture)" != "$ARCH" ]]; then
  echo "ERROR: image package metadata does not match the kernel build manifest." >&2
  exit 1
fi

meta_dependency="${image_package} (= ${image_version})"
meta_root="$(mktemp -d)"
trap 'rm -rf "$meta_root"' EXIT
mkdir -p "$meta_root/DEBIAN" "$meta_root/usr/share/doc/$META_PACKAGE"
cat > "$meta_root/DEBIAN/control" <<EOF
Package: $META_PACKAGE
Version: $meta_version
Architecture: $ARCH
Maintainer: FutureProofHomes Inc. <info@futureproofhomes.net>
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

cat "$KERNEL_MANIFEST" > "$OUT_DIR/build-manifest.txt"
cat >> "$OUT_DIR/build-manifest.txt" <<EOF
meta_package=$META_PACKAGE
meta_version=$meta_version
meta_dependency=$meta_dependency
EOF
rm "$KERNEL_MANIFEST"

echo
echo "==> Meta package build complete. Files in /out:"
ls -1 "$OUT_DIR"
