# Release Qualification

## Candidate

The previously qualified private candidate is:

```text
version: 0.2.0
DMG: AppleAppDevXcodeHeadlessInstaller-0.2.0.dmg
DMG SHA-256: 726c9a20cddd16dc68eabbf9869270ea732b9af18e0b062773be8ef169cdb646
Developer ID: Joshua Kaunert (HSRQC9N69B)
notary submission: c642beb5-7f51-479a-8e92-9373bfc3a411
notary status: Accepted
plugin manifest SHA-256: e60578bf493e0d940419f0082c45516cd84e9ea1b0398542dbb81ee01a225585
routing core SHA-256: 9f7a0f4b9d9d5fec5cde9b01a274d5eb7ec7a4cdd147294e66896a1f804536c6
```

Gatekeeper accepted both the DMG and its mounted installer app. Strict code
signature verification and stapler validation passed.

This artifact is superseded as a distribution candidate because its app
bundle exposed only a command-line interface when double-clicked. The
installer implementation now includes a native confirmation and completion
flow; that changed artifact requires fresh signing, notarization, exact-package
transaction testing, and live Xcode qualification before promotion.

## Installer Gates

- 15 focused installer tests passed.
- Swift type-checking and shell syntax checks passed.
- Exact-package install and restore passed in a disposable Xcode Codex home.
- Restore returned the prior profile and `config.toml` byte-for-byte.
- The default installation activated
  `apple-appdev-workflow@apple-developer-tools`, disabled the conflicting Xcode
  config identity, and left the `LocalAppleWorkflow` cache present.
- The Xcode `Agents` tree was unchanged.

## Stock Xcode Gate

The exact DMG was installed into the separate Xcode CodingAssistant Codex home
and evaluated with stock Xcode 27.0 build `27A5209h` and stock
`codex-cli 0.140.0`.

The fresh-session smoke proved that the plugin's trusted `UserPromptSubmit`
payload appeared after the user message and before the first assistant
message. The full live matrix then passed 9 of 9 cases with zero scorer errors:

1. natural Apple request
2. plugin chip
3. explicit top-level skill chip
4. explicit domain-orchestrator chip
5. explicit focused-specialist chip
6. Xcode host-context routing for a non-Apple authored prompt
7. resumed conversation routing
8. foreign-plugin negative control
9. trusted concurrent-hook composition

The concurrent case executed one neutral context and one Apple route context,
in that order, before the assistant response. The temporary neutral hook was
then removed and the pre-test Xcode config restored byte-for-byte. The final
hook listing contained only the trusted public plugin hook.

## Distribution Decision

The recorded candidate is no longer eligible for distribution. A replacement
may return to narrower-distribution status only after the full installer and
stock Xcode gates above pass against the exact rebuilt DMG. It will still not
be a public launch until:

- the public `jkaunert/apple-appdev-workflow` repository remains frozen for the
  Build Week judging window;
- hook trust remains an explicit post-install user action; and
- a public companion release and cross-link can be created independently,
  followed by a public-plugin documentation PR after the freeze ends.

The package must not be described as replacing Xcode's Codex agent. It installs
only the validated `xcode-headless` profile and leaves the stock agent active.
