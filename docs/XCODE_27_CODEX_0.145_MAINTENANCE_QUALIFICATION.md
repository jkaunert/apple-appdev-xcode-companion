# Xcode 27 / Codex 0.145 Maintenance Qualification

This document tracks the companion-only maintenance candidate prompted by the
Xcode 27 Beta 5 host change. Local source, packaging, installation, and
qualification work may continue during judging, but no branch, pull request,
tag, release, or asset may be pushed or published until the remote freeze is
explicitly lifted.

## Candidate contract

- companion app version: `0.2.1`
- companion app build: `3`
- embedded plugin identity: `apple-appdev-workflow@apple-developer-tools`
- embedded plugin version: `0.2.1`
- embedded plugin source:
  `835435901c5ac46d5d45176e16d8c2e0f568d886`
- Xcode host: Xcode 27 Beta 5, build `27A5237l`
- stock Xcode Codex: `codex-cli 0.145.0`
- qualification contract: `3`
- hook runtime: pinned official Node.js LTS `v24.19.0`
- hook commands:
  - `"$PLUGIN_ROOT/hooks/runtime/node" "$PLUGIN_ROOT/hooks/apple_router.mjs"`
  - `"$PLUGIN_ROOT/hooks/runtime/node" "$PLUGIN_ROOT/hooks/apple_contract_guard.mjs"`

Contract version 3 preserves exact `orchestrator-led` routing, exact
`apple-appdev-workflow:apple-app-orchestrator` ownership, and exact `applied`
injection. It retains all nine contract-v2 Xcode cases, including the exact
neutral reason `workspace-extension:xcworkspace`, and adds natural-language
macOS and Swift Package cases requiring exact authored-prompt reasons
`prompt-signal:macos` and `prompt-signal:swift package`.

## Build-3 local source candidate

The exact validated source render has no symlinks and contains plugin version
`0.2.1`. Its source routing-core SHA-256 is
`e0606455bb9d8ce4dc6d74cfd6e517eba5ba2cd91062ea7f651ee91b99f87ba8`.
The component hashes are recorded in
[`SOURCE_PROVENANCE.md`](SOURCE_PROVENANCE.md).

The package dry-run passed with application version `0.2.1`, application build
`3`, the exact plugin manifest SHA-256
`2efee00591f2ef0c69d585f9d0447af7f082f416d57570ac1e4635283f4dd254`,
official Node.js `v24.19.0` SHA-256
`27db838bb204ef7c21df2931f5656e4c8fb32e6e947f363a402b49714d32b5b1`,
and Node license SHA-256
`148eacf7863ef4329224a29398623077200a27194aa075569faf4a0a85566ca5`.

## Build-3 signed and notarized artifact

The final local artifact was built from clean companion commit
`d6688435df3f63ebea68a8d6ed2d289c19975c75`. It passed strict signature,
stapling, Gatekeeper-open, mounted-app Gatekeeper, and source-profile parity
checks.

```text
DMG: AppleAppDevXcodeHeadlessInstaller-0.2.1.dmg
DMG SHA-256: 26dfb852f8bfd1c8f078eda0bddc17eeefa0cbeb2a79513fc794be445778b0a5
sidecar SHA-256: 2988865b4325941d0d2bb6fd6fcc544ee1e39f0b35c0bdfcace693c4a0885356
notary JSON SHA-256: 08dfaccca06fd17bd785a07aad49364cb233e53a3e83271cdd2583e4a236c000
notary submission: c06f82e2-2825-4f2d-a77e-2c2243cbdf4a
notary status: Accepted
embedded routing core: 33bf6748df912a31b99a8f6d9547996343b86247922d031cae22b08e171da760
signed hook runtime: 5d5f6e28b7b8238637681f8026f680aebd57152eb288e706d975ffdbf0033485
```

## Build-3 installation and hook review

The exact DMG completed the native installation with Xcode closed and
VoiceOver enabled. The installer replaced the prior profile only after
creating this rollback snapshot:

```text
/Users/joshuakaunert/Library/Developer/Xcode/CodingAssistant/codex/.tmp/plugins/quarantine/apple-appdev-workflow/0.2.1-plugin-install-20260812T103502Z
```

