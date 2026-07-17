# CLAUDE.md

PodRadar is a native iOS Bluetooth device finder — a clone of PodSpot: Find
My Headphones (App Store id1611422396, ~$5k/mo MRR verified via trustmrr,
abandoned since Jan 2024), differentiated with a last-known-position map.
Full product scoping in [SPEC.md](SPEC.md); ASO/positioning/pricing
research in `app-marketing-context.md` (gitignored while the repo is
public — see below).

**This project reuses the RepLock/Loopa dev strategy wholesale**
(`C:\Users\awdia\OneDrive\Bureau\replock` and
`C:\Users\awdia\OneDrive\Bureau\contraceptive pill reminder\loopa` — read
their CLAUDE.md for hard-won pipeline lessons before debugging anything
CI/device related).

## The one constraint that shapes everything: NO MAC

Development happens 100% from this Windows machine. No local Xcode, no
simulator, no local build. Never suggest opening Xcode or running
xcodebuild locally.

The loop is: edit Swift here → CI builds on GitHub Actions → install IPA
over USB → user tests on his iPhone and reports back (in French). A device
iteration costs ~15 min, so **push logic into the unit-tested pure-Swift
core (`PodRadar/Core/`) whenever possible** — CI tests are the cheap
iteration path.

⚠️ BLE scanning itself is the one thing that can NEVER be validated in
CI/simulator — CoreBluetooth central scanning needs real hardware. Every
change to `Services/BLEScanner.swift` or proximity tuning
(`ProximityEngine.attackSmoothing`/`releaseSmoothing`/`pathLossExponent`)
requires a device test.

Field lesson (2026-07-17, first device test): reaching 100% on close
approach worked, but felt laggy. A single symmetric EMA (`smoothing: 0.3`
both directions) takes several samples to converge on a step change.
Fixed with **asymmetric attack/release** — fast when a sample says
"closer" (`attackSmoothing: 0.6`), slow when it says "farther"
(`releaseSmoothing: 0.25`) — human perception tolerates a snappy
"getting warmer" far more than flicker on "getting colder", so the two
directions don't need matching time constants. Pinned by
`ProximityEngineTests.testAttackIsFasterThanRelease`.

Second field lesson (same day, next test): the fast attack factor let raw
RSSI noise pass through almost unfiltered, so the reading "jumped around
a lot" with the phone held perfectly still — real BLE RSSI wobbles ±5-10
dB sample-to-sample even stationary (multipath, 3-channel advertising
hop), that's not a bug. Added a **median-of-3 pre-filter** in front of
the EMA: single-sample outliers (either direction) get rejected outright,
a change needs 2 consecutive samples to register. Pinned by
`testMedianPreFilterRejectsASingleNoiseSpike` /
`…AcceptsASustainedChange`. Pending re-test on device (2nd iteration).
Keep the actual signal math in `Core/ProximityEngine.swift` (pure, tested)
and treat `Services/BLEScanner.swift` as a thin, boring wrapper so there's
as little untestable surface as possible.

## Build, test, deploy

```bash
# CI tests run automatically on push to main.

# Device build (signed IPA): cancel the duplicate push-triggered run first —
# two concurrent macOS runs contend for runners.
git push
PUSH_RUN=$(gh run list --workflow=ios.yml --limit 1 --json databaseId --jq '.[0].databaseId')
gh run cancel "$PUSH_RUN"
gh workflow run ios.yml -f export_method=debugging

# When green: download + install (iPhone plugged in over USB, unlocked)
gh run download <RUN_ID> --name PodRadar-ipa --dir /c/Users/awdia/replock-signing/ipa
py -3.12 -m pymobiledevice3 apps install /c/Users/awdia/replock-signing/ipa/PodRadar.ipa

# TestFlight build (OTA install, no USB):
gh workflow run ios.yml -f export_method=app-store-connect
# Requires the ASC app record to exist. Build number = Actions run number.
```

Device-install gotchas (all field-tested on RepLock/Loopa — see their
CLAUDE.md for details): `pymobiledevice3` needs Python 3.12; if the device
isn't detected, restart the Windows Apple stack (kill `AppleDevices*`
processes, relaunch "Appareils Apple", replug); if `apps install` hangs
silently, reboot the iPhone; never run two installs concurrently; `gh run
watch` can die on network blips while the run is still fine.

The Xcode project is **generated** from [project.yml](project.yml) by
XcodeGen in CI — `PodRadar.xcodeproj` is gitignored. To add files/targets,
edit `project.yml`.

## Repo visibility

Keep public during development (free unlimited macOS Actions minutes —
shared quota with RepLock/Loopa, watch for exhaustion near month-end).
**Flip private before submission**: `gh repo edit <owner>/podradar
--visibility private`. Marketing docs are gitignored while public. Always
cancel duplicate push-triggered device runs.

## Apple configuration

