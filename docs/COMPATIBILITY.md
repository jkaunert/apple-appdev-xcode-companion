# Compatibility Contract

This companion release candidate is pinned to the following Marketplace
plugin identity:

```text
plugin: apple-appdev-workflow
plugin version: 0.2.0
marketplace source: apple-developer-tools
public distribution commit: c3702d917fedaa6674a750695d3173e36d714522
private source commit: c30409e917a5bcdb02010c0b78b4971c2b3fa42a
```

The rendered `xcode-headless` profile used for packaging must preserve these
qualified payload hashes:

```text
.codex-plugin/plugin.json: e60578bf493e0d940419f0082c45516cd84e9ea1b0398542dbb81ee01a225585
routing core: 9f7a0f4b9d9d5fec5cde9b01a274d5eb7ec7a4cdd147294e66896a1f804536c6
```

The routing core hash is the package manifest's aggregate for the hook,
neutral policy, and top-level owner kernel. It must be checked from the final
DMG sidecar before installation.

The companion installs and enables only the `apple-developer-tools` identity
for the target Xcode Codex home. It disables conflicting
`apple-appdev-workflow@<source>` config entries there to prevent duplicate
hook execution, but does not remove, overwrite, or migrate their caches.
`LocalAppleWorkflow` installations in other Codex homes remain untouched.
