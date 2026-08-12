# Source Provenance

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

## Local 0.2.1 build-3 candidate

The unpublished build-3 candidate embeds the validated `xcode-headless`
profile rendered from private Apple AppDev Workflow topic commit:

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
is `0d6deaf9057e0d76149856aa3e641bb331aef07a`. Neither repository has been
pushed from this release train.

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
