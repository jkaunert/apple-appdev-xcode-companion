# Xcode Headless Installer

This tool packages Xcode CodingAssistant host assets as a signed macOS
installer app inside a signed, notarizable DMG. It supports two independent
payloads:

- the rendered `xcode-headless` plugin profile; and
- an optional Codex primary-agent canary.

The public Apple workflow plugin uses the first path. Marketplace installation
configures the ordinary Codex plugin and its MCP servers, but Codex Marketplace
does not own Xcode CodingAssistant's separate Codex home. The Xcode profile is
therefore a companion distribution envelope, not a Marketplace post-install
side effect.

## Package The Plugin Profile

Render and validate the Xcode-specific profile first:

```bash
python3 scripts/render_plugin_manifest_profile.py \
  --repo-root . \
  --output-dir /tmp/apple-appdev-xcode-headless-0.2.0 \
  --profile xcode-headless \
  --validate
```

Inspect the package plan without creating an app or DMG:

```bash
tools/xcode-headless-installer/scripts/package_dmg.sh \
  --plugin-profile /tmp/apple-appdev-xcode-headless-0.2.0 \
  --plugin-version 0.2.0 \
  --output-dir /tmp/apple-appdev-xcode-plugin-installer \
  --dry-run
```

For a public artifact, use a Developer ID Application identity and notarize in
the same package run:

```bash
APPLE_APPDEV_WORKFLOW_CODESIGN_IDENTITY="Developer ID Application: Example Team (TEAMID1234)" \
tools/xcode-headless-installer/scripts/package_dmg.sh \
  --plugin-profile /tmp/apple-appdev-xcode-headless-0.2.0 \
  --plugin-version 0.2.0 \
  --output-dir /tmp/apple-appdev-xcode-plugin-installer \
  --release \
  --notarize \
  --keychain-profile AppleAppsBrigade
```

`--notarize` is rejected unless `--release` is present. A successful package
run emits a sidecar JSON manifest with the final DMG SHA-256, installer-binary
SHA-256, signing mode, notarization status, plugin manifest hash, and routing
core hash. A notarized run also keeps notarytool's JSON result beside the DMG
and records its accepted submission ID in the sidecar manifest.

## Install Or Roll Back The Plugin Profile

After the DMG passes Gatekeeper, run the embedded installer explicitly:

```bash
/Volumes/Apple\ AppDev\ Xcode\ Headless\ Installer/AppleAppDevXcodeHeadlessInstaller.app/Contents/MacOS/xcode-headless-installer \
  --install-plugin-profile
```

The install target is:

```text
~/Library/Developer/Xcode/CodingAssistant/codex/plugins/cache/LocalAppleWorkflow/apple-appdev-workflow/<version>
```

If that same version already exists, the installer moves it to Xcode Codex
home's `.tmp/plugins/quarantine/apple-appdev-workflow/` directory before
copying the new profile. It prints the exact rollback path. Restore it with:

```bash
/Volumes/Apple\ AppDev\ Xcode\ Headless\ Installer/AppleAppDevXcodeHeadlessInstaller.app/Contents/MacOS/xcode-headless-installer \
  --restore-plugin-profile /absolute/path/printed/by/install
```

Restore accepts only a validated plugin backup inside that quarantine root. It
preserves the profile being replaced as a second rollback backup. Both install
and restore strip copied extended attributes and validate the final manifest,
hook, neutral policy, and owner-kernel shape.

Plugin-profile operations never write under Xcode's `Agents` directory and
never change `Agents/XcodeVersions/<build>/codex`.

## Optional Primary-Agent Canary

The historical primary-agent mode remains available for isolated canaries:

```bash
tools/xcode-headless-installer/scripts/package_dmg.sh \
  --agent-runtime /path/to/codex \
  --agent-version 0.145.0-alpha.18-fork-xcode-canary \
  --agent-url local-fork-runtime://0.145.0-alpha.18-fork-xcode-canary/codex \
  --output-dir /tmp/apple-appdev-xcode-agent-installer \
  --dry-run
```

Packaging never activates that agent. After an accepted DMG is mounted,
`--install-agent` copies it and `--activate-agent` is still required to change
the active Xcode-build symlink. Activation preserves the prior symlink as a
rollback link.

Xcode validates agent metadata as well as the executable. The packager signs
the embedded runtime first, computes its final SHA-512, writes `Info.plist`,
and only then signs the installer app.

## Gate Boundaries

- A locally ad-hoc-signed DMG proves package shape only. It is not publicly
  distributable.
- Public Xcode distribution requires Developer ID signing, notarization,
  stapling, and Gatekeeper acceptance of the exact final DMG.
- The 9/9 live Xcode hook matrix is host-compatibility evidence. It is not
  Desktop, Marketplace, or public Marketplace release evidence.
- Installing the profile does not prove a restarted Xcode host loaded it. Run a
  fresh Xcode CodingAssistant smoke after install before claiming that exact
  package is host-validated.
- The `xcode-headless` manifest must omit plugin-managed `mcpServers` and retired
  `routerSelection`; Xcode owns the native tool surface while the hook retains
  deterministic workflow ownership.
