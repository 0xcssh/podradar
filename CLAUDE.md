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

**Critical lifecycle bug (2026-07-17, 3rd field test):** scanning silently
died in two ways, both now fixed:
1. `BLEScanner.startScanning()` used to no-op if `central.state` wasn't
   already `.poweredOn` — but a fresh `CBCentralManager` starts in
   `.unknown` and only reaches `.poweredOn` asynchronously a moment later.
   Calling `startScanning()` from a view's `.onAppear` (which fires
   immediately) could lose the race and scanning would just never start,
   with zero UI indication (the "Scanning for nearby devices…" empty
   state looks identical whether it's about to find something or dead
   forever). Fixed with a `wantsToScan` flag: `centralManagerDidUpdateState`
   now retries `beginScan()` itself once the radio is actually ready.
2. `RadarView` used to call `scanner.stopScanning()` from `.onDisappear`.
   Pushing `DeviceFinderView` via `NavigationLink` fires `.onDisappear` on
   the screen underneath it (SwiftUI/NavigationStack behavior) — so
   opening the exact screen that needs LIVE proximity updates the most
   was killing the scan, freezing the reading at whatever it was the
   instant you tapped in (field-reported: percentage frozen at 63% for
   the entire time on DeviceFinderView, haptics imperceptible because
   they kept firing at that one stale interval forever). Fixed by moving
   the scan lifecycle to `RootView` (start once, tied to
   `scenePhase`/foreground-background, not to any individual tab/screen)
   — BLE scanning is cheap enough to just run for the whole foreground
   session.

Also added a real "Bluetooth is off/unauthorized/unsupported" UI state in
RadarView (with an Open Settings button for the unauthorized case) — it
used to fall through to the same silent "Scanning…" text as the normal
not-found-yet-state, giving zero signal that anything was actually wrong.

**Name-probe feature (2026-07-19):** field-asked "can we fix Unknown
device, be more precise?" Most BLE peripherals never include a name in
their passive advertisement (only Apple's proximity-pairing beacon is
reliably identifiable that way, confirmed 2026-07-17) — the real name
lives in the standard Generic Access service (0x1800) / Device Name
characteristic (0x2A00), which requires briefly CONNECTING to read (no
pairing/bonding). `BLEScanner` now does this automatically for any
unnamed device strong enough to matter (same -70dBm floor as the Devices
list), once per device per session (`nameProbeAttempted`), with a 4s
timeout and always disconnecting afterward — connect/discoverServices/
discoverCharacteristics/readValue/disconnect via `CBPeripheralDelegate`.
Learned names go through `DeviceRegistry.updateDiscoveredName` (separate
from `rename`'s user-chosen `customName` — this is what the device calls
ITSELF). Needs device validation: does this actually resolve names for
non-Apple earbuds/trackers in the field, and does connecting to many
devices at once cause any radio contention with the RSSI scan itself?

**Follow-up round (same day, comparing against the reference app
directly):**
1. "Can't see your device?" did nothing when tapped — added
   `CantSeeDeviceView`, a bottom sheet with the same 4 troubleshooting
   tips as the reference (AirPods not in case, device powered on,
   battery left, in signal range).
2. The Devices list had visibly FEWER entries than the reference app's
   screenshot, which shows every visible device (including ones badged
   red "FAR") instead of hiding weak signals. The RSSI floor added
   2026-07-19 was a filter; reverted to a UI-only badge
   (`DeviceRegistry.nearBadgeThresholdRSSI`, renamed from
   `listMinimumRSSI`) — `inRangeDevices` no longer filters by signal
   strength at all, only staleness + ignored. `DevicesListRow` computes
   NEAR (teal) vs FAR (red) per-row from the live smoothed RSSI reading.
