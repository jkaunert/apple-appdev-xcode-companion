# Apple AppDev Xcode Companion

Private staging source for the explicit Xcode CodingAssistant provisioning
envelope used by Apple AppDev Workflow.

The Codex Marketplace plugin and this companion are separate distributions.
The Marketplace plugin installs into ordinary Codex Desktop and CLI homes. The
companion installs the matching `xcode-headless` profile into Xcode's separate
CodingAssistant Codex home without changing Xcode's active Codex agent.

## Current status

- private staging repository; not a public release surface
- source imported from private Apple AppDev Workflow commit
  `c30409e917a5bcdb02010c0b78b4971c2b3fa42a`
- dual-hook replacement candidate pinned to private Apple AppDev Workflow commit
  `b176905b88ac3b21827f088d8a8c1b5b4c044a23`; it remains unqualified pending
  exact-package signing, trust, and live-host validation
- paired public plugin release: `jkaunert/apple-appdev-workflow` `v0.2.0`
- public plugin release commit:
  `c3702d917fedaa6674a750695d3173e36d714522`
- signed and notarized `0.2.0` candidate qualified against stock Xcode 27.0
  build `27A5209h`; see
  [release qualification](docs/RELEASE_QUALIFICATION.md)
- the public plugin repository remains frozen during the Build Week judging
  window and is not modified by companion development

See [source provenance](docs/SOURCE_PROVENANCE.md) for the exact extraction
boundary and [compatibility contract](docs/COMPATIBILITY.md) for the pinned
plugin/profile pairing.

## Package shape

The profile-only package contains:

- a Developer ID signed installer app
- a rendered and validated `xcode-headless` plugin profile
- no replacement Codex agent
- no bundled MCP proxy
- no plugin-managed MCP servers

The installer validates the embedded profile, refuses symbolic-link payloads,
backs up the prior profile and Xcode Codex config, enables the public
marketplace identity, disables conflicting identities without deleting their
caches, presents a native double-click installation flow with a copyable
validated restore path, and leaves
`Agents/XcodeVersions/<build>/codex` unchanged.

Lifecycle-hook trust remains an explicit user decision. The installer does not
pre-trust the embedded `UserPromptSubmit` routing hook or `Stop` contract
guard. After installation, review and trust both with stock Codex's hook
browser before restarting Xcode; the exact
procedure is documented in the
[installer guide](tools/xcode-headless-installer/README.md#review-and-trust-the-hooks).

## Development

Run the focused installer tests:

```bash
python3 -m unittest scripts.test_xcode_headless_installer
```

Inspect a package plan with a rendered profile:

```bash
tools/xcode-headless-installer/scripts/package_dmg.sh \
  --plugin-profile /path/to/rendered/xcode-headless \
  --plugin-version 0.2.0 \
  --output-dir /tmp/apple-appdev-xcode-companion \
  --dry-run
```

Public packaging requires Developer ID signing, notarization, stapling,
Gatekeeper acceptance, and a fresh live Xcode smoke against the exact final
DMG.
