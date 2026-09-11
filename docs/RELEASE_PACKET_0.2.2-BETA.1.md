# Apple AppDev Xcode Companion 0.2.2-beta.1 Release Packet

Status: release train in progress; this packet is not a publication claim.

The beta is paired with Marketplace plugin `apple-appdev-workflow`
`0.2.2-beta.1` from the exact merged private `main` source SHA. The companion
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

## Candidate package evidence

The first candidate package was built from companion commit
`9e521241edf88afb0909dbcc5c40117ea8c3f8c2` with a profile rendered from plugin
topic commit `048d4d4c43a13eaad1465a4d7c7248f4d4a91a18`:

```text
DMG SHA-256: 8779244b98166d2f3e0f87aa4ed7542fa263bf1360a332e85fb76a87d9ddb50f
notarization submission: d80d7cd9-3b1f-403b-b861-2885476a68de
Node runtime: v24.19.0
```

This candidate passed signing, notarization, stapling, Gatekeeper, and the
transactional package-validation install. It remains non-publishable until
fresh Xcode trust and matrix evidence pass and the package is rebuilt from the
exact merged private plugin source.