3. "La connexion n'a pas l'air fiable" — asked for real research into an
   alternative, not just a retry bandaid. Researched: verified real
   Bluetooth SIG company-ID assignments (via Nordic Semiconductor's
   bluetooth-numbers-database) and added `Core/ManufacturerBrand` — a
   zero-connection brand guess ("Samsung Device", "Sony Device", etc.)
   parsed from the SAME manufacturer-data bytes the RSSI reading already
   comes from, exactly as reliable as proximity itself. The connect-based
   GATT probe is demoted from "run automatically for every unnamed
   device in the background" (likely radio contention between the
   continuous active scan and simultaneous connects, plus some
   peripherals are simply non-connectable advertisers) to "on-demand,
   single-target, triggered only when the user opens that ONE device in
   DeviceFinderView" (`BLEScanner.probeNameIfNeeded`) — far less radio
   contention, and it's now a bonus on a screen the user is already
   engaged with rather than a reliability promise for the whole list.
   `didDiscover` now stores every seen `CBPeripheral` in
   `knownPeripherals` so the probe can reconnect long after first sighting.

**"Can't see your device?" sheet layout (2026-07-19):** `.presentationDetents([.medium])`
left a large empty gap below the 4 short tips. Switched to
`.presentationDetents([.height(430)])` sized to the actual content,
dropped the trailing `Spacer()`.

**Map tab lesson (2026-07-19):** field-reported as "doesn't work at
launch, only works once I've found a device." Root cause was MapView only
branching on `.notDetermined` — denying (or "Allow Once", which reverts)
the location prompt fell through to a plain, pin-less Map with zero
explanation and no way to recover (iOS never re-prompts once denied,
Settings is the only path). Also, even once authorized, an empty
`devicesWithLocation` showed a blank Map instead of an empty state,
reading as broken. Fixed with an explicit switch over
`CLAuthorizationStatus` (notDetermined → prompt, denied/restricted →
Open Settings state, authorized + empty → "No locations yet" empty
state, authorized + non-empty → the actual Map).

**Curve + latency lesson (2026-07-17, 4th field test):** "75% → 100% with
huge latency, not progressive." Two compounding causes, both fixed:
1. `proximityScore` used a path-loss formula that PLATEAUED at -50dBm —
   any RSSI at or beyond that threshold scored exactly 1.0, so the last
   stretch of a real approach had no headroom to climb through; it looked
   stuck then "jumped" once the smoothed value finally crossed -50dBm.
   Replaced with a plain continuous ramp (smoothstep) between `farRSSI`
   (-90, 0%) and `closeRSSI` (-35, 100%) — no plateau anywhere in
   between. Pinned by `testProximityScoreHasNoPlateauNearMax`.
2. The median-of-3 pre-filter (added to fix stationary jitter) required 2
   matching samples before accepting ANY change, including a real fast
   approach — that's what felt like "huge latency". Added a bypass: a
   single-sample deviation ≥15dB (far beyond ordinary multipath jitter,
   which the earlier fix targeted) skips the median gate and goes
   straight to the EMA, so genuine movement registers in 1 sample while
   small stationary noise still gets filtered. `attackSmoothing` also
   bumped 0.5→0.6. Pinned by `testLargeJumpBypassesMedianForFastResponse`.

**List-flooding lesson (2026-07-19):** the Devices list showed 9-10
entries at once (mostly "Unknown device") instead of revealing devices
progressively like the reference recording — every BLE peripheral in the
building was being listed regardless of signal strength. Fixed with
`DeviceRegistry.listMinimumRSSI` (-70dBm default): `inRangeDevices` now
filters weak signals, not just stale ones. Tune from field feedback (a
stricter floor = fewer, more-plausible results but risks hiding a genuine
target device that's just far away in the same room). Pinned by
`testWeakSignalDevicesExcludedFromList`. Two duplicate "AirPods Pro"
entries were also observed in the same field test (possibly the left/
right earbud each broadcasting separately, or two different people's
AirPods, or Apple's Bluetooth address rotation — not root-caused yet; the
RSSI floor alone should reduce it but if it persists, revisit).

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
