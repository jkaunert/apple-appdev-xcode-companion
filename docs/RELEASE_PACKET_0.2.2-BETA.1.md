# Apple AppDev Xcode Companion 0.2.2-beta.1 Release Packet

Status: beta package qualification in progress; this packet is not a publication claim.

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

The final signed package will be rebuilt from the clean companion source commit
recorded below after this provenance update, with a profile rendered from the
qualified private plugin source above. The package sidecar and accepted notary
result are the authoritative artifact records and will be attached here after
the build.

```text
DMG SHA-256: pending final package build
sidecar SHA-256: pending final package build
notarization submission: pending final package build
Node runtime: v24.19.0
```

The package is not publishable until signing, notarization, stapling,
Gatekeeper, transactional installation, and fresh exact-package Xcode trust
and matrix evidence are all recorded.
