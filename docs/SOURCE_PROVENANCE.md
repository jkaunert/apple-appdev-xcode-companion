# Source Provenance

## Companion 0.2.2-beta.1 release train

This branch prepares the hook-only companion beta paired with the qualified
private Apple AppDev Workflow `0.2.2-beta.1` Marketplace source. The final
package embeds an `xcode-headless` profile rendered from private `main` at
`722fda0943993fe2506e3a32dd6b12bbd1c92511` (release-evidence merge
`7fd1ae9a14f38aafa208708b604b6d1f43383b8b`), then rewrites only the two
lifecycle-hook commands to the pinned official Node.js LTS runtime. It does
not bundle XcodeBuildMCP, Sosumi, Memory MCP, or private plugin history.

The final package source commit, rendered-profile hashes, Node archive/executable
and license hashes, DMG checksum, accepted notarization submission, and fresh
Xcode Beta 5 matrix report are recorded below. Historical `0.2.0` and `0.2.1`
records remain immutable and cannot qualify this payload.

### Final beta package

```text
app version: 0.2.2-beta.1
app build: 1
companion source commit: ff4dfe20c4707eb3fc794f14cb2f0620bbba271b
DMG SHA-256: d372c87184cbcbe409dbcb60e9398863fd51eeba1e7d989b4048c6016810c8f5
sidecar SHA-256: b91dce1beb84634f5308f45a2ede2326e9cf0197fa4d528081a906e35f4148b6
notary result SHA-256: dc1d8bded147c4ab47fd045f88e0a56bbdaa63729cdcfc8bccfb5cf09c26219a
notarization submission: 96167d46-f990-48e3-944b-bf0669718336
plugin version: 0.2.2-beta.1
plugin manifest SHA-256: 4ea72ae864c4cf5223af791e9ea238ed758458c267f6ec7dfc48f37c7cfb2aee
source routing core SHA-256: 946367e5d475a041742b53e5557deb1817296ca524ecd4e17eb4622ab0f23992
embedded routing core SHA-256: 723e3774ff854808dcdd60ed5a4adf3be40fd356935fef4f7c31207df4c47588
Node runtime: v24.19.0
Node executable SHA-256: 27db838bb204ef7c21df2931f5656e4c8fb32e6e947f363a402b49714d32b5b1
Node license SHA-256: 148eacf7863ef4329224a29398623077200a27194aa075569faf4a0a85566ca5
signed embedded Node SHA-256: b2eb13d6bcd6b83928d24b80155795bb8a38eeab5950507a908bf6bea3916f63
```

The package was signed with Developer ID `Joshua Kaunert (HSRQC9N69B)`,
notarization was Accepted, the DMG was stapled and Gatekeeper-accepted, and
the transactional install preserved Xcode's active agent. The fresh exact-
package Xcode matrix report is retained at
`/Users/joshuakaunert/.codex-fork/quarantine/public-beta-0.2.2-beta.1-20260911/xcode/final-v4-20260912/xcode-parity-report-27A5237l-beta1.json`.

```text
matrix manifest SHA-256: 88b44acbeef01862a01f3bb5acab6a1db5821a05632d80c4775c384963e6266f
matrix report SHA-256: e3b4ab940c904e974d88ae8adc364f5eddef923c6572f0bbdb81f8a108f3d729
result: pass
xcode gate: passed
cases: 11/11
```

## Initial extraction

The initial companion source was mechanically extracted from the private Apple
AppDev Workflow repository at commit:

```text
c30409e917a5bcdb02010c0b78b4971c2b3fa42a
```

Extracted paths:

```text
LICENSE
scripts/test_xcode_headless_installer.py
tools/xcode-headless-installer/README.md
tools/xcode-headless-installer/Sources/XcodeHeadlessInstaller/main.swift
tools/xcode-headless-installer/scripts/package_dmg.sh
```

The extracted installer tree is byte-identical to the tree used by the earlier
0.2.0 package-qualification commit
`952f2a5761c4beaad835b6b8ec34ae53136e44b0`.

## Companion 0.2.1 build-3 release candidate

The build-3 candidate embeds the validated `xcode-headless` profile rendered
from private Apple AppDev Workflow topic commit:

```text
835435901c5ac46d5d45176e16d8c2e0f568d886
```

That source descends from private `main` at
`d7d6192f93a63dd45af5c6be9f349bdb3a069a38`. The render has plugin version
`0.2.1`, qualification contract v3 behavior, no plugin-managed MCP servers,
and these candidate hashes:

