#!/usr/bin/env bash
set -euo pipefail

TOOL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$(cd "$TOOL_DIR/../.." && pwd)"

AGENT_RUNTIME=""
AGENT_VERSION=""
AGENT_URL=""
PLUGIN_PROFILE=""
PLUGIN_VERSION=""
PLUGIN_NAME="apple-appdev-workflow"
OUTPUT_DIR=""
OUTPUT_DMG=""
BUNDLE_ID="com.joshuakaunert.apple-appdev-workflow.xcode-headless-installer"
BUNDLE_NAME="AppleAppDevXcodeHeadlessInstaller"
DISPLAY_NAME="Apple AppDev Xcode Headless Installer"
APP_EXECUTABLE="xcode-headless-installer"
APP_ICON_NAME="AppleAppDevXcodeHeadlessInstaller.icns"
APP_VERSION=""
APP_BUILD="1"
MIN_SYSTEM_VERSION="15.0"
VOLUME_NAME="Apple AppDev Xcode Headless Installer"
RELEASE_MODE=0
NOTARIZE=0
DRY_RUN=0
NOTARY_PROFILE="${APPLE_APPDEV_WORKFLOW_NOTARY_PROFILE:-}"
NOTARY_TIMEOUT="30m"
SIGN_IDENTITY="${APPLE_APPDEV_WORKFLOW_CODESIGN_IDENTITY:-}"

usage() {
  cat <<'EOF'
Usage:
  package_dmg.sh --plugin-profile /path/to/rendered/xcode-headless [options]
  package_dmg.sh --agent-runtime /path/to/codex [options]
  package_dmg.sh --plugin-profile PATH --agent-runtime PATH [options]

Payload options:
  --plugin-profile PATH     Rendered and validated xcode-headless plugin profile.
  --plugin-version VALUE    Embedded plugin version. Defaults to its manifest version.
  --plugin-name VALUE       Embedded plugin name. Defaults to apple-appdev-workflow.
  --agent-runtime PATH      Optional Codex runtime binary to embed.
  --agent-version VALUE     Agent payload directory name. Defaults to runtime version plus timestamp.
  --agent-url URL           Agent metadata URL. Defaults to local-fork-runtime://<agent-version>/codex.

Package options:
  --output-dir PATH         Output directory. Defaults to /tmp/apple-appdev-xcode-headless-installer.
  --output-dmg PATH         Output DMG path. Defaults under output-dir.
  --bundle-id ID            Installer app bundle id.
  --version VERSION         Installer app version. Defaults to plugin version or 0.1.0.
  --build BUILD             Installer app build. Defaults to 1.
  --min-system VERSION      LSMinimumSystemVersion. Defaults to 15.0.
  --sign IDENTITY           Developer ID Application signing identity.
  --release                 Require Developer ID signing and hardened runtime.
  --notarize                Submit the signed DMG to Apple, staple, and assess.
  --keychain-profile NAME   notarytool keychain profile.
  --notary-timeout VALUE    notarytool --wait timeout. Defaults to 30m.
  --dry-run                 Print the plan without compiling, copying, signing, or uploading.

Environment:
  APPLE_APPDEV_WORKFLOW_CODESIGN_IDENTITY
  APPLE_APPDEV_WORKFLOW_NOTARY_PROFILE

Notes:
  A profile-only package never embeds or changes Xcode's active Codex agent.
  Packaging and notarization never activate an embedded agent. Agent activation
  remains a separate manual installer command after the DMG passes Gatekeeper.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --plugin-profile)
      PLUGIN_PROFILE="${2:-}"
      shift 2
      ;;
    --plugin-version)
      PLUGIN_VERSION="${2:-}"
      shift 2
      ;;
    --plugin-name)
      PLUGIN_NAME="${2:-}"
      shift 2
      ;;
    --agent-runtime)
      AGENT_RUNTIME="${2:-}"
      shift 2
      ;;
    --agent-version)
      AGENT_VERSION="${2:-}"
      shift 2
      ;;
    --agent-url)
      AGENT_URL="${2:-}"
      shift 2
      ;;
    --output-dir)
      OUTPUT_DIR="${2:-}"
      shift 2
      ;;
    --output-dmg)
      OUTPUT_DMG="${2:-}"
      shift 2
      ;;
    --bundle-id)
      BUNDLE_ID="${2:-}"
      shift 2
      ;;
    --version)
      APP_VERSION="${2:-}"
      shift 2
      ;;
    --build)
      APP_BUILD="${2:-}"
      shift 2
      ;;
    --min-system)
      MIN_SYSTEM_VERSION="${2:-}"
      shift 2
      ;;
    --sign)
      SIGN_IDENTITY="${2:-}"
      shift 2
      ;;
    --release)
      RELEASE_MODE=1
      shift
      ;;
    --notarize)
      NOTARIZE=1
      shift
      ;;
    --keychain-profile)
      NOTARY_PROFILE="${2:-}"
      shift 2
      ;;
    --notary-timeout)
      NOTARY_TIMEOUT="${2:-}"
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

