# Apple AppDev Xcode Companion 0.2.2-beta.1 Release Packet

Status: qualified prerelease package; publication assets are ready for the
companion repository release.

The beta is paired with Marketplace plugin `apple-appdev-workflow`
`0.2.2-beta.1` from the qualified private `main` source commit
`722fda0943993fe2506e3a32dd6b12bbd1c92511` (release-evidence merge
`7fd1ae9a14f38aafa208708b604b6d1f43383b8b`). The companion
is intentionally hook-only: it installs the `xcode-headless` profile, embeds
the pinned official Node.js LTS runtime for lifecycle hooks, preserves Xcode's
active Codex agent and rollback path, and does not register or provision
XcodeBuildMCP, Sosumi, or Memory MCP.

## Required release evidence

- clean companion source commit and exact paired plugin source SHA
- rendered and validated `xcode-headless` profile
- Developer ID signed installer app and DMG
- stapled, Gatekeeper-accepted notarization result
- DMG and sidecar checksums
- official Node archive, executable, and license provenance
- explicit review/trust of both lifecycle hooks
- fresh Xcode 27 Beta 5 contract-v3 matrix (11 cases)
- rollback backup and active-agent preservation evidence

The immutable package manifest and notary result are added beside this packet
only after the final package is built. Historical `v0.2.0` and `v0.2.1` assets
remain separate evidence and cannot qualify this changed beta payload.

## Final package evidence

The final signed package was built from clean companion commit
`ff4dfe20c4707eb3fc794f14cb2f0620bbba271b` with a profile rendered from the
qualified private plugin source above. The package sidecar and accepted notary
result are the authoritative artifact records.

```text
DMG SHA-256: d372c87184cbcbe409dbcb60e9398863fd51eeba1e7d989b4048c6016810c8f5
sidecar SHA-256: b91dce1beb84634f5308f45a2ede2326e9cf0197fa4d528081a906e35f4148b6
notary result SHA-256: dc1d8bded147c4ab47fd045f88e0a56bbdaa63729cdcfc8bccfb5cf09c26219a
notarization submission: 96167d46-f990-48e3-944b-bf0669718336
Node runtime: v24.19.0
installer executable SHA-256: af5ce9be04be5761dc83df787c804939f306a6c8758316951883fbae8b3be65e
plugin manifest SHA-256: 4ea72ae864c4cf5223af791e9ea238ed758458c267f6ec7dfc48f37c7cfb2aee
source routing core SHA-256: 946367e5d475a041742b53e5557deb1817296ca524ecd4e17eb4622ab0f23992
embedded routing core SHA-256: 723e3774ff854808dcdd60ed5a4adf3be40fd356935fef4f7c31207df4c47588
signed embedded Node SHA-256: b2eb13d6bcd6b83928d24b80155795bb8a38eeab5950507a908bf6bea3916f63
```

The DMG is Developer ID signed, notarized (Accepted), stapled, and
Gatekeeper-accepted. It passed transactional package validation, preserved the
active Xcode agent, and created rollback backup
`/Users/joshuakaunert/Library/Developer/Xcode/CodingAssistant/codex/.tmp/plugins/quarantine/apple-appdev-workflow/0.2.2-beta.1-plugin-install-20260912T013937Z`.

## Fresh exact-package Xcode evidence

Xcode 27 Beta 5 build `27A5237l` with its signed `codex-cli 0.145.0` agent was
reopened after installing this exact package. The contract-v3 matrix passed all
11 cases, including authored macOS and Swift Package prompts, with no carry
process attribution.

```text
matrix manifest SHA-256: 88b44acbeef01862a01f3bb5acab6a1db5821a05632d80c4775c384963e6266f
matrix report SHA-256: e3b4ab940c904e974d88ae8adc364f5eddef923c6572f0bbdb81f8a108f3d729
result: pass
xcode gate: passed
cases: 11/11
```

The raw manifest and report are retained under the qualification quarantine
surface; the report attributes the accepted app-server to Xcode's live PID and
records the final installed profile, runtime, trust, and package hashes.
