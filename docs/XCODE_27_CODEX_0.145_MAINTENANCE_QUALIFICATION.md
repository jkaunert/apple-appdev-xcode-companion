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
