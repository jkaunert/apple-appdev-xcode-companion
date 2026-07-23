# Release Qualification

## Candidate

The currently qualified private candidate is:

```text
version: 0.2.0
source commit: 56c1751fcaedcb36ba04966900283aadf6378fa3
source dirty: false
DMG: AppleAppDevXcodeHeadlessInstaller-0.2.0.dmg
DMG SHA-256: af5250169a3cf8af2bdb8754b9c44bd662d9e89c1a66ba4aaabe225e1f7509c6
installer executable SHA-256: 3818f804566ee146877c8e419034d065b6a504f154b4121f4e117fc0dac96805
Developer ID: Joshua Kaunert (HSRQC9N69B)
notary submission: 5aae18b3-d9a2-4a26-838b-5206bc7fa8b8
notary status: Accepted
plugin manifest SHA-256: e60578bf493e0d940419f0082c45516cd84e9ea1b0398542dbb81ee01a225585
routing core SHA-256: 9f7a0f4b9d9d5fec5cde9b01a274d5eb7ec7a4cdd147294e66896a1f804536c6
```

Gatekeeper accepted both the DMG and its mounted installer app. Strict code
signature verification and stapler validation passed.

The distribution path is now a normal macOS flow: open the DMG in Finder and
double-click `AppleAppDevXcodeHeadlessInstaller.app`. The app presents native
confirmation, progress, completion, and failure UI. Direct invocation of an
executable inside `Contents/MacOS` is retained only as an automation interface,
not as the primary installation instruction.

## Installer Gates

- 16 focused installer tests passed.
- Swift type-checking and shell syntax checks passed.
- Finder launch displayed the branded native confirmation and completion
  dialogs from the exact signed and notarized DMG.
- Return activated Install and Escape cancelled without mutation.
- The native AppKit accessibility tree exposed the prompt as static text and
  exposed `Install` and `Cancel` as named buttons.
- Exact-package install and restore passed in a disposable Xcode Codex home.
- Restore returned the prior profile and `config.toml` byte-for-byte.
- The default installation activated
  `apple-appdev-workflow@apple-developer-tools`, disabled the conflicting Xcode
  config identity, and left the `LocalAppleWorkflow` cache present.
- The Xcode `Agents` tree was unchanged.
- A native install into the live Xcode CodingAssistant Codex home completed
  successfully. Because that home already held the qualified profile, its
  `config.toml` remained byte-for-byte unchanged.
- The release sidecar binds the artifact to the clean source commit above and
  release packaging refuses a dirty or non-git source tree.

The live rollback snapshot is retained at:

```text
/Users/joshuakaunert/Library/Developer/Xcode/CodingAssistant/codex/.tmp/plugins/quarantine/apple-appdev-workflow/0.2.0-plugin-install-20260723T053252Z
```

## Stock Xcode Gate

The exact replacement DMG was installed into the separate Xcode CodingAssistant
Codex home and evaluated with stock Xcode 27.0 build `27A5209h` and stock
`codex-cli 0.140.0`.

A fresh stock-agent smoke ran without the hook-trust bypass flag and proved the
trusted `UserPromptSubmit` payload appeared after the user message and before
the first assistant message. The response named
`apple-appdev-workflow:apple-app-orchestrator`.

The routing payload hashes are byte-identical to the already qualified public
plugin payload. Its preserved nine-case Xcode matrix was rescored against the
original pinned source commit
`d5ed6961bba3551b8d86e4470e5b80ac09dd6f4f`; all nine cases passed with zero
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

This distinction is intentional: the fresh smoke proves activation from the
exact new DMG, while the immutable matrix proves the unchanged routing payload's
behavioral breadth.

## Distribution Decision

This candidate is **ready only for narrower distribution** from the private
companion repository. It is not yet a public launch.

The current limitations are:

- the public `jkaunert/apple-appdev-workflow` repository remains frozen for the
  Build Week judging window;
- hook trust remains an explicit post-install user action;
- the accessibility tree and keyboard paths passed, but a manual VoiceOver
  gesture walkthrough and older-supported-macOS pass remain pending;
- the strict cross-host automation-isolation audit was inconclusive because the
  active Codex app-server owned multiple XcodeBuildMCP roots. Exact-path
  installer and stock-agent evidence was collected independently and is not
  being presented as cross-host isolation proof; and
- a public companion release and cross-link should be created independently,
  followed by a public-plugin documentation PR after the freeze ends.

The package must not be described as replacing Xcode's Codex agent. It installs
only the validated `xcode-headless` plugin profile and leaves the stock agent
active.
