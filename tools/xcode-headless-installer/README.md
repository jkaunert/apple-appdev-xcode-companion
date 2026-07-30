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
SHA-256, exact source commit, clean/dirty state, signing mode, notarization
status, plugin manifest hash, and routing core hash. Developer ID release
packaging refuses a dirty or non-git source checkout. A notarized run also
keeps notarytool's JSON result beside the DMG and records its accepted
submission ID in the sidecar manifest.

## Install Or Roll Back The Plugin Profile

Open the DMG and quit Xcode. Then double-click
`AppleAppDevXcodeHeadlessInstaller.app`, review the native confirmation, and
click **Install**. The completion dialog confirms that Xcode's active Codex
agent was not changed and provides a copyable rollback path.

For terminal automation, change into the mounted DMG directory and invoke the
same signed app executable explicitly:

```bash
cd "/Volumes/Apple AppDev Xcode Headless Installer"
./AppleAppDevXcodeHeadlessInstaller.app/Contents/MacOS/xcode-headless-installer \
  --install-plugin-profile
```

The volume can receive a numeric suffix if another copy is already mounted.
Finder double-click installation does not depend on the mounted volume name.

The install target is:

```text
~/Library/Developer/Xcode/CodingAssistant/codex/plugins/cache/apple-developer-tools/apple-appdev-workflow/<version>
```

The installer creates a transaction backup under Xcode Codex home's
`.tmp/plugins/quarantine/apple-appdev-workflow/` directory before copying the
new profile. The transaction includes the prior profile when present and the
prior `config.toml` state. It enables
`apple-appdev-workflow@apple-developer-tools` and disables conflicting
identities in that Xcode home without deleting their caches. It prints the
exact rollback path. Restore the complete profile-and-config state with:

```bash
cd "/Volumes/Apple AppDev Xcode Headless Installer"
./AppleAppDevXcodeHeadlessInstaller.app/Contents/MacOS/xcode-headless-installer \
  --restore-plugin-profile /absolute/path/printed/by/install
```

Restore accepts only a validated transaction backup inside that quarantine
root. It preserves the profile and config being replaced as a second rollback
backup. Both install and restore strip copied extended attributes and validate
the final manifest, both lifecycle hooks, neutral policy, and owner-kernel
shape.

Plugin-profile operations never write under Xcode's `Agents` directory and
never change `Agents/XcodeVersions/<build>/codex`.

## Review And Trust The Hooks

The installer enables the plugin profile but deliberately does not pre-trust
its lifecycle hooks. Trust is a separate, explicit user action because hook
commands run outside the Codex sandbox.

With Xcode still closed, launch the stock Codex TUI from the Xcode
CodingAssistant home:

```bash
XCODE_BUILD="$(xcodebuild -version | awk '/Build version/{print $3}')"
XCODE_CODEX_HOME="$HOME/Library/Developer/Xcode/CodingAssistant/codex"
CODEX_HOME="$XCODE_CODEX_HOME" \
  "$HOME/Library/Developer/Xcode/CodingAssistant/Agents/XcodeVersions/$XCODE_BUILD/codex/codex"
```

Stock Codex opens its startup hook review when a definition needs approval.
Choose **Review Hooks**, inspect the command and source path, and trust the
`UserPromptSubmit` and `Stop` hooks from
`apple-appdev-workflow@apple-developer-tools`. `UserPromptSubmit` injects the
deterministic top-level owner; `Stop` validates the final output contract and
can request one correction pass without looping. If the startup review has
already been dismissed, enter `/hooks` to open the same browser. For version
`0.2.0`, the previously qualified routing definition was:

```text
command: node "$PLUGIN_ROOT/hooks/apple_router.mjs"
hash: sha256:1c82a273ee2e6d13245f8ade4bff516ecb8d46b623c96c22e4e572a8edb87711
```

The dual-hook repair changes the hook definition and therefore requires fresh
trust hashes from the exact replacement DMG. Do not reuse the historical hash
for that package. Record both hashes during exact-candidate qualification, and
do not approve a different command, source identity, or hash without reviewing
the changed package. Quit the TUI after approval, start Xcode, create a fresh
Codex conversation, and confirm the first Apple-development prompt produces
the expected orchestrator-led route and a malformed final answer receives at
most one correction pass.

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
- Hook discovery does not imply hook trust. Complete the explicit stock Codex
  review for both lifecycle hooks before the live Xcode smoke.
- The `xcode-headless` manifest must omit plugin-managed `mcpServers` and retired
  `routerSelection`; Xcode owns the native tool surface while the hook retains
  deterministic workflow ownership.
