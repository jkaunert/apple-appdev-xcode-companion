#!/usr/bin/env bash
set -euo pipefail

NODE_VERSION="v24.19.0"
NODE_BASE_URL="https://nodejs.org/dist/$NODE_VERSION"
OUTPUT_DIR=""
DRY_RUN=0

usage() {
  cat <<'EOF'
Usage:
  fetch_hook_runtime.sh [--output-dir PATH] [--dry-run]

Fetches the pinned official Node.js LTS archive for the current macOS
architecture, verifies its published SHA-256, and materializes only:

  <output-dir>/node
  <output-dir>/LICENSE
  <output-dir>/provenance.json

The output is an input to package_dmg.sh --hook-runtime and
--hook-runtime-license. It is not installed globally and does not change PATH.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --output-dir)
      OUTPUT_DIR="${2:-}"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "error: unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

case "$(uname -m)" in
  arm64)
    NODE_ARCH="arm64"
    ARCHIVE_SHA256="8294b7aa9b03997481c06babf1e8b270c859358f27da57a11509afe537ac381d"
    ;;
  x86_64)
    NODE_ARCH="x64"
    ARCHIVE_SHA256="d1b5e999db158c62fe8f7267a4476b035d8bd93b1a605bac24a3f0dd166e3316"
    ;;
  *)
    echo "error: unsupported macOS architecture: $(uname -m)" >&2
    exit 1
    ;;
esac

ARCHIVE="node-$NODE_VERSION-darwin-$NODE_ARCH.tar.gz"
ARCHIVE_URL="$NODE_BASE_URL/$ARCHIVE"
if [[ -z "$OUTPUT_DIR" ]]; then
  OUTPUT_DIR="/tmp/apple-appdev-hook-runtime-$NODE_VERSION-$NODE_ARCH"
fi
if [[ "$OUTPUT_DIR" == "/" || "$OUTPUT_DIR" == "//" || "$OUTPUT_DIR" == "${HOME:-}" ]]; then
  echo "error: --output-dir must be a dedicated runtime directory" >&2
  exit 2
fi

echo "Pinned Xcode hook runtime plan"
echo "  node_version: $NODE_VERSION"
echo "  architecture: $NODE_ARCH"
echo "  archive_url: $ARCHIVE_URL"
echo "  archive_sha256: $ARCHIVE_SHA256"
echo "  output_dir: $OUTPUT_DIR"
if [[ "$DRY_RUN" == "1" ]]; then
  exit 0
fi

for command in curl shasum tar otool file; do
  command -v "$command" >/dev/null 2>&1 || {
    echo "error: $command is required" >&2
    exit 1
  }
done
for destination in "$OUTPUT_DIR/node" "$OUTPUT_DIR/LICENSE" "$OUTPUT_DIR/provenance.json"; do
  [[ ! -e "$destination" ]] || {
    echo "error: refusing to replace existing runtime artifact: $destination" >&2
    exit 1
  }
done

STAGING_DIR="$(mktemp -d "${TMPDIR:-/tmp}/apple-appdev-hook-runtime.XXXXXX")"
cleanup() {
  rm -rf "$STAGING_DIR"
}
trap cleanup EXIT

curl --fail --location --silent --show-error "$ARCHIVE_URL" --output "$STAGING_DIR/$ARCHIVE"
ACTUAL_SHA256="$(shasum -a 256 "$STAGING_DIR/$ARCHIVE" | awk '{print $1}')"
[[ "$ACTUAL_SHA256" == "$ARCHIVE_SHA256" ]] || {
  echo "error: Node archive SHA-256 mismatch" >&2
  exit 1
}
tar -xzf "$STAGING_DIR/$ARCHIVE" -C "$STAGING_DIR"
EXTRACTED_ROOT="$STAGING_DIR/node-$NODE_VERSION-darwin-$NODE_ARCH"
EXTRACTED_NODE="$EXTRACTED_ROOT/bin/node"
EXTRACTED_LICENSE="$EXTRACTED_ROOT/LICENSE"
[[ -x "$EXTRACTED_NODE" && -f "$EXTRACTED_LICENSE" ]] || {
  echo "error: verified Node archive lacks bin/node or LICENSE" >&2
  exit 1
}
if ! file "$EXTRACTED_NODE" | grep -q "Mach-O .* $(uname -m)"; then
  echo "error: verified Node runtime architecture does not match this Mac" >&2
  exit 1
fi
while IFS= read -r dependency; do
  dependency="${dependency#"${dependency%%[![:space:]]*}"}"
  dependency="${dependency%% (*}"
  [[ -n "$dependency" && "$dependency" != "$EXTRACTED_NODE:" ]] || continue
  case "$dependency" in
    /usr/lib/*|/System/Library/*)
      ;;
    *)
      echo "error: official Node runtime has non-system dependency: $dependency" >&2
      exit 1
      ;;
  esac
done < <(otool -L "$EXTRACTED_NODE")

mkdir -p "$OUTPUT_DIR"
cp -p "$EXTRACTED_NODE" "$OUTPUT_DIR/node"
cp -p "$EXTRACTED_LICENSE" "$OUTPUT_DIR/LICENSE"
chmod 755 "$OUTPUT_DIR/node"
chmod 644 "$OUTPUT_DIR/LICENSE"
NODE_SHA256="$(shasum -a 256 "$OUTPUT_DIR/node" | awk '{print $1}')"
LICENSE_SHA256="$(shasum -a 256 "$OUTPUT_DIR/LICENSE" | awk '{print $1}')"
cat > "$OUTPUT_DIR/provenance.json" <<EOF
{
  "schema_version": 1,
  "source": "Node.js official distribution",
  "version": "$NODE_VERSION",
  "architecture": "$NODE_ARCH",
  "archive_url": "$ARCHIVE_URL",
  "archive_sha256": "$ARCHIVE_SHA256",
  "node_sha256": "$NODE_SHA256",
  "license_sha256": "$LICENSE_SHA256"
}
EOF

echo "Pinned hook runtime ready"
echo "  node: $OUTPUT_DIR/node"
echo "  node_sha256: $NODE_SHA256"
echo "  license: $OUTPUT_DIR/LICENSE"
echo "  license_sha256: $LICENSE_SHA256"
echo "  provenance: $OUTPUT_DIR/provenance.json"
