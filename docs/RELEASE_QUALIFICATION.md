# Release Qualification

## Candidate

The published dual-hook release is:

```text
version: 0.2.0
app build: 4
minimum macOS: 15.0
companion source commit: d8f83d1fa0d661aa1c01a1138c0e156bf4929d5d
companion source dirty at package time: false
plugin source commit: b176905b88ac3b21827f088d8a8c1b5b4c044a23
DMG: AppleAppDevXcodeHeadlessInstaller-0.2.0.dmg
DMG SHA-256: d604a00bbc2a930326d7fe3f4c30fea0725da1b370c1f8bb07791793539a130a
installer executable SHA-256: 928ba2019f642a56d8fef7ff586e8eeffa56cfbd22898aaab3cda21ddb1e66de
Developer ID: Joshua Kaunert (HSRQC9N69B)
notary submission: 7cb7664a-2bd5-427a-aacb-5754e9f94511
notary status: Accepted
plugin manifest SHA-256: 0b52bbc68aa8d534124d66b8f3ea5c7307bd020d103ababa5e74b0de2e5c5f9d
routing core SHA-256: 565f1089fadaa4594a8d97f473610a3783a0f5e3c99f35c9123c02facf5e4257
```

Gatekeeper accepted both the DMG and its mounted installer app as notarized
Developer ID software. Strict deep code-signature verification, DMG stapler
validation, and mounted-app verification passed.

The package contains a physical, symlink-free `xcode-headless` profile and no
replacement Codex agent, bundled MCP proxy, plugin-managed MCP server, or
retired `routerSelection`.

## Superseded Build 3

Build 3 from companion commit
`7b236ef06b8d6e7f8453a66d23cd8bc0055a155a` passed its host UI, signing,
notarization, and routing checks, but failed the macOS 15 compatibility gate.
Its executable declared `LSMinimumSystemVersion` 15.0 without compiling Swift
for that deployment target. On macOS 15.7.8, `dyld` rejected the binary because
it was built for macOS 26.0 and referenced
`/usr/lib/swift/libswift_DarwinFoundation2.dylib`.

Commit `d8f83d1fa0d661aa1c01a1138c0e156bf4929d5d` makes
`--min-system` control both `LSMinimumSystemVersion` and Swift's compile
target. Build 4 was compiled with:

```text
-target arm64-apple-macosx15.0
```

Its Mach-O `LC_BUILD_VERSION` reports `minos 15.0`, and its load commands do
not reference `libswift_DarwinFoundation2.dylib`. Build 3 must not be
published.

## Installer Gates

- All 17 focused installer tests passed.
- Swift type-checking and shell syntax checks passed.
- The mounted embedded profile was byte-identical to the clean render from the
  pinned plugin source commit and passed bundle validation.
- Exact-package dry-run and native Finder install completed from the mounted
  notarized build-4 DMG.
- The installed profile matched the embedded payload byte-for-byte.
- Installation activated
  `apple-appdev-workflow@apple-developer-tools`, disabled the conflicting
  identity in the Xcode home, and left the `LocalAppleWorkflow` cache intact.
- Both previously reviewed hook trust hashes remained present after the
  build-4 replacement.
- The active stock Xcode Codex agent remained the signed `codex-cli 0.140.0`
  binary selected by Xcode build `27A5209h`, with SHA-256
  `ffcb8ff096c48bb124a66006346cfbbd65fb8d67d4424e51a4f7ace4322fb03c`.
- Release packaging bound the artifact to a clean companion commit and would
  have rejected a dirty or non-git source tree.

The exact host-install rollback snapshot is:

```text
/Users/joshuakaunert/Library/Developer/Xcode/CodingAssistant/codex/.tmp/plugins/quarantine/apple-appdev-workflow/0.2.0-plugin-install-20260731T004634Z
```

## macOS 15 Gate

Build 4 was validated in the retained Tart VM
`apple-appdev-xcode-companion-0-2-0-macos15-qual-20260730`:

```text
macOS version: 15.7.8
macOS build: 24G824
architecture: arm64
DMG SHA-256: d604a00bbc2a930326d7fe3f4c30fea0725da1b370c1f8bb07791793539a130a
installer executable SHA-256: 928ba2019f642a56d8fef7ff586e8eeffa56cfbd22898aaab3cda21ddb1e66de
```

The exact notarized DMG passed stapler and Gatekeeper checks in the VM. Its
mounted app passed strict code-signature and Gatekeeper verification. The
packaged executable ran `--help` and
`--install-plugin-profile --dry-run`, then completed a real transactional
profile install.

The VM's installed profile was byte-identical to the DMG's embedded profile,
the intended plugin identity was enabled, and the rollback snapshot was:

```text
/Users/admin/Library/Developer/Xcode/CodingAssistant/codex/.tmp/plugins/quarantine/apple-appdev-workflow/0.2.0-plugin-install-20260731T004508Z
```

The VM clone was shut down cleanly and retained for reproducibility.

## Native Finder And VoiceOver Gate

The exact build-4 DMG was mounted after its executable hash was matched to the
sidecar manifest. Xcode was closed for the complete install transaction.

The confirmation alert disclosed that the installer:

```text
does not replace Xcode's Codex agent or pre-trust either lifecycle hook:
UserPromptSubmit or Stop.
```

VoiceOver was enabled before `Install` was activated. The completion alert
reported that Apple AppDev Workflow was enabled, repeated the explicit
post-install trust requirement for both hooks, and displayed the rollback
path. `Done` was activated, the installer exited, and VoiceOver was restored
to off.

