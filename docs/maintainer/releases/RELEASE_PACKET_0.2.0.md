# Apple AppDev Xcode Companion 0.2.0 Release Packet

Status: published and independently verified.

## Published Release

```text
repository: jkaunert/apple-appdev-xcode-companion
tag: v0.2.0
title: Apple AppDev Xcode Companion 0.2.0
source commit: d8f83d1fa0d661aa1c01a1138c0e156bf4929d5d
app version: 0.2.0
app build: 4
minimum macOS: 15.0
published at: 2026-08-03T19:49:40Z
release: https://github.com/jkaunert/apple-appdev-xcode-companion/releases/tag/v0.2.0
```

The public annotated tag dereferences to the exact build source commit above.
The release is neither a draft nor a prerelease.

## Release Assets

The published release contains these three files from the qualified build
directory:

```text
<private-local-path>shuakaunert/Developer/apple-appdev-xcode-companion/build/releases/macos15-deployment-fix-b176905-d8f83d1/
```

```text
AppleAppDevXcodeHeadlessInstaller-0.2.0.dmg
AppleAppDevXcodeHeadlessInstaller-0.2.0.dmg.manifest.json
AppleAppDevXcodeHeadlessInstaller-0.2.0.dmg.notary.json
```

Artifact identity:

```text
DMG SHA-256: d604a00bbc2a930326d7fe3f4c30fea0725da1b370c1f8bb07791793539a130a
installer executable SHA-256: 928ba2019f642a56d8fef7ff586e8eeffa56cfbd22898aaab3cda21ddb1e66de
notary submission: 7cb7664a-2bd5-427a-aacb-5754e9f94511
notary status: Accepted
plugin manifest SHA-256: 0b52bbc68aa8d534124d66b8f3ea5c7307bd020d103ababa5e74b0de2e5c5f9d
routing core SHA-256: 565f1089fadaa4594a8d97f473610a3783a0f5e3c99f35c9123c02facf5e4257
```

Build 3 must not be uploaded. It passed the host gates but failed to launch on
macOS 15 because the executable was compiled for macOS 26.

## Draft Release Body

Apple AppDev Xcode Companion installs the `xcode-headless` profile for Apple
AppDev Workflow into Xcode CodingAssistant's separate Codex home. It does not
replace Xcode's Codex agent and does not pre-trust either lifecycle hook.

This release includes:

- a native double-click installation flow for macOS 15 and later;
- transactional backup and rollback support;
- the deterministic `UserPromptSubmit` owner router;
- the top-level-only `Stop` output-contract guard;
- explicit post-install trust guidance for both hooks; and
- Developer ID signing, notarization, stapling, and Gatekeeper acceptance.

Quit Xcode, open the DMG, and double-click the installer. After installation,
use stock Codex in Xcode's CodingAssistant home to review and trust each new or
changed hook before reopening Xcode. Clean homes require review of both
`UserPromptSubmit` and `Stop`; upgraded homes may retain the unchanged
`UserPromptSubmit` trust.

The installer leaves `Agents/XcodeVersions/<build>/codex` unchanged. Its
completion dialog displays a rollback path for restoring the previous plugin
profile and configuration.

SHA-256:

```text
d604a00bbc2a930326d7fe3f4c30fea0725da1b370c1f8bb07791793539a130a
```

## Qualification Summary

- 17/17 installer tests passed.
- Swift type-checking and package-script syntax passed.
- The build came from clean companion commit `d8f83d1`.
- The DMG and app passed code-signature verification.
- Apple notarization was accepted and the ticket was stapled.
- Gatekeeper accepted the final DMG and mounted app.
- The executable declares Mach-O `minos 15.0` and no longer links the
  macOS-26-only `libswift_DarwinFoundation2.dylib`.
- The exact DMG launched and completed a transactional install on macOS
  15.7.8 build `24G824`.
- The exact DMG completed the native Finder install flow on macOS 26.5.1.
- VoiceOver was enabled before the build-4 `Install` action and restored to off
  after completion.
- Both native dialogs explicitly named `UserPromptSubmit` and `Stop`.
- The embedded profile was byte-identical to both installed profiles.
- A fresh post-install Xcode session proved top-level injection and
  release-contract correction.
- The preserved Xcode host matrix rescored 9/9 with zero errors against the
  identical routing payload.

The detailed record is
[`docs/RELEASE_QUALIFICATION.md`](RELEASE_QUALIFICATION.md).

## Publication Record

All declared technical qualification gates are complete. The public release
outcome is **ready to ship** within the documented macOS 15+ and Xcode host
boundary.

Publication completed on 2026-08-03:

1. `jkaunert/apple-appdev-xcode-companion` is public;
2. annotated tag `v0.2.0` dereferences to exact build source commit
   `d8f83d1fa0d661aa1c01a1138c0e156bf4929d5d`;
3. the GitHub release is published, non-draft, and non-prerelease; and
4. fresh downloads of all three assets are byte-identical to the qualified
   local files and match the SHA-256 values above.

The public `jkaunert/apple-appdev-workflow` repository remains frozen through
the Build Week judging window. Publishing this companion must not modify,
retag, or push to that repository.