has() {
  command -v "$1" >/dev/null 2>&1
}

xml_escape() {
  local value="$1"
  value="${value//&/&amp;}"
  value="${value//</&lt;}"
  value="${value//>/&gt;}"
  value="${value//\"/&quot;}"
  printf '%s' "$value"
}

json_escape() {
  local value="$1"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  value="${value//$'\n'/\\n}"
  printf '%s' "$value"
}

timestamp() {
  date -u +%Y%m%dT%H%M%SZ
}

runtime_version() {
  "$AGENT_RUNTIME" --version | awk '{print $2; exit}'
}

sanitize_version() {
  printf '%s' "$1" | tr -c 'A-Za-z0-9._+-' '-'
}

require_safe_component() {
  local label="$1"
  local value="$2"
  if [[ -z "$value" || ! "$value" =~ ^[A-Za-z0-9._+-]+$ || "$value" == "." || "$value" == ".." ]]; then
    echo "error: $label must be one safe path component" >&2
    exit 2
  fi
}

manifest_value() {
  local key="$1"
  local manifest="$2"
  plutil -extract "$key" raw -o - "$manifest"
}

manifest_has_key() {
  local key="$1"
  local manifest="$2"
  plutil -extract "$key" xml1 -o - "$manifest" >/dev/null 2>&1
}

[[ -n "$AGENT_RUNTIME" || -n "$PLUGIN_PROFILE" ]] || {
  echo "error: pass --plugin-profile, --agent-runtime, or both" >&2
  exit 2
}
[[ -n "$BUNDLE_ID" ]] || { echo "error: --bundle-id cannot be empty" >&2; exit 2; }
[[ -n "$APP_BUILD" ]] || { echo "error: --build cannot be empty" >&2; exit 2; }
[[ -n "$MIN_SYSTEM_VERSION" ]] || { echo "error: --min-system cannot be empty" >&2; exit 2; }
if [[ "$RELEASE_MODE" == "1" && -z "$SIGN_IDENTITY" ]]; then
  echo "error: --release requires --sign or APPLE_APPDEV_WORKFLOW_CODESIGN_IDENTITY" >&2
  exit 2
fi
if [[ "$NOTARIZE" == "1" && "$RELEASE_MODE" != "1" ]]; then
  echo "error: --notarize requires --release" >&2
  exit 2
fi
if [[ "$NOTARIZE" == "1" && -z "$NOTARY_PROFILE" ]]; then
  echo "error: --notarize requires --keychain-profile or APPLE_APPDEV_WORKFLOW_NOTARY_PROFILE" >&2
  exit 2
fi

has swiftc || { echo "error: swiftc is required" >&2; exit 1; }
has shasum || { echo "error: shasum is required" >&2; exit 1; }
has hdiutil || { echo "error: hdiutil is required" >&2; exit 1; }
has codesign || { echo "error: codesign is required" >&2; exit 1; }
has plutil || { echo "error: plutil is required" >&2; exit 1; }
if [[ "$NOTARIZE" == "1" ]]; then
  has xcrun || { echo "error: xcrun is required for notarization" >&2; exit 1; }
  has spctl || { echo "error: spctl is required for notarization validation" >&2; exit 1; }
fi

