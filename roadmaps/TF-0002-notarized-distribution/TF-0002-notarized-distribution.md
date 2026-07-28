**English** · [日本語](TF-0002-notarized-distribution-ja.md)

# TF-0002 — Developer ID signing & notarization

<!-- TF-METADATA -->
| Field | Value |
|---|---|
| Proposal | [TF-0002](TF-0002-notarized-distribution.md) |
| Author | [@akidon0000](https://github.com/akidon0000) |
| Status | **Proposal** |
| Topic | Distribution |
| Origin | Gatekeeper warnings reported by v0.0.1 testers |
<!-- /TF-METADATA -->

## Introduction

Sign releases with a Developer ID Application certificate and notarize them, so downloaded
builds launch without the "Apple could not verify…" Gatekeeper warning.

## Motivation

Releases are currently ad-hoc signed. Every downloader hits the Gatekeeper block and needs a
workaround (right-click → Open, "Open Anyway", `xattr -d com.apple.quarantine`, or a curl
download). Real testers already stumbled on this — it is the single biggest friction in
sharing the app.

## Detailed design

Prerequisite: Apple Developer Program membership (US$99/year).

- **Certificates & secrets.** Store the Developer ID Application certificate (`.p12`) and an
  App Store Connect API key as GitHub Actions secrets.
- **Release workflow** ([release.yml](../../.github/workflows/release.yml)):
  1. `codesign --options runtime` with the Developer ID identity (hardened runtime is required
     for notarization) — replaces the current `--sign -` in `scripts/release.sh`.
  2. `xcrun notarytool submit --wait` the zip.
  3. `xcrun stapler staple` the app, then re-zip for upload.
- **Local fallback.** `scripts/release.sh` keeps working without the certificate (ad-hoc) so
  local packaging never requires the secrets.
- **README.** Drop the Gatekeeper-workaround instructions once notarized releases ship.

## Alternatives considered

- **Status quo (ad-hoc + workaround docs)** — free, but every new user pays the friction.
- **Mac App Store** — blocked until the python3 subprocess is gone ([TF-0001](../TF-0001-native-swift-cost-analysis/TF-0001-native-swift-cost-analysis.md)).
- **Homebrew cask** — eases install but does not remove Gatekeeper's verdict on unsigned apps.

## Progress

- [ ] Enroll in the Apple Developer Program
- [ ] Add certificate + API-key secrets to the repository
- [ ] Sign / notarize / staple steps in release.yml, with local ad-hoc fallback
- [ ] Update README install instructions

## References

- [Notarizing macOS software before distribution](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)
- A draft Developer ID + notarization script existed as `release.sh` at the repo root (removed 2026-07; recoverable from git history) — reusable as a starting point.
