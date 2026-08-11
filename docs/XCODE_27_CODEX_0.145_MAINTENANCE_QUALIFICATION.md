# Xcode 27 / Codex 0.145 Maintenance Qualification

This document tracks the companion-only maintenance candidate prompted by the
Xcode 27 Beta 5 host change. It does not modify the frozen public
`jkaunert/apple-appdev-workflow` repository or change the paired plugin version
from `0.2.0`.

## Candidate contract

- companion app version: `0.2.1`
- embedded plugin identity: `apple-appdev-workflow@apple-developer-tools`
- embedded plugin version: `0.2.0`
- Xcode host: Xcode 27 Beta 5, build `27A5237l`
- stock Xcode Codex: `codex-cli 0.145.0`
- qualification contract: `2`
- hook runtime: pinned official Node.js LTS `v24.19.0`
- hook commands:
  - `"$PLUGIN_ROOT/hooks/runtime/node" "$PLUGIN_ROOT/hooks/apple_router.mjs"`
  - `"$PLUGIN_ROOT/hooks/runtime/node" "$PLUGIN_ROOT/hooks/apple_contract_guard.mjs"`

Contract version 2 preserves exact `orchestrator-led` routing, exact
`apple-appdev-workflow:apple-app-orchestrator` ownership, and exact `applied`
injection. For the neutral Xcode host-context case it expects the exact reason
`workspace-extension:xcworkspace`; Codex `0.145.0` no longer includes Xcode's
project-structure prose in the `UserPromptSubmit` prompt on this host.

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

## Development evidence

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

## Final trust-onboarding candidate evidence

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

## Required release sequence

1. Complete focused tests, warnings-as-errors Swift compilation, shell syntax,
   JSON validation, and branch-diff review.
2. Commit the companion and private qualification changes so the release
   packager can enforce a clean source commit.
3. Build the exact Developer ID signed and notarized `0.2.1` DMG.
4. Verify the DMG and mounted app with Gatekeeper and validate the sidecar
   manifest.
5. Quit Xcode and install the exact DMG, preserving the printed rollback path.
6. Explicitly review and trust both changed hook definitions.
7. Restart Xcode and run the fresh routing smoke, the 9-case Xcode matrix, the
   12-case stock Desktop prerequisite, and the Stop one-retry correction.
8. Record final artifact hashes, trust hashes, session IDs, and the v2 scorer
   report before publishing a companion maintenance release.

Until all eight steps are green, status remains `no-go` for public release.
