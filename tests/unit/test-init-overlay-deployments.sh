#!/bin/sh
set -eu

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
TMPDIR="$(mktemp -d)"

cleanup() {
  rm -rf "$TMPDIR"
}

assert_eq() {
  expected="$1"
  actual="$2"
  label="$3"

  if [ "$expected" != "$actual" ]; then
    printf '[fail] %s: esperado=%s atual=%s\n' "$label" "$expected" "$actual" >&2
    exit 1
  fi
}

trap cleanup EXIT INT TERM

export CDA_INIT_OVERLAY_LIB_ONLY=1
export CDA_RUNTIME_DIR="$TMPDIR/run/cda"
. "$ROOT_DIR/initramfs/init-overlay.sh"

mkdir -p "$TMPDIR/deployments/base/images"
cat > "$TMPDIR/deployments/base/deployment.conf" <<'EOF'
DEPLOYMENT_NAME=base
DEPLOYMENT_VERSION=2026.04
DEPLOYMENT_IMAGE_DIR=images
DEPLOYMENT_SLOT=base
EOF
ln -sfn base "$TMPDIR/deployments/current"

export CDA_CMDLINE="cda.deployment_dir=$TMPDIR/deployments cda.deployment=current"
unset DEPLOYMENT_NAME DEPLOYMENT_VERSION DEPLOYMENT_IMAGE_DIR DEPLOYMENT_SLOT DEPLOYMENT_SOURCE 2>/dev/null || true
selected_source_file="$TMPDIR/selected-source"
mount_boot_source > "$selected_source_file"
selected_source="$(cat "$selected_source_file")"
assert_eq "$TMPDIR/deployments/current/images" "$selected_source" "mount_boot_source deployment source"

assert_eq "$TMPDIR/deployments" "$(cmdline_get cda.deployment_dir)" "cmdline_get deployment_dir"
assert_eq "base" "$DEPLOYMENT_NAME" "deployment name from descriptor"
assert_eq "2026.04" "$DEPLOYMENT_VERSION" "deployment version from descriptor"
assert_eq "images" "$DEPLOYMENT_IMAGE_DIR" "deployment image dir"
assert_eq "current" "$DEPLOYMENT_SLOT" "deployment slot from cmdline"

write_runtime_metadata
assert_eq "base" "$(cat "$TMPDIR/run/cda/deployment-name")" "runtime metadata deployment name"
assert_eq "2026.04" "$(cat "$TMPDIR/run/cda/deployment-version")" "runtime metadata deployment version"
assert_eq "current" "$(cat "$TMPDIR/run/cda/deployment-slot")" "runtime metadata deployment slot"

mkdir -p "$TMPDIR/legacy"
export CDA_CMDLINE="cda.squashdir=$TMPDIR/legacy"
unset DEPLOYMENT_NAME DEPLOYMENT_VERSION DEPLOYMENT_IMAGE_DIR DEPLOYMENT_SLOT DEPLOYMENT_SOURCE 2>/dev/null || true
legacy_source="$(mount_boot_source)"
assert_eq "$TMPDIR/legacy" "$legacy_source" "legacy squashdir fallback"

echo "[ok] init-overlay deployment selection"
