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

## Current build-4 qualification

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

## Xcode 27 maintenance boundary

The Xcode 27/Codex `0.145.0` maintenance work is companion-native. It does not
change the rendered plugin source files. At package time the companion copies
the same validated private `xcode-headless` render, adds a pinned official
Node.js LTS executable plus its license under `hooks/runtime`, and rewrites
only the two commands in the embedded copy of `hooks/hooks.json` to use that
plugin-relative runtime. The package sidecar records both the unmodified source
routing-core hash and the transformed embedded routing-core hash.

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
