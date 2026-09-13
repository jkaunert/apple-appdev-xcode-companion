# Apple AppDev Xcode Companion

The Apple AppDev Xcode Companion installs the optional Apple AppDev Workflow
profile into Xcode CodingAssistant's separate Codex home. It gives Xcode the
same deterministic hook routing as the Marketplace plugin without replacing
Xcode's Codex agent or native `xcode-tools` integration.

## Current release

The current stable release is [`v0.2.2`](https://github.com/jkaunert/apple-appdev-xcode-companion/releases/tag/v0.2.2), app build `3`.

The release is qualified on both supported host pairs:

- Xcode 27.0 RC (`27A266a`) with its signed Codex `0.145.0` agent
- Xcode 26.6 (`17F113`) with its signed Codex `0.140.0` agent

Each host passed the 11-case version-3 routing matrix. Xcode 26.6's bundled
Codex `0.140.0` agent accepts `gpt-5.5`; newer models require a newer Xcode
agent. See the [compatibility contract](docs/COMPATIBILITY.md) and
[qualification record](docs/RELEASE_QUALIFICATION_0.2.2.md) for exact source,
artifact, and host evidence.

## What the companion installs

- a signed and notarized installer app inside a DMG
- a physical, validated `xcode-headless` Apple AppDev Workflow profile
- an embedded official Node.js LTS runtime used only by the two lifecycle hooks
- transactional backup and restore of the prior Xcode profile/configuration

It does not install MCP servers, XcodeBuildMCP, a proxy, or a replacement Codex
agent. Install the [Marketplace plugin](https://github.com/jkaunert/apple-appdev-workflow)
separately for ordinary Codex Desktop/CLI use and its plugin-owned MCPs.

## Install

1. Quit Xcode.
2. Download and open the `AppleAppDevXcodeHeadlessInstaller-0.2.2.dmg`
   asset from the [stable release](https://github.com/jkaunert/apple-appdev-xcode-companion/releases/tag/v0.2.2).
3. Open `AppleAppDevXcodeHeadlessInstaller.app` and activate **Install**.
4. Activate **Review Hooks** and approve both `UserPromptSubmit` and `Stop` in
   Xcode's stock Codex review surface.
5. Relaunch Xcode and start a fresh conversation.

The installer keeps Xcode's active agent unchanged and prints a concrete
rollback path. It never pre-trusts hooks or modifies `hooks.state`; hook trust
is an explicit user security decision.

For terminal-driven installation from a mounted DMG:

```bash
cd "/Volumes/Apple AppDev Xcode Headless Installer"
./AppleAppDevXcodeHeadlessInstaller.app/Contents/MacOS/xcode-headless-installer \
  --install-plugin-profile
```

The mounted volume may have a numeric suffix if another copy is already open.

## Boundaries and troubleshooting

The companion and Marketplace plugin are separate distributions. Marketplace
installation does not silently provision Xcode, and companion installation does
not alter ordinary Codex homes or remove `LocalAppleWorkflow` caches.

If routing does not appear in Xcode:

1. confirm both lifecycle hooks are trusted and enabled in Codex hook settings;
2. restart Xcode and begin a fresh conversation;
3. use the explicit fallback `$apple-appdev-workflow:<skill>` invocation when
   hooks are disabled or restricted;
4. use the rollback path printed by the installer if the profile must be
   restored.

Issues and release feedback belong in the
[companion issue tracker](https://github.com/jkaunert/apple-appdev-xcode-companion/issues).
The project is licensed under the [Apache License 2.0](LICENSE).
