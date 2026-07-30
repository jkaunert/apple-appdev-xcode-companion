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

## Current build-3 qualification

The current signed and notarized DMG was built from clean companion commit:

```text
7b236ef06b8d6e7f8453a66d23cd8bc0055a155a
```

Its embedded `xcode-headless` profile was rendered from clean private Apple
AppDev Workflow commit:

```text
b176905b88ac3b21827f088d8a8c1b5b4c044a23
```

Build 3 supersedes the earlier package from companion commit
`f1083157624fc381328dc246abd9686827ecd2d4`. That package's native
confirmation and completion dialogs named only `UserPromptSubmit`, even though
the embedded profile contained both lifecycle hooks. Commit `7b236ef` corrects
only those two user-facing sentences and adds regression coverage; the
embedded profile and routing-core hashes are unchanged.

Exact artifact hashes, manual UI evidence, and host evidence are recorded in
`docs/qualification/dual-hook-0.2.0-20260730.json`.

## Distribution boundary

The corresponding public Marketplace release is:

```text
repository: jkaunert/apple-appdev-workflow
tag: v0.2.0
distribution commit: c3702d917fedaa6674a750695d3173e36d714522
```

This repository does not contain the public Marketplace plugin repository's
history and must not be used to mutate that frozen distribution surface.