RUNTIME_VERSION=""
SOURCE_RUNTIME_SHA256=""
FINAL_RUNTIME_SHA512=""
if [[ -n "$AGENT_RUNTIME" ]]; then
  [[ -x "$AGENT_RUNTIME" ]] || {
    echo "error: --agent-runtime must be executable: $AGENT_RUNTIME" >&2
    exit 1
  }
  RUNTIME_VERSION="$(runtime_version)"
  [[ -n "$RUNTIME_VERSION" ]] || {
    echo "error: could not determine runtime version from $AGENT_RUNTIME --version" >&2
    exit 1
  }
  if [[ -z "$AGENT_VERSION" ]]; then
    AGENT_VERSION="$(sanitize_version "$RUNTIME_VERSION")-fork-xcode-canary-$(timestamp)"
  fi
  require_safe_component "agent version" "$AGENT_VERSION"
  if [[ -z "$AGENT_URL" ]]; then
    AGENT_URL="local-fork-runtime://$AGENT_VERSION/codex"
  fi
  SOURCE_RUNTIME_SHA256="$(shasum -a 256 "$AGENT_RUNTIME" | awk '{print $1}')"
fi

PLUGIN_MANIFEST_SHA256=""
PLUGIN_CORE_SHA256=""
APP_ICON_SOURCE=""
if [[ -n "$PLUGIN_PROFILE" ]]; then
  [[ -d "$PLUGIN_PROFILE" ]] || {
    echo "error: --plugin-profile must be a directory: $PLUGIN_PROFILE" >&2
    exit 1
  }
  PLUGIN_MANIFEST="$PLUGIN_PROFILE/.codex-plugin/plugin.json"
  [[ -f "$PLUGIN_MANIFEST" ]] || {
    echo "error: plugin profile manifest is missing: $PLUGIN_MANIFEST" >&2
    exit 1
  }
  MANIFEST_PLUGIN_NAME="$(manifest_value name "$PLUGIN_MANIFEST")"
  MANIFEST_PLUGIN_VERSION="$(manifest_value version "$PLUGIN_MANIFEST")"
  require_safe_component "plugin name" "$PLUGIN_NAME"
  require_safe_component "plugin manifest name" "$MANIFEST_PLUGIN_NAME"
  [[ "$MANIFEST_PLUGIN_NAME" == "$PLUGIN_NAME" ]] || {
    echo "error: plugin profile name mismatch: expected $PLUGIN_NAME; found $MANIFEST_PLUGIN_NAME" >&2
    exit 1
  }
  if [[ -z "$PLUGIN_VERSION" ]]; then
    PLUGIN_VERSION="$MANIFEST_PLUGIN_VERSION"
  fi
  require_safe_component "plugin version" "$PLUGIN_VERSION"
  require_safe_component "plugin manifest version" "$MANIFEST_PLUGIN_VERSION"
  [[ "$MANIFEST_PLUGIN_VERSION" == "$PLUGIN_VERSION" ]] || {
    echo "error: plugin profile version mismatch: expected $PLUGIN_VERSION; found $MANIFEST_PLUGIN_VERSION" >&2
    exit 1
  }
  if manifest_has_key mcpServers "$PLUGIN_MANIFEST"; then
    echo "error: xcode-headless plugin profile must omit mcpServers" >&2
    exit 1
  fi
  if manifest_has_key routerSelection "$PLUGIN_MANIFEST"; then
    echo "error: xcode-headless plugin profile contains retired routerSelection" >&2
    exit 1
  fi
  CORE_FILES=(
    "hooks/hooks.json"
    "hooks/apple_router.mjs"
    "routing/router-policy.json"
    "routing/top-level-owner-kernel.md"
  )
  for relative_path in "${CORE_FILES[@]}"; do
    [[ -f "$PLUGIN_PROFILE/$relative_path" ]] || {
      echo "error: plugin profile lacks required file: $relative_path" >&2
      exit 1
    }
  done
  PLUGIN_MANIFEST_SHA256="$(shasum -a 256 "$PLUGIN_MANIFEST" | awk '{print $1}')"
  PLUGIN_CORE_SHA256="$({
    for relative_path in "${CORE_FILES[@]}"; do
      file_hash="$(shasum -a 256 "$PLUGIN_PROFILE/$relative_path" | awk '{print $1}')"
      printf '%s  %s\n' "$file_hash" "$relative_path"
    done
  } | shasum -a 256 | awk '{print $1}')"
  if [[ -f "$PLUGIN_PROFILE/assets/apple-appdev-workflow-logo.png" ]]; then
    APP_ICON_SOURCE="$PLUGIN_PROFILE/assets/apple-appdev-workflow-logo.png"
  elif [[ -f "$PLUGIN_PROFILE/assets/apple-appdev-workflow-logo-512.png" ]]; then
    APP_ICON_SOURCE="$PLUGIN_PROFILE/assets/apple-appdev-workflow-logo-512.png"
  fi
