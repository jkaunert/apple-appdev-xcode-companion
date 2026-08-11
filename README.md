# Apple AppDev Xcode Companion

Public source and release home for the explicit Xcode CodingAssistant
provisioning envelope used by Apple AppDev Workflow.

The Codex Marketplace plugin and this companion are separate distributions.
The Marketplace plugin installs into ordinary Codex Desktop and CLI homes. The
companion installs the matching `xcode-headless` profile into Xcode's separate
CodingAssistant Codex home without changing Xcode's active Codex agent.

## Current status

- public companion release: [`v0.2.0`](https://github.com/jkaunert/apple-appdev-xcode-companion/releases/tag/v0.2.0)
- source imported from private Apple AppDev Workflow commit
  `c30409e917a5bcdb02010c0b78b4971c2b3fa42a`
- embedded dual-hook profile pinned to private Apple AppDev Workflow commit
  `b176905b88ac3b21827f088d8a8c1b5b4c044a23`
- signed, notarized, and published build-4 companion source commit
  `d8f83d1fa0d661aa1c01a1138c0e156bf4929d5d`, qualified on macOS 15.7.8
  and macOS 26.5.1 after exact-DMG transactional installation, a VoiceOver
  installation pass, a fresh Xcode-host smoke, and a 9/9 preserved Xcode host
  matrix rescore
- paired public plugin release: `jkaunert/apple-appdev-workflow` `v0.2.0`
- public plugin release commit:
  `c3702d917fedaa6674a750695d3173e36d714522`
- exact artifact hashes, hook trust state, and stock-host evidence are in
  [release qualification](docs/RELEASE_QUALIFICATION.md)
- the verified tag, asset, and publication record is in the
  [0.2.0 release packet](docs/RELEASE_PACKET_0.2.0.md)
- the public plugin repository remains frozen during the Build Week judging
  window and is not modified by companion development
- the next companion maintenance candidate keeps the public plugin payload at
  `0.2.0` while embedding a pinned, licensed Node.js LTS runtime inside the
  Xcode-only installed profile; Xcode 27/Codex `0.145.0` qualification is in
  progress and does not change the frozen plugin repository

See [source provenance](docs/SOURCE_PROVENANCE.md) for the exact extraction
boundary and [compatibility contract](docs/COMPATIBILITY.md) for the pinned
plugin/profile pairing.

## Package shape

The self-contained maintenance package contains:

- a Developer ID signed installer app
- a rendered and validated `xcode-headless` plugin profile
- a signed Node.js LTS executable and license used only by the two lifecycle
  hooks
- no replacement Codex agent
- no bundled MCP proxy
- no plugin-managed MCP servers

The installer validates the embedded profile, refuses symbolic-link payloads,
backs up the prior profile and Xcode Codex config, enables the public
marketplace identity, disables conflicting identities without deleting their
caches, runs `UserPromptSubmit` and `Stop` under Xcode's sanitized `PATH`
before config activation, presents a native double-click installation flow with
a copyable validated restore path, offers a primary **Review Hooks** action
that opens Xcode's stock Codex review as Terminal's foreground job inside a
dedicated empty onboarding workspace, and leaves
`Agents/XcodeVersions/<build>/codex` unchanged.

Lifecycle-hook trust remains an explicit user decision. The installer does not
pre-trust the embedded `UserPromptSubmit` routing hook or `Stop` contract
guard. The self-contained commands differ from public companion `v0.2.0`, so
both require explicit review after the maintenance install. The installer
launches the stock review surface but never writes `hooks.state`; command and
source approval remains the user's decision. A one-time workspace-trust prompt,
when needed, applies only to that onboarding directory rather than the user's
home or project directories. The exact procedure is documented in the
[installer guide](tools/xcode-headless-installer/README.md#review-and-trust-the-hooks).

## Development

Run the focused installer tests:

```bash
python3 -m unittest scripts.test_xcode_headless_installer
```

Inspect a package plan with a rendered profile:

```bash
tools/xcode-headless-installer/scripts/fetch_hook_runtime.sh \
  --output-dir /tmp/apple-appdev-hook-runtime-v24.19.0

tools/xcode-headless-installer/scripts/package_dmg.sh \
  --plugin-profile /path/to/rendered/xcode-headless \
  --plugin-version 0.2.0 \
  --hook-runtime /tmp/apple-appdev-hook-runtime-v24.19.0/node \
  --hook-runtime-license /tmp/apple-appdev-hook-runtime-v24.19.0/LICENSE \
  --output-dir /tmp/apple-appdev-xcode-companion \
  --dry-run
```

Public packaging requires Developer ID signing, notarization, stapling,
Gatekeeper acceptance, and a fresh live Xcode smoke against the exact final
DMG.
