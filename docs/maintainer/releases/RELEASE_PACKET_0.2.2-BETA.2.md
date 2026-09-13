# Apple AppDev Xcode Companion 0.2.2-beta.2 Release Packet

Status: qualified prerelease package.

This companion beta pairs with the documentation-focused
`apple-appdev-workflow` Marketplace beta `0.2.2-beta.2`. It remains hook-only,
embeds the official Node.js runtime required by Xcode’s sanitized hook
environment, and does not provision MCP servers or replace Xcode’s active
Codex agent.

## Package evidence

The final package was built from clean companion commit
`a40df27419e374e36833f0ab1282c8b4598bac70` with an `xcode-headless` profile
rendered from private plugin `main` at
`2b954c49bd1df757405d74a2cd0c5d9cdfbdcc24`.

```text
app version: 0.2.2-beta.2
app build: 2
DMG SHA-256: 678aafb3191691f27da2faa30c668ef3fb3d3554e985b4d983136ed632f156f9
sidecar SHA-256: dccb038df9308f4d5c2f6bc32e7312cac6872026a939d3e5b8df6379c69e0272
notary result SHA-256: c97ea92ab055c18f1e8aedfa501f1e47964c5d8e061e505326afcc3510c6fb46
notarization submission: dc9ae04b-89fc-43db-a2af-3b682466c41b
plugin manifest SHA-256: f8ee017d8efe37881547ca09fae3caf138d338bad7083fc6cfe4a27009430572
source routing core SHA-256: 946367e5d475a041742b53e5557deb1817296ca524ecd4e17eb4622ab0f23992
embedded routing core SHA-256: 6cdcd2ad41ea09864f00408b988a5573d83dad1e9b0a976a155b6f467ba65ab6
signed embedded Node SHA-256: 15b775da9387a17cd5f859eedb5d509a8ed12b33fe8e9023f3e41b59de0765c1
```

The DMG is Developer ID signed, notarized (Accepted), stapled, and
Gatekeeper-accepted. The installer passed both sanitized-PATH hook postflights,
preserved Xcode’s active agent, and created a rollback backup.

## Exact-package Xcode evidence

After installing the beta.2 profile and reopening Xcode 27 Beta 5, the
contract-v3 matrix passed all 11 cases, including authored macOS and Swift
Package prompts.

```text
matrix manifest SHA-256: ba2b71c3eb10f819114b154d9cabcf449e228818631318d89dcf34638161f2e5
matrix report SHA-256: 0e102b4d322a9bb4c29092a53bbd908f5863d183afb454a9329907237b9bac01
result: pass
xcode gate: passed
cases: 11/11
```

## Distribution

The signed prerelease is published at:

<https://github.com/jkaunert/apple-appdev-xcode-companion/releases/tag/v0.2.2-beta.2>

The public plugin counterpart is
[`v0.2.2-beta.2`](https://github.com/jkaunert/apple-appdev-workflow/releases/tag/v0.2.2-beta.2).
The companion release tag targets merged source `729cbdd28b2db92f7a558caa09665195292f80d3`.