fi

if [[ -z "$APP_VERSION" ]]; then
  APP_VERSION="${PLUGIN_VERSION:-0.1.0}"
fi
if [[ -z "$OUTPUT_DIR" ]]; then
  OUTPUT_DIR="/tmp/apple-appdev-xcode-headless-installer"
fi
if [[ "$OUTPUT_DIR" == "/" || "$OUTPUT_DIR" == "//" || "$OUTPUT_DIR" == "${HOME:-}" ]]; then
  echo "error: --output-dir must be a dedicated package directory" >&2
  exit 2
fi
PACKAGE_SUFFIX="${PLUGIN_VERSION:-$AGENT_VERSION}"
if [[ -n "$PLUGIN_VERSION" && -n "$AGENT_VERSION" ]]; then
  PACKAGE_SUFFIX="$PLUGIN_VERSION-with-agent-$AGENT_VERSION"
fi
if [[ -z "$OUTPUT_DMG" ]]; then
  OUTPUT_DMG="$OUTPUT_DIR/${BUNDLE_NAME}-${PACKAGE_SUFFIX}.dmg"
fi

APP_PATH="$OUTPUT_DIR/$BUNDLE_NAME.app"
STAGING_DIR="$OUTPUT_DIR/dmg-root"
CONTENTS_DIR="$APP_PATH/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
BUILD_BIN="$OUTPUT_DIR/build/$APP_EXECUTABLE"
ENTITLEMENTS_DIR="$OUTPUT_DIR/entitlements"
AGENT_ENTITLEMENTS="$ENTITLEMENTS_DIR/codex-agent-entitlements.plist"
INSTALLER_ENTITLEMENTS="$ENTITLEMENTS_DIR/installer-entitlements.plist"
PACKAGE_MANIFEST="$OUTPUT_DMG.manifest.json"
NOTARY_RESULT="$OUTPUT_DMG.notary.json"
DMG_MANIFEST_PATH="$(basename "$OUTPUT_DMG")"
NOTARY_MANIFEST_PATH="$(basename "$NOTARY_RESULT")"
PAYLOAD_DIR=""
PLUGIN_PAYLOAD_DIR=""
if [[ -n "$AGENT_RUNTIME" ]]; then
  PAYLOAD_DIR="$RESOURCES_DIR/XcodeAgent/$AGENT_VERSION"
fi
if [[ -n "$PLUGIN_PROFILE" ]]; then
  PLUGIN_PAYLOAD_DIR="$RESOURCES_DIR/XcodePluginProfile/$PLUGIN_NAME/$PLUGIN_VERSION"
fi

echo "Xcode-headless installer package plan"
echo "  repo_root: $REPO_ROOT"
if [[ -n "$PLUGIN_PROFILE" ]]; then
  echo "  plugin_profile: $PLUGIN_PROFILE"
  echo "  plugin_name: $PLUGIN_NAME"
  echo "  plugin_version: $PLUGIN_VERSION"
  echo "  plugin_manifest_sha256: $PLUGIN_MANIFEST_SHA256"
  echo "  plugin_core_sha256: $PLUGIN_CORE_SHA256"
  echo "  plugin_payload_destination: $PLUGIN_PAYLOAD_DIR"
  if [[ -n "$APP_ICON_SOURCE" ]]; then
    echo "  app_icon_source: $APP_ICON_SOURCE"
  fi
fi
if [[ -n "$AGENT_RUNTIME" ]]; then
  echo "  agent_runtime: $AGENT_RUNTIME"
  echo "  runtime_version: $RUNTIME_VERSION"
  echo "  source_runtime_sha256: $SOURCE_RUNTIME_SHA256"
  echo "  agent_version: $AGENT_VERSION"
  echo "  agent_url: $AGENT_URL"
fi
echo "  app: $APP_PATH"
echo "  dmg: $OUTPUT_DMG"
echo "  package_manifest: $PACKAGE_MANIFEST"
echo "  release_mode: $RELEASE_MODE"
echo "  notarize: $NOTARIZE"
if [[ -n "$SIGN_IDENTITY" ]]; then
  echo "  sign_identity: $SIGN_IDENTITY"
