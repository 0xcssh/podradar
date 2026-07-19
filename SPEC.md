# SPEC — PodRadar

Clone of PodSpot: Find My Headphones (App Store id1611422396, ~$5k/mo MRR,
abandoned since Jan 2024 — see app-marketing-context.md for the full
competitive analysis). Native iOS, Bluetooth Low Energy device finder with
a differentiating last-known-position map.

## Core loop

1. User opens the app because they just lost an earbud/headphone.
2. Radar tab scans all nearby BLE peripherals, shows a live list sorted by
   proximity (closest first), with a hot/cold trend per device.
3. Tapping a device opens `DeviceFinderView`: a full-screen pulsing radar
   visual, live percentage, and haptic pulses that speed up/intensify
   with proximity (`Core/HapticPulse`, CI-tested) — shipped 2026-07-17.
   This is what makes an "Unknown device" sighting still useful: most BLE
   peripherals never broadcast a name in their advertisement (only Apple's
   proximity-pairing beacon is reliably identifiable, field-confirmed the
   same day), so the user doesn't need to know WHAT a signal is, just
   whether walking toward it makes the pulses faster.
4. If a device goes stale (not heard from in ~8s) while the app has
   location permission, PodRadar stamps its last-known GPS position —
   visible later on the Map tab. This is the answer to the niche's #1
   complaint ("useless once the device goes out of range/off").

## Full flow rebuild to match PodSpot exactly (shipped 2026-07-19)

User shared paid + free screen recordings of PodSpot's actual flow and
asked for the same design AND functionality, not just inspiration.
Rebuilt around it end to end:

- **Devices list** (was: dark live list) → light gray/white screen, white
  card rows (icon, name, generic "NEAR" pill — no live percentage; that
  precision is the paid feature), "Tap on your device to track down its
  precise location" subtitle, "Can't see your device?" button, X to close
  back to the hero screen. Swipe-to-ignore/favorite preserved from M2.
- **Paywall** (was: a stub) → real `PaywallView`: blue radar-pulse hero,
  "Pinpoint Your Device's Exact Location" headline, "Unlock Premium"
  badge, 3 checkmarked bullets, sticky trial CTA wired to
  `SubscriptionManager.purchase()` with live price/trial text from
  StoreKit, "Already Subscribed?" restore link. Gates every device tap:
  subscribed → `DeviceFinderView`, free → paywall sheet.
- **DeviceFinderView** → background now tints continuously from red
  (far) to green (close) as proximity rises (`PRColor.proximityBackground`),
  concentric target rings derived from that one color via `lightened(by:)`,
  "Found it!"/"Cancel" buttons (was: a static navy screen with a
  teal-only ring).
- **Found it! → Save Location** (new): confirmation alert, then a
  description field + MapKit preview + Save Location button, matching
  PodSpot's screen exactly. Writes into the same `LastKnownLocation` (now
  with an optional `note`) the Map tab / Previous Locations already read —
  this IS M3's last-known-position feature, just reached through the
  "Found it!" flow instead of automatic staleness detection alone (both
  paths write the same data).
- Navigation rearchitected around a single `NavigationPath` (`RadarRoute`
  enum: `.finder`, `.saveLocation`) owned by RadarView and threaded down
  via `@Binding`, so "Save Location" can pop all the way back to the
  Devices list in one action instead of one level at a time.

## Home screen (shipped 2026-07-17)

RadarView now opens on an idle hero screen instead of a live list —
reproduces PodSpot's actual home screen (reference screenshot reviewed
same day): wordmark, "Tap to Scan" hook + big circular tap target, an
"Unlock Premium" pill (→ `PaywallPlaceholderView` stub until M4), and a
"Previous Locations" pill (→ `PreviousLocationsView`, reads the same
`lastKnownLocation` data the Map tab will use once M3 wires
LocationRecorder end to end). Adapted to PodRadar's navy/teal identity
rather than copying PodSpot's blue/gold. The underlying BLE scan still
runs continuously regardless of which UI state is showing (RootView owns
that lifecycle) — tapping the circle only reveals the list, it doesn't
start/stop the radio.

## Non-goals (v1)

- No detection of powered-off devices or closed AirPods cases — the Find
  My protocol is private to Apple; never imply otherwise in marketing copy
  or UI (compliance + trust risk).
- No Android/cross-platform — iOS only, same as every player in this niche.
- No social/community features.

## Milestones (RepLock/Loopa playbook)

- [x] M0 — pipeline: project.yml + XcodeGen + GitHub Actions CI (test +
      manual device-build workflow), pure-Swift Core scaffolded with unit
      tests (ProximityEngine, DeviceRegistry), minimal 3-tab app shell
      (Radar/Map/Settings) that builds. Pending: first green CI run +
      first signed IPA installed on device.
- [x] M1 — BLE scanning validated on device ✅ 2026-07-17: proximity %
      reaches 100% correctly on close approach with acceptable lag (fixed
      via asymmetric attack/release EMA), and a stationary reading no
      longer jumps around (fixed via median-of-3 pre-filter rejecting
      single-sample RSSI noise). Both field-tested and user-confirmed
      "ça fait l'affaire".
- [ ] M2 — device list polish: naming heuristics (map common BLE service
      UUIDs / name patterns to DeviceKind icons), favorites, ignore-list
      for noisy irrelevant BLE beacons (the biggest UX complaint risk in
      this niche — too many irrelevant devices in the list).
- [ ] M3 — last-known-position map: LocationRecorder wired to
      BLEScanner.onDeviceWentStale, Map tab renders pins, "last seen X
      minutes ago at [address]" copy.
- [ ] M4 — onboarding + paywall: short funnel (hook → how it works →
      permissions pre-prompts → hard paywall), StoreKit 2
      SubscriptionManager already scaffolded — wire real product IDs in
      ASC (`com.awdia.podradar.pro.weekly` 4,99€/wk 3-day trial,
      `.pro.yearly` 29,99€/yr anchor), dev paywall bypass for iteration
      (REMOVE before submission).
- [ ] M5 — localization: en source + fr/es/de/it/pt-BR from day 1 (the
      niche's biggest gap — see app-marketing-context.md), xcstrings
      catalog, ASC metadata in all 6 locales.
- [ ] M6 — submission prep: app icon (real artwork, not the placeholder
      Theme.swift palette), screenshots (radar hero → map → hot/cold),
      privacy questionnaire, legal pages, remove all dev escape hatches,
      flip repo private, submit.

## Open product decisions

- App name: working title PodRadar — confirm before ASC record creation
  (bundle ID `com.awdia.podradar` already assumed throughout).
- Proximity feedback: percentage only, or add a sound-emission feature
  (competitors like Wunderfind rely on visual radar only; a "make it
  beep" feature needs the OTHER device to have speakers and pairing,
  usually out of scope for a pure BLE scanner — validate feasibility
  before promising it in marketing).