`Review Hooks` opened the Xcode-shipped `codex-cli 0.145.0`. Stock Codex showed
one active `UserPromptSubmit` hook and one active `Stop` hook under
`apple-appdev-workflow@apple-developer-tools`; both remained trusted through
the stock review surface:

```text
UserPromptSubmit trust hash: sha256:bb883231a497676fe6ab677af02eada9a794fec2851562fe452c2c774c4aff10
Stop trust hash: sha256:7f26b5d44d66ae59d13d78aad2a3d150c1cc9b12c4d584da2fcc6eef725783e4
installed manifest: 2efee00591f2ef0c69d585f9d0447af7f082f416d57570ac1e4635283f4dd254
installed hooks.json: f615cf9f0e8645d8830665929044c6756c25dab80560b70f6dd2ec5568cceea2
installed routing core: 33bf6748df912a31b99a8f6d9547996343b86247922d031cae22b08e171da760
installed hook runtime: 5d5f6e28b7b8238637681f8026f680aebd57152eb288e706d975ffdbf0033485
```

The installer and review agent exited normally, the rollback path remained on
the clipboard, and VoiceOver was restored to off.

## Contract-v3 live Xcode evidence

The canonical Xcode 27 Beta 5 matrix passed all 11 cases against the installed
build-3 profile while retaining the green 12-case stock Desktop prerequisite.
The two new natural-language turns share stock Xcode session
`019ff591-f0f2-7343-b037-4c821eb74b80` and persisted conversation
`5AE9BD1C-5B2F-4548-9CA6-EDE9DE13F6FD`:

```text
macos-natural: orchestrator-led / apple-appdev-workflow:apple-app-orchestrator / applied / prompt-signal:macos
swift-package-natural: orchestrator-led / apple-appdev-workflow:apple-app-orchestrator / applied / prompt-signal:swift package
```

The scorer attributed the accepted turns to Xcode PID `19425` and its
Xcode-shipped Codex app-server, rejected carry-backed attribution, and reported
`xcodeGate=passed` with no errors.

```text
manifest: /Users/joshuakaunert/.codex-fork/quarantine/v021-swift-package-provenance-20260812/xcode-v3-live-build3/xcode-parity-manifest-27A5237l-v3-build3.json
manifest SHA-256: b3f78a62133f04d763b988c7955ca7d7d52ce6d7f2a606c5de1f851da5dab410
report: /Users/joshuakaunert/.codex-fork/quarantine/v021-swift-package-provenance-20260812/xcode-v3-live-build3/xcode-parity-report-27A5237l-v3-build3.json
report SHA-256: ebc8ea77421adfc7703522a72dffc879dc186c883caae9331a5806116de8bcf0
```

Selected build-3 screenshot SHA-256 evidence:

```text
confirmation with VoiceOver: 68a8b157b2f16a3d62b77e2c775860bb6510714dd83670c907d273a528cc6322
completion with Review Hooks: 6dcce48908d2160ce6a4bc986d6069b115ed8ebed7ce38bb7a1c2531185d8f34
hooks list: 1091db6dc3e81a0dc333a9e161b3ff175ee855943f4e02c581c3a93d0cd062d6
UserPromptSubmit trusted: 0b49e81e9e721a5bfc9fd727cb13a03912a34eb0fb7acc968f065fb4575b99c7
Stop trusted: 4f7d1de91205a1d476f7673ca86cd8dd0f7e78257044ae97d3a54c16375a1a70
macOS natural-language result: 9ae77d0daf040e20853234ced684b014e9537aee9ba888426624fcbe9415cb36
Swift Package natural-language result: 069fb8d39934042f6ed12d881ac918f3daa27a228e2d97d8a5bc0576eca05240
```

## Implemented distribution gates

- the runtime fetcher pins the official architecture-specific archive and
  verifies its published SHA-256 before extraction
- only `bin/node` and the Node.js `LICENSE` enter the package
- the packager rejects symlink runtimes and non-system dynamic-library
  dependencies
- the packager rewrites both lifecycle hooks to exact plugin-relative runtime
  commands
- the runtime is signed before the enclosing installer app
- the sidecar manifest records source and final runtime hashes, the license
  hash, and source versus embedded routing-core hashes
