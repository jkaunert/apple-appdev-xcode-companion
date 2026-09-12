# Apple AppDev Xcode Companion 0.2.2-beta.2 Qualification

This record covers the exact signed package and Xcode qualification evidence
for the documentation-focused beta. It is independent of the immutable
`0.2.2-beta.1` package.

Required evidence:

- clean companion source commit
- exact paired plugin profile and source hash
- Developer ID signing, notarization, stapling, and Gatekeeper acceptance
- explicit review/trust of both lifecycle hooks
- rollback and active-agent preservation
- Xcode 27 Beta 5 contract-v3 matrix

Result: all required package and host gates passed.

- companion source: `a40df27419e374e36833f0ab1282c8b4598bac70`
- paired private plugin source: `2b954c49bd1df757405d74a2cd0c5d9cdfbdcc24`
- merged companion release source: `729cbdd28b2db92f7a558caa09665195292f80d3`
- DMG SHA-256: `678aafb3191691f27da2faa30c668ef3fb3d3554e985b4d983136ed632f156f9`
- notarization: `dc9ae04b-89fc-43db-a2af-3b682466c41b` (Accepted)
- Xcode matrix report: `0e102b4d322a9bb4c29092a53bbd908f5863d183afb454a9329907237b9bac01`
