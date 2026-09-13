# Compatibility Contract

The stable companion `0.2.2` build-3 release contract is pinned to these Xcode
profile identities:

```text
plugin: apple-appdev-workflow
plugin version: 0.2.2
marketplace source: apple-developer-tools
private source commit: recorded in the paired release contract
qualification contract: 3
companion app version: 0.2.2
companion app build: 3
Xcode 27.0 RC build: 27A266a / Codex 0.145.0
Xcode 26.6 build: 17F113 / Codex 0.140.0
```

Its profile preserves deterministic top-level ownership, adds authored macOS
and Swift Package prompt provenance, and retains
`workspace-extension:xcworkspace` only for the neutral Xcode host-context
case. The release artifact must be signed, notarized, explicitly hook-reviewed,
and qualified by the 11-case live matrix on both supported hosts; exact hashes
and evidence are recorded in the paired release contract.

The prior `0.2.1` build-3 maintenance record remains historical; its exact
hashes and evidence are in
[`XCODE_27_CODEX_0.145_MAINTENANCE_QUALIFICATION.md`](XCODE_27_CODEX_0.145_MAINTENANCE_QUALIFICATION.md).
The companion release does not publish or modify the paired public plugin
repository as part of packaging.

## Published 0.2.0 compatibility record

The following facts remain the historical published `v0.2.0` contract:

```text
plugin: apple-appdev-workflow
plugin version: 0.2.0
marketplace source: apple-developer-tools
public distribution commit: c3702d917fedaa6674a750695d3173e36d714522
private source commit: c30409e917a5bcdb02010c0b78b4971c2b3fa42a
dual-hook profile source commit: b176905b88ac3b21827f088d8a8c1b5b4c044a23
```

The qualified dual-hook `xcode-headless` profile preserves these payload
hashes:

```text
.codex-plugin/plugin.json: 0b52bbc68aa8d534124d66b8f3ea5c7307bd020d103ababa5e74b0de2e5c5f9d
hooks/hooks.json: 0451510d0746ff745b246cb41d57fd99faa74153e13486a3af8320d6de10793e
hooks/apple_router.mjs: 8195ca4054b68d9b8815acd38b85cee6a6af7c809fc2e974ba1448255dc657c2
hooks/apple_contract_guard.mjs: 895cef34b9c45ca0ae5557fccde5693854def4d33734acd621494e5090dadfe8
routing core: 565f1089fadaa4594a8d97f473610a3783a0f5e3c99f35c9123c02facf5e4257
```

The routing core hash is the package manifest's aggregate for the hooks,
neutral policy, and top-level owner kernel. These values came from the exact
signed and notarized DMG sidecar and matched the installed Xcode profile.

The build-4 installer executable is compiled with:

```text
-target arm64-apple-macosx15.0
```

Its app metadata and Mach-O load command both declare macOS 15.0 as the
minimum. The exact notarized artifact launched and completed a transactional
install on macOS 15.7.8 build `24G824`, and it was also installed and exercised
through Xcode 27.0 build `27A5209h` on macOS 26.5.1 build `25F80`.

The superseded build-3 executable must not be distributed. Although its app
metadata declared macOS 15.0, Swift had compiled it for macOS 26.0 and its
`libswift_DarwinFoundation2.dylib` dependency prevented launch on macOS 15.

The previously qualified `UserPromptSubmit` hook definition had this stock
Codex trust hash:

```text
sha256:1c82a273ee2e6d13245f8ade4bff516ecb8d46b623c96c22e4e572a8edb87711
```

The repaired profile contains both `UserPromptSubmit` and `Stop`. The routing
command definition is unchanged, so an upgraded Xcode Codex home can retain
the qualified `UserPromptSubmit` trust hash above. The new `Stop` command
definition has this exact-candidate trust hash:

```text
sha256:0ed272c8c1d1eb54f0342f83d3cb690a70448b72397b3fd1c53ffd191cc6bc78
```

Clean homes still require explicit review of both commands. The installer
intentionally does not add either hash to `hooks.state`.

The companion installs and enables only the `apple-developer-tools` identity
for the target Xcode Codex home. It disables conflicting
`apple-appdev-workflow@<source>` config entries there to prevent duplicate
hook execution, but does not remove, overwrite, or migrate their caches.
`LocalAppleWorkflow` installations in other Codex homes remain untouched.
