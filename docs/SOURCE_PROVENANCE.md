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

## Distribution boundary

The corresponding public Marketplace release is:

```text
repository: jkaunert/apple-appdev-workflow
tag: v0.2.0
distribution commit: c3702d917fedaa6674a750695d3173e36d714522
```

This repository does not contain the public Marketplace plugin repository's
history and must not be used to mutate that frozen distribution surface.
