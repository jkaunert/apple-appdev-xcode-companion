# Release Qualification

## Candidate

The qualified private dual-hook candidate is:

```text
version: 0.2.0
companion source commit: f1083157624fc381328dc246abd9686827ecd2d4
companion source dirty at package time: false
plugin source commit: b176905b88ac3b21827f088d8a8c1b5b4c044a23
DMG: AppleAppDevXcodeHeadlessInstaller-0.2.0.dmg
DMG SHA-256: b9d0bcae86d335ff88401f69f03824d18e6e4c67f16a5a66a05d44d5cd9854fc
installer executable SHA-256: 245f6d46c8f46f8c2965ff8f262a62ea933e64d8026cf3d816a17acfac2f9db7
Developer ID: Joshua Kaunert (HSRQC9N69B)
notary submission: e27839d6-60b7-479a-8be0-cc3168c278f8
notary status: Accepted
plugin manifest SHA-256: 0b52bbc68aa8d534124d66b8f3ea5c7307bd020d103ababa5e74b0de2e5c5f9d
routing core SHA-256: 565f1089fadaa4594a8d97f473610a3783a0f5e3c99f35c9123c02facf5e4257
```

Gatekeeper accepted both the DMG and its mounted installer app as notarized
Developer ID software. Strict deep code-signature verification, DMG stapler
validation, and mounted-app verification passed.

The package contains a physical, symlink-free `xcode-headless` profile and no
replacement Codex agent, bundled MCP proxy, plugin-managed MCP server, or
retired `routerSelection`.

## Installer Gates

- All 16 focused installer tests passed.
- Swift type-checking and shell syntax checks passed.
- The mounted embedded profile was byte-identical to the clean render from the
  pinned plugin source commit and passed bundle validation.
- Exact-package dry-run and install completed from the mounted notarized DMG.
- The installed profile matched the rendered payload hashes.
- Installation activated
  `apple-appdev-workflow@apple-developer-tools`, disabled the conflicting
  identity in the Xcode home, and left the `LocalAppleWorkflow` cache intact.
- The active stock Xcode Codex agent remained the signed `codex-cli 0.140.0`
  binary selected by Xcode build `27A5209h`.
- Release packaging bound the artifact to a clean companion commit and would
  have rejected a dirty or non-git source tree.

The exact install rollback snapshot is:

```text
/Users/joshuakaunert/Library/Developer/Xcode/CodingAssistant/codex/.tmp/plugins/quarantine/apple-appdev-workflow/0.2.0-plugin-install-20260730T070446Z
```

## Hook Trust

The installer did not pre-trust either hook. Stock Codex's hook browser showed
both hooks active after explicit review:

```text
UserPromptSubmit command: node "$PLUGIN_ROOT/hooks/apple_router.mjs"
UserPromptSubmit trust hash: sha256:1c82a273ee2e6d13245f8ade4bff516ecb8d46b623c96c22e4e572a8edb87711

Stop command: node "$PLUGIN_ROOT/hooks/apple_contract_guard.mjs"
Stop trust hash: sha256:0ed272c8c1d1eb54f0342f83d3cb690a70448b72397b3fd1c53ffd191cc6bc78
```

Only `Stop` appeared as a new or changed definition in this upgraded home.
`UserPromptSubmit` retained trust because its command definition and trust hash
were unchanged. A clean home still requires review of both.

## Stock Xcode Gate

The exact installed payload was evaluated with Xcode 27.0 build `27A5209h`
and stock `codex-cli 0.140.0`.

### Exact-home correction smoke

A non-interactive stock-agent smoke used Xcode's real CodingAssistant Codex
home without the hook-trust bypass flag. Session
`019fb1db-47fb-75b0-a834-0a2e5b747d2e` proved the complete correction path:

1. `UserPromptSubmit` injected
   `apple-appdev-workflow:apple-app-orchestrator`.
2. The model emitted the intentionally requested malformed answer `Done`.
3. The installed `Stop` hook at
   `apple-developer-tools/apple-appdev-workflow/0.2.0` blocked it once.
4. The corrected final answer began with `Routing: orchestrator-led` and
   contained a fully qualified `Activated skills` block.
5. The guard did not loop.

### Fresh Xcode-host smoke

A fresh Codex agent conversation was created inside Xcode after installation
and trust review.

```text
Xcode conversation: 3AD6E5A3-3198-48DA-A480-E3A19D04B910
Codex session: 019fb1e1-bdf1-7693-b5de-92243197bfa5
conversationType: assistant
assistantKind: agent
modelIdentifier: codex
app-server PID: 50884
app-server parent Xcode PID: 31455
```

The broad marked turn `XCODE-DUAL-HOOK-LIVE-SMOKE-20260730-0216` routed to
`apple-appdev-workflow:apple-app-orchestrator`. Its final answer began with the
canonical routing line and preserved these fully qualified skills:

```text
apple-appdev-workflow:apple-app-orchestrator
apple-appdev-workflow:apple-release-orchestrator
apple-appdev-workflow:apple-testing-quality-gates
apple-appdev-workflow:apple-review-hardening
apple-appdev-workflow:apple-manual-validation
apple-appdev-workflow:apple-build-release-ops
```

The response was already compliant, so `Stop` correctly remained silent. A
same-conversation focused-specialist control selected
`apple-appdev-workflow:apple-decision-stress-test` with
`Routing: explicit-specialist`. Its requested `Done` response was not rewritten
because final-contract enforcement is intentionally limited to turns whose
selected owner is `apple-appdev-workflow:apple-app-orchestrator`.

### Preserved matrix

The immutable nine-case Xcode host matrix was rescored against the newly
installed `apple-developer-tools/0.2.0` payload. All nine cases passed with zero
scorer errors:

1. natural Apple request
2. plugin chip
3. explicit top-level skill chip
4. explicit domain-orchestrator chip
5. explicit focused-specialist chip
6. Xcode host-context routing for a non-Apple authored prompt
7. resumed conversation routing
8. foreign-plugin negative control
9. trusted concurrent-hook composition

The historical manifest still named the retired
`LocalAppleWorkflow/0.1.1` install root. Its first rescore therefore failed
preflight before case scoring. The derived qualification manifest changed only
`host.installedPluginRoot` to the installed
`apple-developer-tools/apple-appdev-workflow/0.2.0` path; the immutable session,
conversation, trust-transition, and attribution evidence remained unchanged.

## Distribution Decision

This candidate is **ready only for narrower distribution** from the private
companion repository. It is not yet a public launch.

The current limitations are:

- the public `jkaunert/apple-appdev-workflow` repository remains frozen for the
  Build Week judging window;
- hook trust remains an explicit post-install user action;
- the exact dual-hook candidate passed command-line install, stock-agent, and
  Xcode-host routing checks, but its native Finder dialog flow was not manually
  repeated after the dual-hook payload change;
- a manual VoiceOver gesture walkthrough and older-supported-macOS pass remain
  pending; and
- a public companion release and cross-link should be created independently,
  followed by a public-plugin documentation PR after the freeze ends.

The package must not be described as replacing Xcode's Codex agent. It installs
only the validated `xcode-headless` plugin profile and leaves the stock agent
active.