fi
if [[ -n "$NOTARY_PROFILE" ]]; then
  echo "  notary_profile: $NOTARY_PROFILE"
fi

if [[ "$DRY_RUN" == "1" ]]; then
  echo "dry-run: swiftc -O -o \"$BUILD_BIN\" \"$TOOL_DIR/Sources/XcodeHeadlessInstaller/main.swift\""
  if [[ -n "$PLUGIN_PROFILE" ]]; then
    echo "dry-run: copy xcode-headless plugin profile into \"$PLUGIN_PAYLOAD_DIR\""
    if [[ -n "$APP_ICON_SOURCE" ]]; then
      echo "dry-run: render branded installer icon into \"$RESOURCES_DIR/$APP_ICON_NAME\""
    fi
    echo "dry-run: validate --install-plugin-profile without changing Xcode home"
  fi
  if [[ -n "$AGENT_RUNTIME" ]]; then
    echo "dry-run: copy runtime payload into \"$PAYLOAD_DIR\""
    echo "dry-run: codesign embedded codex with hardened runtime and allow-jit entitlements"
    echo "dry-run: compute final signed runtime SHA-512 and write Xcode agent Info.plist"
  fi
  echo "dry-run: codesign installer app"
  echo "dry-run: hdiutil create \"$OUTPUT_DMG\""
  echo "dry-run: codesign DMG"
  echo "dry-run: write package manifest \"$PACKAGE_MANIFEST\""
  if [[ "$NOTARIZE" == "1" ]]; then
    echo "dry-run: xcrun notarytool submit \"$OUTPUT_DMG\" --keychain-profile \"$NOTARY_PROFILE\" --wait --timeout \"$NOTARY_TIMEOUT\" --output-format json > \"$NOTARY_RESULT\""
    echo "dry-run: xcrun stapler staple \"$OUTPUT_DMG\""
    echo "dry-run: xcrun stapler validate \"$OUTPUT_DMG\""
    echo "dry-run: spctl --assess --type open --context context:primary-signature --verbose=4 \"$OUTPUT_DMG\""
  fi
  exit 0
fi

mkdir -p "$OUTPUT_DIR"
rm -rf "$APP_PATH" "$STAGING_DIR" "$OUTPUT_DIR/build" "$ENTITLEMENTS_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR" "$ENTITLEMENTS_DIR" "$OUTPUT_DIR/build" "$STAGING_DIR"

swiftc -O -o "$BUILD_BIN" "$TOOL_DIR/Sources/XcodeHeadlessInstaller/main.swift"
cp -p "$BUILD_BIN" "$MACOS_DIR/$APP_EXECUTABLE"
chmod +x "$MACOS_DIR/$APP_EXECUTABLE"

if [[ -n "$PLUGIN_PROFILE" ]]; then
  mkdir -p "$(dirname "$PLUGIN_PAYLOAD_DIR")"
  cp -R -X "$PLUGIN_PROFILE" "$PLUGIN_PAYLOAD_DIR"
  xattr -c -r "$PLUGIN_PAYLOAD_DIR"
fi

if [[ -n "$APP_ICON_SOURCE" ]]; then
  has sips || { echo "error: sips is required to build the installer app icon" >&2; exit 1; }
  has iconutil || { echo "error: iconutil is required to build the installer app icon" >&2; exit 1; }
  APP_ICONSET="$OUTPUT_DIR/app-icon.iconset"
  rm -rf "$APP_ICONSET"
  mkdir -p "$APP_ICONSET"
  sips -z 16 16 "$APP_ICON_SOURCE" --out "$APP_ICONSET/icon_16x16.png" >/dev/null
  sips -z 32 32 "$APP_ICON_SOURCE" --out "$APP_ICONSET/icon_16x16@2x.png" >/dev/null
  sips -z 32 32 "$APP_ICON_SOURCE" --out "$APP_ICONSET/icon_32x32.png" >/dev/null
  sips -z 64 64 "$APP_ICON_SOURCE" --out "$APP_ICONSET/icon_32x32@2x.png" >/dev/null
  sips -z 128 128 "$APP_ICON_SOURCE" --out "$APP_ICONSET/icon_128x128.png" >/dev/null
  sips -z 256 256 "$APP_ICON_SOURCE" --out "$APP_ICONSET/icon_128x128@2x.png" >/dev/null
  sips -z 256 256 "$APP_ICON_SOURCE" --out "$APP_ICONSET/icon_256x256.png" >/dev/null
  sips -z 512 512 "$APP_ICON_SOURCE" --out "$APP_ICONSET/icon_256x256@2x.png" >/dev/null
  sips -z 512 512 "$APP_ICON_SOURCE" --out "$APP_ICONSET/icon_512x512.png" >/dev/null
  sips -z 1024 1024 "$APP_ICON_SOURCE" --out "$APP_ICONSET/icon_512x512@2x.png" >/dev/null
  iconutil -c icns "$APP_ICONSET" -o "$RESOURCES_DIR/$APP_ICON_NAME"
  rm -rf "$APP_ICONSET"