- the installer requires the runtime, license, and exact commands before copy
- the installer executes both hooks with
  `PATH=/usr/bin:/bin:/usr/sbin:/sbin` before enabling the plugin
- the Stop postflight verifies one correction and a silent
  `stop_hook_active=true` retry so the guard cannot loop
- any validation or postflight failure restores the prior profile and config
- the completion dialog makes explicit hook review the primary next action and
  opens the exact Xcode-shipped stock Codex binary in Terminal
- the review handoff preserves Terminal foreground process-group ownership,
  uses a dedicated empty onboarding workspace instead of the user's home, and
  rejects symlinked onboarding directories
- the review handoff preserves stock ownership of command/source inspection and
  trust persistence; the installer never writes `hooks.state`

## Historical build-1 development evidence

The first ad-hoc development package completed from dirty companion source to
prove package mechanics only. It is not a release candidate and is not public
distribution evidence.

- package output:
  `/tmp/apple-appdev-xcode-companion-runtime-dev-build-v2-20260810`
- package filename: `AppleAppDevXcodeHeadlessInstaller-0.2.1.dmg`
- DMG SHA-256:
  `c2eda3f64634bb3096451d48a673c8a6f35d3a4952d33fd6e38adff6c58bf8a4`
- source routing-core SHA-256:
  `565f1089fadaa4594a8d97f473610a3783a0f5e3c99f35c9123c02facf5e4257`
- embedded routing-core SHA-256:
  `158023b5adc09faf6c3e4248309f1b14e68f58a58ca16939e2997e16ba0ed748`
- source Node executable SHA-256:
  `27db838bb204ef7c21df2931f5656e4c8fb32e6e947f363a402b49714d32b5b1`
- final ad-hoc-signed Node executable SHA-256:
  `b49e3d4673bd14b343ff17111df6696e3961701bf36ed981f878e57e24f559ba`
- package-time sanitized-PATH postflight: `UserPromptSubmit` pass, `Stop`
  correction pass, `Stop` one-retry guard pass

## Historical build-1 trust-onboarding evidence

The exact clean companion commit under qualification is
`bfd17f6a72055090a7bdb7acab3280ca4f2193a9`. Live validation of earlier
unpublished candidates exposed two terminal-boundary defects before promotion:
Foundation `Process` moved stock Codex out of Terminal's foreground process
group, and the zsh cleanup function resolved `$0` to its function name instead
of the launcher path. The final candidate uses a foreground-preserving `execv`
handoff, captures the launcher path before entering the cleanup function, and
adds a pseudo-terminal regression that requires the agent process group to
equal the terminal foreground process group.

The final Developer ID signed and notarized package is:

```text
DMG: build/releases/xcode27-beta5-trust-bfd17f6/AppleAppDevXcodeHeadlessInstaller-0.2.1.dmg
DMG SHA-256: a51ceed81366dc30de615b62c6850af2d9b660417a2c1c252252916fcc787d18
sidecar SHA-256: 9fe6c727b461ffcdadacf20a0adc07169c13844a3464ff59446d9255d9e914df
notary JSON SHA-256: a70e34c7e877cc02f28e73ca67c9f798e63e880c00ec6b4db646d14eb3e3c925
notary submission: 6b696373-7fe7-4644-8d11-83053938b15e
notary status: Accepted
```

The first submission completed inside the harness's initial 600-second window,
so the identical-byte recovery resubmission path was not entered. Stapler,
Gatekeeper-open assessment, mounted-app Gatekeeper assessment, and strict app
signature validation all passed.

The exact DMG completed the native install flow with Xcode closed and
VoiceOver enabled. The completion alert exposed `Review Hooks`, `Copy Rollback
Path`, and `Done`, and preserved this rollback snapshot:

```text
/Users/joshuakaunert/Library/Developer/Xcode/CodingAssistant/codex/.tmp/plugins/quarantine/apple-appdev-workflow/0.2.0-plugin-install-20260811T105553Z
```

`Review Hooks` launched the Xcode-shipped Codex `0.145.0` agent with its process
group equal to Terminal's foreground process group. Stock Codex requested trust
only for the dedicated empty
`.tmp/hook-trust-onboarding/workspace`, not the user's home or an application
project. Its `/hooks` browser then showed both packaged commands active and
trusted under `apple-appdev-workflow@apple-developer-tools`:

