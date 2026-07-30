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
  `b176905b88ac3b21827f088d8a8c1b5b4c044a23`
- signed and notarized build-3 companion source commit
  `7b236ef06b8d6e7f8453a66d23cd8bc0055a155a`, qualified for narrower
  distribution after exact-DMG Finder installation, a VoiceOver gesture
  walkthrough, and a 9/9 preserved Xcode host matrix rescore
- paired public plugin release: `jkaunert/apple-appdev-workflow` `v0.2.0`
- public plugin release commit:
  `c3702d917fedaa6674a750695d3173e36d714522`
- exact artifact hashes, hook trust state, and stock-host evidence are in
  [release qualification](docs/RELEASE_QUALIFICATION.md)
- the independent tag, asset, and release-body handoff is in the
  [0.2.0 release packet](docs/RELEASE_PACKET_0.2.0.md)
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
guard. On a clean Xcode Codex home, review and trust both. On an upgraded home,
the unchanged `UserPromptSubmit` command may retain its prior trust while the
new `Stop` command still requires review. The exact procedure is documented in
the [installer guide](tools/xcode-headless-installer/README.md#review-and-trust-the-hooks).

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