fi

if [[ -n "$AGENT_RUNTIME" ]]; then
  mkdir -p "$PAYLOAD_DIR"
  cp -p "$AGENT_RUNTIME" "$PAYLOAD_DIR/codex"
  chmod +x "$PAYLOAD_DIR/codex"
fi

cat > "$AGENT_ENTITLEMENTS" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>com.apple.security.cs.allow-jit</key>
  <true/>
</dict>
</plist>
EOF

cat > "$INSTALLER_ENTITLEMENTS" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict/>
</plist>
EOF

APP_ICON_PLIST=""
if [[ -n "$APP_ICON_SOURCE" ]]; then
  APP_ICON_PLIST="  <key>CFBundleIconFile</key>
  <string>$(xml_escape "$APP_ICON_NAME")</string>"
fi

cat > "$CONTENTS_DIR/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleDisplayName</key>
  <string>$(xml_escape "$DISPLAY_NAME")</string>
  <key>CFBundleExecutable</key>
  <string>$(xml_escape "$APP_EXECUTABLE")</string>
  <key>CFBundleIdentifier</key>
  <string>$(xml_escape "$BUNDLE_ID")</string>
$APP_ICON_PLIST
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>$(xml_escape "$DISPLAY_NAME")</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>$(xml_escape "$APP_VERSION")</string>
  <key>CFBundleVersion</key>
  <string>$(xml_escape "$APP_BUILD")</string>
  <key>LSMinimumSystemVersion</key>
  <string>$(xml_escape "$MIN_SYSTEM_VERSION")</string>
  <key>NSHumanReadableCopyright</key>
  <string>Copyright 2026 Joshua Kaunert</string>
</dict>
</plist>
EOF

if [[ -n "$AGENT_RUNTIME" ]]; then
  if [[ -n "$SIGN_IDENTITY" ]]; then
    codesign --force --options runtime --timestamp --entitlements "$AGENT_ENTITLEMENTS" --identifier codex --sign "$SIGN_IDENTITY" "$PAYLOAD_DIR/codex"
  else
    codesign --force --sign - "$PAYLOAD_DIR/codex"
  fi

  FINAL_RUNTIME_SHA512="$(shasum -a 512 "$PAYLOAD_DIR/codex" | awk '{print $1}')"
  cat > "$PAYLOAD_DIR/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>checksum</key>
  <string>$(xml_escape "$FINAL_RUNTIME_SHA512")</string>
  <key>name</key>
  <string>codex</string>
  <key>url</key>
  <string>$(xml_escape "$AGENT_URL")</string>
  <key>version</key>
  <string>$(xml_escape "$RUNTIME_VERSION")</string>
</dict>
</plist>
EOF
  RECORDED_CHECKSUM="$(plutil -extract checksum raw -o - "$PAYLOAD_DIR/Info.plist")"
  RECORDED_URL="$(plutil -extract url raw -o - "$PAYLOAD_DIR/Info.plist")"
  [[ "$RECORDED_CHECKSUM" == "$FINAL_RUNTIME_SHA512" ]] || {
    echo "error: generated agent Info.plist checksum does not match final signed runtime SHA-512" >&2
    exit 1
  }
  [[ "$RECORDED_URL" == "$AGENT_URL" ]] || {
    echo "error: generated agent Info.plist URL does not match --agent-url" >&2
    exit 1
  }
fi

if [[ -n "$SIGN_IDENTITY" ]]; then
  codesign --force --options runtime --timestamp --entitlements "$INSTALLER_ENTITLEMENTS" --sign "$SIGN_IDENTITY" "$APP_PATH"
