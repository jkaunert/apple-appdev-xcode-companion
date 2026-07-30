# Release Qualification

## Candidate

The current private dual-hook candidate is:

```text
version: 0.2.0
app build: 3
companion source commit: 7b236ef06b8d6e7f8453a66d23cd8bc0055a155a
companion source dirty at package time: false
plugin source commit: b176905b88ac3b21827f088d8a8c1b5b4c044a23
DMG: AppleAppDevXcodeHeadlessInstaller-0.2.0.dmg
DMG SHA-256: 7e29121fd151e27d727911ee77012b0ff0e854b9eef1a923307714069c9549dd
installer executable SHA-256: 9aa24ca130dde17bef1440925462708c92c14570db3462d6e8f5e9bb4050c2f7
Developer ID: Joshua Kaunert (HSRQC9N69B)
notary submission: 613937d6-6c4c-4176-a071-67e0a6e8ffe9
notary status: Accepted
plugin manifest SHA-256: 0b52bbc68aa8d534124d66b8f3ea5c7307bd020d103ababa5e74b0de2e5c5f9d
routing core SHA-256: 565f1089fadaa4594a8d97f473610a3783a0f5e3c99f35c9123c02facf5e4257
```

Build 3 supersedes the earlier notarized package from companion commit
`f1083157624fc381328dc246abd9686827ecd2d4`. That package named only
`UserPromptSubmit` in its native confirmation and completion dialogs. The
replacement changes only those two sentences and adds a source-contract
regression test. The embedded profile and routing-core hashes are unchanged.

Gatekeeper accepted both the DMG and its mounted installer app as notarized
Developer ID software. Strict deep code-signature verification, DMG stapler
validation, and mounted-app verification passed.

The package contains a physical, symlink-free `xcode-headless` profile and no
replacement Codex agent, bundled MCP proxy, plugin-managed MCP server, or
retired `routerSelection`.

## Installer Gates

- All 17 focused installer tests passed.
- Swift type-checking and shell syntax checks passed.
- The mounted embedded profile was byte-identical to the clean render from the
  pinned plugin source commit and passed bundle validation.
- Exact-package dry-run and native Finder install completed from the mounted
  notarized DMG.
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
/Users/joshuakaunert/Library/Developer/Xcode/CodingAssistant/codex/.tmp/plugins/quarantine/apple-appdev-workflow/0.2.0-plugin-install-20260730T234612Z
```

## Native Finder And VoiceOver Gate

The exact build-3 DMG was mounted after its executable hash was matched to the
sidecar manifest. Xcode was closed for the complete install transaction.

The confirmation alert visibly and accessibly disclosed:

```text
It does not replace Xcode's Codex agent or pre-trust either lifecycle hook:
UserPromptSubmit or Stop.
```

VoiceOver announced the alert and informative text, then reached `Cancel,
button` and `Install, default, button`. `Install` was activated with the
VoiceOver gesture. The completion alert visibly and accessibly disclosed:

```text
Before opening Xcode, use stock Codex to review and trust each lifecycle hook:
UserPromptSubmit and Stop.
```

VoiceOver reached `Copy Rollback Path, button` and `Done, default, button`.
After `Done`, the installer exited and VoiceOver was restored to off.

Selected screenshot hashes:

```text
confirmation with VoiceOver: e2afa9c22e35a177b34446401020003b5fee3223da0540a14521fad90779b543
Install button with VoiceOver: 2364c8b1aa2ad5483896a4b81dabf60e2c891e002bb9fd59dc97a13c8b8e5900
completion with VoiceOver: 40e289bb7b6094f6e36642eda5d1710711f487b4a7b5b3571fcf76c4f692c494
Done button with VoiceOver: 1325d58a793a3ccf455d83e4271afcc28da7176a70948043e361499598709064
VoiceOver restored off: b7d816462742581137f64c9b44dc0a2133906eab30b3c5f463347b42d9b77626
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

The routing payload embedded in build 3 is byte-identical to the payload
evaluated with Xcode 27.0 build `27A5209h` and stock `codex-cli 0.140.0`.
The exact installed build-3 profile was rechecked before the preserved matrix
was rescored.

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

The immutable nine-case Xcode host matrix was rescored again against the exact
build-3-installed `apple-developer-tools/0.2.0` payload. All nine cases passed
with zero scorer errors:

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

The regenerated build-3 report has SHA-256
`a78a999e0a8f9a5aeb4ae9902d31f8965daf9f4d54ae466b8aa7c13c6435aa90`,
which is byte-identical to the prior passing report. This is evidence that the
installed routing payload stayed unchanged; it is not a new Xcode-host
conversation.

## Distribution Decision

This candidate is **ready only for narrower distribution** from the private
companion repository. It is not yet a public launch.

The current limitations are:

- the public `jkaunert/apple-appdev-workflow` repository remains frozen for the
  Build Week judging window;
- hook trust remains an explicit post-install user action;
- the exact build-3 package passed native Finder and VoiceOver installation,
  but a fresh Xcode-host conversation has not yet been captured for this
  installer-copy-only rebuild;
- an older-supported-macOS pass remains pending; and
- the independent companion release packet is prepared but no tag, GitHub
  release, or repository-visibility change has been published.

The package must not be described as replacing Xcode's Codex agent. It installs
only the validated `xcode-headless` plugin profile and leaves the stock agent
active.