| Item | Value |
|---|---|
| Team ID | `8L8G4P4Z9X` (GitHub variable `APPLE_TEAM_ID`, shared with RepLock/Loopa) |
| Bundle ID | `com.awdia.podradar` |
| App Group | `group.com.podradar.app` — **NOT YET CREATED in the portal.** First archive attempt (2026-07-17) failed with "Provisioning profile doesn't match the entitlements file's value for the com.apple.security.application-groups entitlement" — automatic signing can't register an App Group that doesn't exist yet (same issue RepLock/Loopa hit). Entitlements removed from project.yml until the user creates the group manually in the portal; DeviceStore.swift already falls back to `UserDefaults.standard` so nothing breaks meanwhile. Re-add the entitlements block once created. |
| Subscriptions | `com.awdia.podradar.pro.weekly` — **launch at 2,99 €/wk** (matches PodSpot's live paywall price, the proven revenue benchmark — see app-marketing-context.md), 3-day free trial; raise/A-B test toward 4,99 € once real subscribers validate the funnel; `com.awdia.podradar.pro.yearly` — 29,99 €/yr anchor (to create in ASC at M4) |
| Test device | Same iPhone 16 Pro Max already registered in the portal (RepLock) |
| Signing | Same certs/API key as RepLock/Loopa — GitHub secrets `CERT_P12_BASE64`, `CERT_DIST_P12_BASE64`, `CERT_P12_PASSWORD`, `ASC_*` (must be re-added to THIS repo — secrets don't carry across repos). Local material in `C:\Users\awdia\replock-signing\` — never commit. |
| Permissions | `NSBluetoothAlwaysUsageDescription`, `NSLocationWhenInUseUsageDescription` (map feature only, no background location) |

No FamilyControls/camera entitlements needed (unlike RepLock) — Bluetooth
+ location are standard entitlements, no special portal approval expected.

## Architecture

```
PodRadar/            SwiftUI app
  PodRadarApp.swift  Wires BLEScanner → LocationRecorder on stale-device
                      events, loads StoreKit products at launch
  Views/              RootView (3-tab shell), RadarView (live device list +
                      proximity %), MapView (last-known-position pins),
                      SettingsView (subscription status)
  Core/               Pure, CI-tested: ProximityEngine (RSSI smoothing →
                      proximity % + hot/cold trend), BLEDevice model,
                      DeviceRegistry (sighting upsert, staleness, last-
                      known-location attach — ALL device/proximity logic
                      goes HERE, never in Services)
  Services/           Side effects: BLEScanner (CoreBluetooth central,
                      thin — see NO MAC warning above), LocationRecorder
                      (CoreLocation, When-In-Use only), DeviceStore
                      (UserDefaults/App Group persistence for favorites),
                      SubscriptionManager (StoreKit 2, ported from RepLock)
  Design/             Theme.swift — PRColor navy/signal-teal/alert system,
                      placeholder palette, swap before submission
  Assets.xcassets/    AppIcon (empty placeholder — real artwork TBD)
Shared/               Localizable.xcstrings — will compile into the app;
                      widget extension (if added later) reuses it
PodRadarTests/        Unit tests (ProximityEngineTests, DeviceRegistryTests)
```

## Conventions (inherited from RepLock/Loopa — keep them)

- Commit style: imperative subject + short why-paragraph; end with
  `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`.
- Code, comments, and commits in English; the user reports in French.
- **Localization is mandatory — never hardcode user-facing copy.** English
  literals are the keys; catalog in
  [Shared/Localizable.xcstrings](Shared/Localizable.xcstrings). SwiftUI
  `Text("…")` localizes automatically; everything else uses
  `String(localized:)`. Every new user-visible string gets a catalog entry
  in the same commit. Target languages before submission: en (source), fr,
  es, de, it, pt-BR — multi-language is this app's biggest ASO edge over
  PodSpot (English-only), so don't defer it like RepLock did.
- No emojis in UI — SF Symbols only. Design must never look cheap.
- Repo lives in a OneDrive-synced folder — if git behaves strangely
  (locks, phantom changes), suspect OneDrive sync first.
- Never market detection of powered-off devices or closed AirPods cases —
  the Find My protocol is private to Apple; PodRadar only sees BLE
  advertisements from devices that are on and in range.

## Status / roadmap (details in SPEC.md)

- [~] M0 — pipeline: project.yml, GitHub Actions workflow, Core (with
      tests), Services, minimal 3-tab shell all scaffolded 2026-07-17.
      Pending: first CI run, GitHub repo creation + secrets, first signed
      IPA on device.
- [ ] M1 — BLE scanning validated on real device (proximity feel tuning)
- [ ] M2 — device list polish (naming, favorites, ignore-list)
- [ ] M3 — last-known-position map wired end to end
- [ ] M4 — onboarding + hard paywall (StoreKit 2 products live in ASC)
- [ ] M5 — 6-locale localization
- [ ] M6 — submission prep