else
  codesign --force --sign - "$APP_PATH"
fi
codesign --verify --deep --strict --verbose=2 "$APP_PATH"

if [[ -n "$PLUGIN_PROFILE" ]]; then
  "$APP_PATH/Contents/MacOS/$APP_EXECUTABLE" \
    --install-plugin-profile \
    --dry-run \
    --plugin-payload-root "$RESOURCES_DIR/XcodePluginProfile" \
    --plugin-name "$PLUGIN_NAME" \
    --plugin-version "$PLUGIN_VERSION"
fi
if [[ -n "$AGENT_RUNTIME" ]]; then
  "$APP_PATH/Contents/MacOS/$APP_EXECUTABLE" \
    --install-agent \
    --dry-run \
    --payload-root "$RESOURCES_DIR/XcodeAgent" \
    --agent-version "$AGENT_VERSION"
fi

rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR"
cp -R "$APP_PATH" "$STAGING_DIR/"
cat > "$STAGING_DIR/README.txt" <<EOF
Apple AppDev Xcode Headless Installer

This DMG contains a signed installer app for explicit Xcode CodingAssistant
host-asset installation. Packaging and notarization did not mutate Xcode home
or activate Xcode's current Codex agent.
EOF
if [[ -n "$PLUGIN_PROFILE" ]]; then
  cat >> "$STAGING_DIR/README.txt" <<EOF

To install the embedded xcode-headless plugin profile:
  1. Quit Xcode.
  2. Double-click $BUNDLE_NAME.app.
  3. Review the confirmation and click Install.

The installer backs up the prior profile and Xcode Codex config, enables the
public plugin identity, and disables conflicting identities without deleting
their caches. The completion dialog shows the exact rollback path.

For terminal automation from this mounted DMG directory:
  ./$BUNDLE_NAME.app/Contents/MacOS/$APP_EXECUTABLE --install-plugin-profile

Restore the complete state from this mounted DMG directory with:
  ./$BUNDLE_NAME.app/Contents/MacOS/$APP_EXECUTABLE --restore-plugin-profile BACKUP_PATH

Embedded plugin: $PLUGIN_NAME $PLUGIN_VERSION
Plugin manifest SHA-256: $PLUGIN_MANIFEST_SHA256
Plugin routing-core SHA-256: $PLUGIN_CORE_SHA256
EOF
fi
if [[ -n "$AGENT_RUNTIME" ]]; then
  cat >> "$STAGING_DIR/README.txt" <<EOF

To install the embedded agent without activation:
  ./$BUNDLE_NAME.app/Contents/MacOS/$APP_EXECUTABLE --install-agent

To install and activate for the current Xcode build:
  ./$BUNDLE_NAME.app/Contents/MacOS/$APP_EXECUTABLE --install-agent --activate-agent

Embedded agent version: $AGENT_VERSION
Runtime version: $RUNTIME_VERSION
Source runtime SHA-256: $SOURCE_RUNTIME_SHA256
Final signed runtime SHA-512: $FINAL_RUNTIME_SHA512
EOF
fi

rm -f "$OUTPUT_DMG" "$PACKAGE_MANIFEST" "$NOTARY_RESULT"
hdiutil create -volname "$VOLUME_NAME" -srcfolder "$STAGING_DIR" -format UDZO -ov "$OUTPUT_DMG"
if [[ -n "$SIGN_IDENTITY" ]]; then
  codesign --force --timestamp --sign "$SIGN_IDENTITY" "$OUTPUT_DMG"
else
  codesign --force --sign - "$OUTPUT_DMG"
fi
codesign --verify --verbose=2 "$OUTPUT_DMG"

NOTARY_SUBMISSION_ID=""
NOTARY_STATUS="not-requested"
NOTARY_RESULT_MANIFEST_PATH=""
if [[ "$NOTARIZE" == "1" ]]; then
  xcrun notarytool submit "$OUTPUT_DMG" \
    --keychain-profile "$NOTARY_PROFILE" \
    --wait \
    --timeout "$NOTARY_TIMEOUT" \
    --output-format json > "$NOTARY_RESULT"
  cat "$NOTARY_RESULT"
  NOTARY_SUBMISSION_ID="$(plutil -extract id raw -o - "$NOTARY_RESULT")"
  NOTARY_STATUS="$(plutil -extract status raw -o - "$NOTARY_RESULT")"
  NOTARY_RESULT_MANIFEST_PATH="$NOTARY_MANIFEST_PATH"
  [[ "$NOTARY_STATUS" == "Accepted" ]] || {
    echo "error: notarization did not return Accepted status: $NOTARY_STATUS" >&2
    exit 1
  }
  xcrun stapler staple "$OUTPUT_DMG"
  xcrun stapler validate "$OUTPUT_DMG"
  spctl --assess --type open --context context:primary-signature --verbose=4 "$OUTPUT_DMG"