```text
.codex-plugin/plugin.json: 2efee00591f2ef0c69d585f9d0447af7f082f416d57570ac1e4635283f4dd254
hooks/hooks.json: 0451510d0746ff745b246cb41d57fd99faa74153e13486a3af8320d6de10793e
hooks/apple_router.mjs: 8195ca4054b68d9b8815acd38b85cee6a6af7c809fc2e974ba1448255dc657c2
hooks/apple_contract_guard.mjs: 895cef34b9c45ca0ae5557fccde5693854def4d33734acd621494e5090dadfe8
routing/router-policy.json: 4dede6d5a1103948877b2e92c12ee92c14c6ee78a95f3f980fc60571ce1a7d72
routing/top-level-owner-kernel.md: 2d00c2577be2174de4aa9b30c7a8f3380e8ded50455dc3d030604d67f7a45949
source routing core: e0606455bb9d8ce4dc6d74cfd6e517eba5ba2cd91062ea7f651ee91b99f87ba8
```

The local public Marketplace payload commit is
`24c1aaedbbf0c4182a2bd31830908d859cd9342a`; its local provenance follow-up
is `e478bbf3a0ab3477aab7d9fb6213f14318fc77b5` (including the earlier
`0d6deaf9057e0d76149856aa3e641bb331aef07a` candidate-provenance commit).
Those plugin-source commits are not published by the companion release; only
the companion source tag and qualified companion assets are promoted.

The signed and notarized companion artifact was built from clean companion
commit `d6688435df3f63ebea68a8d6ed2d289c19975c75`. Its DMG SHA-256 is
`26dfb852f8bfd1c8f078eda0bddc17eeefa0cbeb2a79513fc794be445778b0a5`,
its sidecar SHA-256 is
`2988865b4325941d0d2bb6fd6fcc544ee1e39f0b35c0bdfcace693c4a0885356`,
and Apple accepted notarization submission
`c06f82e2-2825-4f2d-a77e-2c2243cbdf4a`. The installed Xcode profile matched
the sidecar routing core
`33bf6748df912a31b99a8f6d9547996343b86247922d031cae22b08e171da760`.
The canonical contract-v3 report passed all 11 Xcode cases; its SHA-256 is
`ebc8ea77421adfc7703522a72dffc879dc186c883caae9331a5806116de8bcf0`.

## Published 0.2.0 build-4 qualification

The current signed and notarized DMG was built from clean companion commit:

```text
d8f83d1fa0d661aa1c01a1138c0e156bf4929d5d
```

Its embedded `xcode-headless` profile was rendered from clean private Apple
AppDev Workflow commit:

```text
b176905b88ac3b21827f088d8a8c1b5b4c044a23
```

Build 4 supersedes build 3 from companion commit
`7b236ef06b8d6e7f8453a66d23cd8bc0055a155a`. Build 3's app metadata declared
macOS 15.0, but the package script did not pass that deployment target to
Swift. Its executable was therefore built for macOS 26 and failed to launch on
macOS 15.7.8. Commit `d8f83d1` makes `--min-system` control both the app
metadata and Swift compile target and adds regression coverage.

The embedded profile and routing-core hashes are unchanged from build 3.
Build 4's installer executable declares Mach-O `minos 15.0`, contains no
`libswift_DarwinFoundation2.dylib` load command, and completed a real install
on macOS 15.7.8.

Exact artifact hashes, manual UI evidence, and host evidence are recorded in
`docs/qualification/dual-hook-0.2.0-20260730.json`.

## Self-contained hook-runtime transformation

The Xcode 27/Codex `0.145.0` packaging work is companion-native. At package
time the companion copies the validated private `xcode-headless` render, adds
a pinned official Node.js LTS executable plus its license under
`hooks/runtime`, and rewrites only the two commands in the embedded copy of
`hooks/hooks.json` to use that plugin-relative runtime. The package sidecar
records both the unmodified source routing-core hash and the transformed
embedded routing-core hash.

Node archive URL, archive SHA-256, extracted executable SHA-256, architecture,
and license SHA-256 are emitted by
`tools/xcode-headless-installer/scripts/fetch_hook_runtime.sh`. This keeps the
runtime acquisition reviewable without committing a third-party binary to the
repository.

## Distribution boundary

The corresponding public Marketplace release is:

```text
repository: jkaunert/apple-appdev-workflow
tag: v0.2.0
distribution commit: c3702d917fedaa6674a750695d3173e36d714522
```

This repository does not contain the public Marketplace plugin repository's
history and must not be used to mutate that frozen distribution surface.
