# SpaceBar Distribution Prep

| Field | Value |
|-------|-------|
| **Product** | SpaceBar |
| **Status** | Checklist only — not implemented in the app |
| **Related** | [BRD.md](BRD.md) §11, [PRD.md](PRD.md) §11, [OPEN_PRODUCT_DECISIONS.md](OPEN_PRODUCT_DECISIONS.md) DEC-008 |
| **Date** | 21 August 2026 |

Until this checklist is complete, **do not promote unsigned downloads** beyond contributor build-from-source. Gatekeeper and spoofing risk outweigh convenience.

---

## Current posture (DEC-008 = A)

- Hardened Runtime is enabled in the Xcode project.
- README documents building with XcodeGen / `xcodebuild` and opening the Debug `.app`.
- No Sparkle dependency, Homebrew cask, or notarization automation ships in this repository yet.

---

## 1. Apple Developer ID + notarization

Prerequisites:

- [ ] Apple Developer Program membership
- [ ] Developer ID Application certificate installed in the signing keychain
- [ ] App-specific password or API key for `notarytool`

Release build sketch (run locally; secrets never committed):

```bash
# Archive / export a Developer ID–signed .app, then:
xcrun notarytool submit SpaceBar.zip --apple-id "$APPLE_ID" --team-id "$TEAM_ID" --password "$APP_PASSWORD" --wait
xcrun stapler staple SpaceBar.app
```

- [ ] Document exact archive scheme and export options used by the maintainer
- [ ] Verify Gatekeeper accepts the stapled app on a clean Mac (`spctl --assess`)

---

## 2. Homebrew cask

- [ ] Decide cask name (e.g. `spacebar`) and homepage / livecheck strategy
- [ ] Host notarized artifacts (GitHub Releases recommended)
- [ ] Open a Homebrew/homebrew-cask PR with `url`, `sha256`, and `app "SpaceBar.app"`
- [ ] Add CI or a release script that updates the cask SHA on each tag

---

## 3. Sparkle (in-app updates)

- [ ] Choose Sparkle major version and add as SPM/Xcode package **only when ready to ship updates**
- [ ] Generate EdDSA key pair; store private key offline (never in git)
- [ ] Host `appcast.xml` + signed archives
- [ ] Wire Sparkle updater UI and sandbox/hardened-runtime exceptions as required by Sparkle docs

Do **not** add the Sparkle package to this repo until the feed and signing keys exist.

---

## 4. Related Phase 3 product features (not started)

Tracked in BRD/PRD backlog; implement only after distribution posture is clear:

| Item | Notes |
|------|-------|
| Launch at login | Prefer `SMAppService` after notarized builds exist |
| Move caches to Trash | Reversibility vs immediate free space trade-off |
| Custom cleanup paths | Needs `DeletePathGuard` redesign |
| Localization | String catalogs; screenshot name heuristics today are English-centric |
| Multi-volume picker | Free space today is startup volume (`/`) only |
| Dry-run mode | Estimate without delete |
| Scheduled auto-clean | Explicitly deferred — conflicts with confirm-gated safety model |

---

## Gate before marketing

1. Notarized + stapled build available from a trusted host  
2. README install path updated (cask and/or signed download)  
3. First-run primer already covers FDA / Automation / permanent delete (shipped in Phase 2)

*This file is preparation only. Completing the checkboxes is a release-engineering project, not an in-app feature toggle.*
