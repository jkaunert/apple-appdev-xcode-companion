# Compatibility

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

For signed-artifact details, historical versions, and source-to-package hashes,
see the [maintainer compatibility evidence](maintainer/COMPATIBILITY_EVIDENCE.md).
