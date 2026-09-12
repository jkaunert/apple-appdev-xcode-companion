# Compatibility

The current `0.2.2-beta.2` companion is qualified for:

- macOS 15 or later
- Xcode 27 Beta 5 (`27A5237l`)
- Xcode’s signed Codex agent `codex-cli 0.145.0`

The companion installs only the hook-native Apple AppDev Workflow profile. It
does not replace Xcode’s Codex agent, install MCP servers, or change Xcode’s
native `xcode-tools` provider.

For signed-artifact details, historical versions, and source-to-package hashes,
see the [maintainer compatibility evidence](maintainer/COMPATIBILITY_EVIDENCE.md).
