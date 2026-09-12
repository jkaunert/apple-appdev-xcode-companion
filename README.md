# Apple AppDev Xcode Companion

Apple AppDev Xcode Companion is the optional, signed companion for using Apple
AppDev Workflow inside Xcode CodingAssistant.

It installs the matching hook-native workflow profile into Xcode’s separate
Codex home. The Marketplace plugin remains the normal Codex Desktop and CLI
distribution.

## Download

Download the current prerelease from the
[GitHub releases page](https://github.com/jkaunert/apple-appdev-xcode-companion/releases).

The `0.2.2-beta.1` release is qualified for Xcode 27 Beta 5 and macOS 15 or
later.

## Install

1. Quit Xcode.
2. Download and open the DMG.
3. Open `AppleAppDevXcodeHeadlessInstaller.app`.
4. Choose **Install**.
5. Choose **Review Hooks**, inspect both lifecycle hooks, and trust them.
6. If prompted, trust only the installer’s dedicated onboarding workspace.
7. Reopen Xcode and start a fresh CodingAssistant conversation.

The installer creates a rollback backup before replacing the profile and leaves
Xcode’s active Codex agent unchanged.

## What it installs

- The Apple AppDev Workflow hook-native profile
- An embedded official Node.js runtime used only by the two lifecycle hooks
- A transactional rollback path for the previous profile and configuration

## What it does not change

- It does not replace or activate Xcode’s Codex agent.
- It does not install or configure MCP servers.
- It does not modify the ordinary Codex Desktop or CLI home.
- It does not delete `LocalAppleWorkflow` caches.
- It does not replace Xcode’s native `xcode-tools` integration.

## Trust and troubleshooting

Automatic routing requires both lifecycle hooks to be trusted. If routing is
missing, open the stock Codex hook browser, confirm that
`apple-appdev-workflow@apple-developer-tools` is enabled, and start a fresh
conversation.

If the installer reports that Xcode is running, quit Xcode completely and retry.
The installer prints the exact rollback path after a successful replacement.

## Support and license

Report issues at
[GitHub Issues](https://github.com/jkaunert/apple-appdev-xcode-companion/issues).
Licensed under the [Apache License 2.0](LICENSE).
