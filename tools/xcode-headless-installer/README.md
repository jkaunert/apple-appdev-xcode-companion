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

Materialize the pinned official Node.js LTS runtime used only by the two
plugin hooks. This does not install Node globally or change `PATH`:

```bash
tools/xcode-headless-installer/scripts/fetch_hook_runtime.sh \
  --output-dir /tmp/apple-appdev-hook-runtime-v24.19.0
```

The fetcher pins the Node version, official archive URL, architecture-specific
archive SHA-256, extracted executable SHA-256, and license SHA-256 in
`provenance.json`. The packager rejects symlinks and runtimes with non-system
dynamic-library dependencies.

Inspect the package plan without creating an app or DMG:

```bash
tools/xcode-headless-installer/scripts/package_dmg.sh \
  --plugin-profile /tmp/apple-appdev-xcode-headless-0.2.0 \
  --plugin-version 0.2.0 \
  --version 0.2.1 \
  --hook-runtime /tmp/apple-appdev-hook-runtime-v24.19.0/node \
  --hook-runtime-license /tmp/apple-appdev-hook-runtime-v24.19.0/LICENSE \
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
  --version 0.2.1 \
  --hook-runtime /tmp/apple-appdev-hook-runtime-v24.19.0/node \
  --hook-runtime-license /tmp/apple-appdev-hook-runtime-v24.19.0/LICENSE \
  --output-dir /tmp/apple-appdev-xcode-plugin-installer \
  --release \
  --notarize \
  --keychain-profile AppleAppsBrigade
```

`--version` is the companion app and DMG version; `--plugin-version` remains
the embedded workflow version. `--notarize` is rejected unless `--release` is
present. A successful package run emits a sidecar JSON manifest with the final
DMG SHA-256, installer-binary
SHA-256, exact source commit, clean/dirty state, signing mode, notarization
status, plugin manifest hash, source and embedded routing-core hashes, and
source/final hook-runtime hashes. Developer ID release
packaging refuses a dirty or non-git source checkout. A notarized run also
keeps notarytool's JSON result beside the DMG and records its accepted
submission ID in the sidecar manifest.

## Install Or Roll Back The Plugin Profile

Open the DMG and quit Xcode. Then double-click
`AppleAppDevXcodeHeadlessInstaller.app`, review the native confirmation, and
click **Install**. Before the plugin is enabled, the installer runs both
`UserPromptSubmit` and `Stop` through the packaged runtime with
`PATH=/usr/bin:/bin:/usr/sbin:/sbin`. A failed postflight triggers the existing
transactional profile-and-config rollback. The completion dialog confirms that
both postflights passed, Xcode's active Codex agent was not changed, and a
copyable rollback path is available.

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
shape. New self-contained packages additionally require an executable
`hooks/runtime/node`, its distributed `LICENSE`, and the exact two packaged
runtime commands.

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
Choose **Review Hooks**, inspect the command and source path, and trust each
new or changed hook from `apple-appdev-workflow@apple-developer-tools`.
`UserPromptSubmit` injects the deterministic top-level owner; `Stop` validates
the top-level owner's final output contract and can request one correction
pass without looping. If the startup review has already been dismissed, enter
`/hooks` to open the same browser. Do not approve a different command, source
identity, or hash without reviewing the changed package. Quit the TUI after
approval, start Xcode, create a fresh Codex conversation, and confirm the first broad
Apple-development prompt produces the expected orchestrator-led route. The
`Stop` guard intentionally applies only when
`apple-appdev-workflow:apple-app-orchestrator` is the selected owner; focused
explicit specialists retain their own output contracts.

The historical public `0.2.0` DMG used bare `node` commands and the trust
hashes recorded below:

```text
UserPromptSubmit: node "$PLUGIN_ROOT/hooks/apple_router.mjs"
sha256:1c82a273ee2e6d13245f8ade4bff516ecb8d46b623c96c22e4e572a8edb87711

Stop: node "$PLUGIN_ROOT/hooks/apple_contract_guard.mjs"
sha256:0ed272c8c1d1eb54f0342f83d3cb690a70448b72397b3fd1c53ffd191cc6bc78
```

Self-contained maintenance packages deliberately replace those definitions:

```text
UserPromptSubmit: "$PLUGIN_ROOT/hooks/runtime/node" "$PLUGIN_ROOT/hooks/apple_router.mjs"
Stop: "$PLUGIN_ROOT/hooks/runtime/node" "$PLUGIN_ROOT/hooks/apple_contract_guard.mjs"
```

Both will therefore require explicit review again. Record the final trust
hashes from the exact signed/notarized candidate; do not carry the historical
hashes forward.

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
- For Xcode 27 with Codex CLI `0.145.0` or newer, qualification contract v2
  expects the neutral authored host-context case to route by the exact
  `workspace-extension:xcworkspace` reason. The top-level owner and injection
  checks remain exact; the older contract that expected Xcode project prose in
  the hook prompt remains available only for historical hosts.