fi

APP_SHA256="$(shasum -a 256 "$MACOS_DIR/$APP_EXECUTABLE" | awk '{print $1}')"
DMG_SHA256="$(shasum -a 256 "$OUTPUT_DMG" | awk '{print $1}')"
SIGNING_MODE="ad-hoc"
if [[ -n "$SIGN_IDENTITY" ]]; then
  SIGNING_MODE="developer-id"
fi
cat > "$PACKAGE_MANIFEST" <<EOF
{
  "schema_version": 1,
  "created_at": "$(timestamp)",
  "bundle_id": "$(json_escape "$BUNDLE_ID")",
  "app_version": "$(json_escape "$APP_VERSION")",
  "app_build": "$(json_escape "$APP_BUILD")",
  "signing_mode": "$SIGNING_MODE",
  "notarized": $([[ "$NOTARIZE" == "1" ]] && printf true || printf false),
  "notarization": {
    "status": "$(json_escape "$NOTARY_STATUS")",
    "submission_id": "$(json_escape "$NOTARY_SUBMISSION_ID")",
    "result_path": "$(json_escape "$NOTARY_RESULT_MANIFEST_PATH")"
  },
  "installer_executable_sha256": "$APP_SHA256",
  "dmg_path": "$(json_escape "$DMG_MANIFEST_PATH")",
  "dmg_sha256": "$DMG_SHA256",
  "plugin": {
    "included": $([[ -n "$PLUGIN_PROFILE" ]] && printf true || printf false),
    "name": "$(json_escape "$PLUGIN_NAME")",
    "version": "$(json_escape "$PLUGIN_VERSION")",
    "manifest_sha256": "$PLUGIN_MANIFEST_SHA256",
    "routing_core_sha256": "$PLUGIN_CORE_SHA256"
  },
  "agent": {
    "included": $([[ -n "$AGENT_RUNTIME" ]] && printf true || printf false),
    "version": "$(json_escape "$AGENT_VERSION")",
    "runtime_version": "$(json_escape "$RUNTIME_VERSION")",
    "source_runtime_sha256": "$SOURCE_RUNTIME_SHA256",
    "final_runtime_sha512": "$FINAL_RUNTIME_SHA512"
  }
}
EOF

cat <<EOF
Xcode-headless installer package complete
app: $APP_PATH
dmg: $OUTPUT_DMG
dmg_sha256: $DMG_SHA256
package_manifest: $PACKAGE_MANIFEST
signing_mode: $SIGNING_MODE
notarized: $NOTARIZE
EOF
if [[ -n "$PLUGIN_PROFILE" ]]; then
  cat <<EOF
plugin_name: $PLUGIN_NAME
plugin_version: $PLUGIN_VERSION
plugin_manifest_sha256: $PLUGIN_MANIFEST_SHA256
plugin_core_sha256: $PLUGIN_CORE_SHA256

Plugin-profile install command after mounting the DMG:
  Double-click "$BUNDLE_NAME.app" in the mounted DMG.

Optional terminal automation from the mounted DMG directory:
  "./$BUNDLE_NAME.app/Contents/MacOS/$APP_EXECUTABLE" --install-plugin-profile
EOF
fi
if [[ -n "$AGENT_RUNTIME" ]]; then
  cat <<EOF
agent_version: $AGENT_VERSION
runtime_version: $RUNTIME_VERSION
source_runtime_sha256: $SOURCE_RUNTIME_SHA256
final_runtime_sha512: $FINAL_RUNTIME_SHA512
agent_url: $AGENT_URL

Agent activation command after mounting the DMG:
  "/Volumes/$VOLUME_NAME/$BUNDLE_NAME.app/Contents/MacOS/$APP_EXECUTABLE" --install-agent --activate-agent
EOF
fi
