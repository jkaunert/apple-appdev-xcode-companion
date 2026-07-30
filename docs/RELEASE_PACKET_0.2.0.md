# Apple AppDev Xcode Companion 0.2.0 Release Packet

Status: prepared, not published.

## Proposed Release

```text
repository: jkaunert/apple-appdev-xcode-companion
tag: v0.2.0
title: Apple AppDev Xcode Companion 0.2.0
source commit: 7b236ef06b8d6e7f8453a66d23cd8bc0055a155a
app version: 0.2.0
app build: 3
```

The current GitHub repository is private. Do not publish the tag or release,
or change repository visibility, until the remaining release decision is made
explicitly.

## Release Assets

Upload these three files from:

```text
/Users/joshuakaunert/Developer/apple-appdev-xcode-companion/build/releases/dual-hook-copy-fix-b176905-7b236ef/
```

```text
AppleAppDevXcodeHeadlessInstaller-0.2.0.dmg
AppleAppDevXcodeHeadlessInstaller-0.2.0.dmg.manifest.json
AppleAppDevXcodeHeadlessInstaller-0.2.0.dmg.notary.json
```

Artifact identity:

```text
DMG SHA-256: 7e29121fd151e27d727911ee77012b0ff0e854b9eef1a923307714069c9549dd
installer executable SHA-256: 9aa24ca130dde17bef1440925462708c92c14570db3462d6e8f5e9bb4050c2f7
notary submission: 613937d6-6c4c-4176-a071-67e0a6e8ffe9
notary status: Accepted
plugin manifest SHA-256: 0b52bbc68aa8d534124d66b8f3ea5c7307bd020d103ababa5e74b0de2e5c5f9d
routing core SHA-256: 565f1089fadaa4594a8d97f473610a3783a0f5e3c99f35c9123c02facf5e4257
```

## Draft Release Body

Apple AppDev Xcode Companion installs the `xcode-headless` profile for Apple
AppDev Workflow into Xcode CodingAssistant's separate Codex home. It does not
replace Xcode's Codex agent and does not pre-trust either lifecycle hook.

This release includes:

- a native double-click installation flow;
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
7e29121fd151e27d727911ee77012b0ff0e854b9eef1a923307714069c9549dd
```

## Qualification Summary

- 17/17 installer tests passed.
- Swift type-checking and package-script syntax passed.
- The build came from a clean companion commit.
- The DMG and app passed code-signature verification.
- Apple notarization was accepted and the ticket was stapled.
- Gatekeeper accepted the final DMG.
- The exact DMG completed the native Finder install flow.
- VoiceOver reached and announced the alert, informative text, Cancel,
  Install, Copy Rollback Path, and Done controls.
- Both native dialogs explicitly named `UserPromptSubmit` and `Stop`.
- The embedded profile was byte-identical to the installed profile.
- The preserved Xcode host matrix rescored 9/9 with zero errors.

The detailed record is
[`docs/RELEASE_QUALIFICATION.md`](RELEASE_QUALIFICATION.md).

## Remaining Go/No-Go Decision

The candidate remains **ready only for narrower distribution** until:

- a fresh Xcode-host conversation is run against the exact build-3 install, or
  the release decision explicitly accepts the identical-payload 9/9 rescore as
  sufficient for this installer-copy-only rebuild; and
- the older-supported-macOS validation requirement is completed or explicitly
  removed from the public support claim.

The public `jkaunert/apple-appdev-workflow` repository remains frozen through
the Build Week judging window. Publishing this companion must not modify,
retag, or push to that repository.