```text
UserPromptSubmit trust hash: sha256:bb883231a497676fe6ab677af02eada9a794fec2851562fe452c2c774c4aff10
Stop trust hash: sha256:7f26b5d44d66ae59d13d78aad2a3d150c1cc9b12c4d584da2fcc6eef725783e4
```

Normal TUI exit removed the one-use launcher, and VoiceOver was restored to
off. Selected screenshot SHA-256 evidence:

```text
confirmation with VoiceOver: afc1328d965c6fcaa134ecdceb370aa8f85834829414c122f2b4529af388f5fd
completion with Review Hooks: 06fbb9ed2c185dbebe3cefdda54d29b861b21cc1b7fc81e99a91f30941409044
dedicated-workspace prompt: 88734432eac45886a919354dcfc759949dd9699ec9f6b8c5932bcdd350c2de32
UserPromptSubmit trusted: 0d442c9dc0864f2cc8759ec473c6b63ba4d55210c966636befa54ab2888137d9
Stop trusted: fce55f9d8595c597fa259c0817a1884147d8b20c9be99cb6f7dfd77280f2482d
VoiceOver restored off: b023b77e1e06ed300ce2ea6a8af6b67afbbac73b058285a880dc8a2bc746a9eb
```

The installed profile was byte-identical to the mounted DMG payload. Its
manifest SHA-256 is
`45beef50d55daf3ad71fb6d2ea31496b723652d660e124b2244990cd5b9be36a`,
its rewritten `hooks.json` SHA-256 is
`f615cf9f0e8645d8830665929044c6756c25dab80560b70f6dd2ec5568cceea2`,
and its final signed hook-runtime SHA-256 is
`03e1fd1a760aed8055fa4ceee56957a645c971f90ca9360143aaea9b0e9f0400`.

The unchanged canonical qualification-contract-v2 matrix was rescored against
this installed profile and exact companion sidecar. It passed all 9 Xcode cases,
retained the 12-case stock Desktop prerequisite, and reported
`xcodeGate=passed`:

```text
manifest: /Users/joshuakaunert/.codex-fork/quarantine/stock-xcode-hook-router-live-parity-beta5-trust-bfd17f6-20260811/probe-xcode-01/xcode-parity-manifest-27A5237l-v2-trust-bfd17f6-canonical.json
manifest SHA-256: c5fc2022b2ef1c227fc2233007998569d7cd9764d0a9566ea47fab3a9cdbbbbb
report: /Users/joshuakaunert/.codex-fork/quarantine/stock-xcode-hook-router-live-parity-beta5-trust-bfd17f6-20260811/probe-xcode-01/xcode-parity-report-27A5237l-v2-trust-bfd17f6-canonical.json
report SHA-256: 23a879e437f39f9b682e4b303e8660b6e01bd51c08f77c900016e41add31f944
```

The final automated gate is 24/24 installer tests, warnings-as-errors Swift
compilation, shell syntax validation, and a clean branch-diff review. This is
green for companion branch promotion. Publishing a `0.2.1` GitHub release and
asset remains a separate release operation.

## Release sequence status

1. Complete focused tests, warnings-as-errors Swift compilation, shell syntax,
   JSON validation, and branch-diff review.
2. Commit the companion and private qualification changes so the release
   packager can enforce a clean source commit.
3. Build the exact Developer ID signed and notarized `0.2.1` DMG.
4. Verify the DMG and mounted app with Gatekeeper and validate the sidecar
   manifest.
5. Quit Xcode and install the exact DMG, preserving the printed rollback path.
6. Explicitly review and trust both changed hook definitions.
7. Restart Xcode and run the fresh routing smoke, the 11-case Xcode matrix, the
   12-case stock Desktop prerequisite, and the Stop one-retry correction.
8. Record final artifact hashes, trust hashes, session IDs, and the v3 scorer
   report before publishing a companion maintenance release.

All eight technical steps are green locally. The candidate is ready only for
post-freeze branch promotion and release publication; it remains a public
release `no-go` until the judging freeze is explicitly lifted and the remote
state is rechecked.