Selected build-4 screenshot hashes:

```text
confirmation before VoiceOver: c8621499f0ec49bef41aba4a74060ada3e3da41556d827b354702962bd2204a6
confirmation with VoiceOver: a4a0ab165f703cfc4de13a66e30aa6630bd359995b0f1399686b962e2b79ec5a
completion: 0212beb4529d74aa00db70e12a30bc03d6d04b2bd53959d43db911b06785d021
VoiceOver restored off: 86ee338cbadbfb36ba6a8b0e017477e6fffc5353b1b2d96863d84f443e40bd26
```

The full VoiceOver control-traversal evidence from build 3 remains applicable
because build 4 changed only the package script's Swift deployment target and
its regression test. The installer UI source and embedded plugin payload are
unchanged.

## Hook Trust

The installer did not pre-trust either hook. Stock Codex's hook browser showed
both hooks active after explicit review:

```text
UserPromptSubmit command: node "$PLUGIN_ROOT/hooks/apple_router.mjs"
UserPromptSubmit trust hash: sha256:1c82a273ee2e6d13245f8ade4bff516ecb8d46b623c96c22e4e572a8edb87711

Stop command: node "$PLUGIN_ROOT/hooks/apple_contract_guard.mjs"
Stop trust hash: sha256:0ed272c8c1d1eb54f0342f83d3cb690a70448b72397b3fd1c53ffd191cc6bc78
```

The trust hashes were retained across the build-4 replacement because the
embedded hook definitions are byte-identical. A clean home still requires
explicit review of both.

## Stock Xcode Gate

The routing payload embedded in build 4 is byte-identical to the payload
evaluated with Xcode 27.0 build `27A5209h` and stock `codex-cli 0.140.0`.

### Exact-home correction smoke

The previously recorded non-interactive stock-agent session
`019fb1db-47fb-75b0-a834-0a2e5b747d2e` proves the complete top-level
correction path for the same immutable routing payload:

1. `UserPromptSubmit` injected
   `apple-appdev-workflow:apple-app-orchestrator`.
2. The model emitted the intentionally requested malformed answer `Done`.
3. `Stop` blocked it once.
4. The corrected final answer began with `Routing: orchestrator-led` and
   contained a fully qualified `Activated skills` block.
5. The guard did not loop.

### Fresh build-4 Xcode-host smoke

A fresh Codex agent conversation was created inside Xcode after the exact
build-4 install:

```text
marker: XCODE-BUILD4-NATURAL-RELEASE-SMOKE-20260730-1949
Xcode conversation: 8CE2A9C1-6E66-4EFD-A7DE-31400D5240BF
Xcode conversation SHA-256: 02340ea92eee3949b17c26981189937c218a5f11c54e9c9b756f98709d47e63c
Codex session: 019fb5a6-85a8-7bd1-9c96-98738df510e7
Codex session SHA-256: 6300453d301e4ee6123e1f02b2798988e5e00b92c8c431f63e20f8f8c6da7d78
app-server PID: 90572
app-server parent Xcode PID: 77992
```

`UserPromptSubmit` injected
`apple-appdev-workflow:apple-app-orchestrator` before model planning. The
natural broad ship-readiness prompt activated the release brigade. The first
draft had the correct skills but did not begin directly with the required
route block, so `Stop` corrected it once. The final answer began with
`Routing: orchestrator-led` and preserved these fully qualified skills:

```text
apple-appdev-workflow:apple-app-orchestrator
apple-appdev-workflow:apple-release-orchestrator
apple-appdev-workflow:apple-testing-quality-gates
apple-appdev-workflow:apple-review-hardening
apple-appdev-workflow:apple-manual-validation
apple-appdev-workflow:apple-build-release-ops
```

The session ended with `task_complete`; the guard did not loop.

### Preserved matrix

The immutable nine-case Xcode host matrix was rescored against the identical
`apple-developer-tools/0.2.0` routing payload. All nine cases passed with zero
scorer errors:

1. natural Apple request
2. plugin chip
3. explicit top-level skill chip
4. explicit domain-orchestrator chip
5. explicit focused-specialist chip
6. Xcode host-context routing for a non-Apple authored prompt
7. resumed conversation routing
8. foreign-plugin negative control
9. trusted concurrent-hook composition

The regenerated report has SHA-256
`a78a999e0a8f9a5aeb4ae9902d31f8965daf9f4d54ae466b8aa7c13c6435aa90`.
This matrix is carried forward by exact embedded-profile hash identity; build 4
changed only the installer executable's deployment target.

## Distribution Decision

The build-4 release is technically qualified for its declared macOS 15+
support boundary. The canonical release outcome is **ready to ship** within
the documented Xcode host boundary.

Publication was independently verified on 2026-08-03:

```text
repository visibility: public
tag: v0.2.0
annotated tag object: 6dedd63c94b6de6384860a73c29d882b3691f97d
tag target: d8f83d1fa0d661aa1c01a1138c0e156bf4929d5d
release: https://github.com/jkaunert/apple-appdev-xcode-companion/releases/tag/v0.2.0
published at: 2026-08-03T19:49:40Z
draft: false
prerelease: false
downloaded asset identity: pass (3/3 byte-identical)
```

The remaining limitations are:

- the public `jkaunert/apple-appdev-workflow` repository remains frozen for the
  Build Week judging window;
- hook trust remains an explicit post-install user action.

The package must not be described as replacing Xcode's Codex agent. It installs
only the validated `xcode-headless` plugin profile and leaves the stock agent
active.
