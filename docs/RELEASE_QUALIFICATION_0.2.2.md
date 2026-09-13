# Apple AppDev Xcode Companion 0.2.2

This record describes the stable build-3 companion release. The Marketplace
plugin and the Xcode companion are separate release surfaces.

## Artifact

```text
version: 0.2.2
app build: 3
minimum macOS: 15.0
source commit used to build the DMG: d36acc1632705b135aaae312e4b77c2b6812901b
source dirty at package time: false
DMG: AppleAppDevXcodeHeadlessInstaller-0.2.2.dmg
DMG SHA-256: af2a930bb849ac2565ad45ed19baa9ff8e4995fba7b2ae50451801464acc9499
sidecar SHA-256: 84697e86335b993957e5fc745a60c141c23ed0c76a14a76ddafc181a854c657f
installer executable SHA-256: c7079f8db976777dfd874e86eb32f6b57770f890b18d2adc1201caf73879dbfb
Developer ID: Developer ID Application: Joshua Kaunert (HSRQC9N69B)
notary submission: 358ccd83-f74e-4990-8b06-96b184638461
notary status: Accepted
```

The DMG is stapled and passes `xcrun stapler validate`, strict deep code-sign
verification, and Gatekeeper assessment as notarized Developer ID software.
The sidecar is distributed beside the DMG and is the authoritative source for
the embedded profile, routing-core hashes, and official Node runtime pins.

## Host qualification

The stable profile passed the 11-case qualification-contract-v3 matrix on both
supported Xcode hosts:

| Host | Xcode build | Bundled Codex | Result |
| --- | --- | --- | --- |
| Xcode 27.0 RC | `27A266a` | `0.145.0` | 11/11 pass |
| Xcode 26.6 | `17F113` | `0.140.0` | 11/11 pass |

The matrices prove deterministic top-level routing, explicit macOS and Swift
Package prompt provenance, neutral workspace fallback, resume continuity,
trust transitions, and pre-assistant injection. Their manifest/report hashes
are recorded in the paired plugin release contract.

The live matrices were captured with the same stable 0.2.2 rendered profile and
hook-runtime source. The final public DMG is a subsequent clean-checkout
repack after documentation and test-fixture-only changes; its signed runtime
hash is intentionally distinct. The final DMG independently passed package
install, sanitized-PATH `UserPromptSubmit`/`Stop` postflight, rollback, and
Gatekeeper checks.

## Distribution boundary

The companion installs only the physical `xcode-headless` profile and its hook
runtime into Xcode's separate Codex home. It does not install or update
XcodeBuildMCP, Sosumi, Memory MCP, a proxy, or a Codex agent, and it does not
modify ordinary Codex homes. Hook trust remains an explicit user decision.
