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
- [x] M2 — device list polish ✅: DeviceKindClassifier (Apple proximity-
      pairing + name heuristics), favorites, ignore-list, RSSI floor
      (-70dBm) to stop the list flooding with weak signals, per-device
      rename with local persistence, stable first-seen ordering (no more
      reshuffling as RSSI fluctuates).
- [x] M3 — last-known-position map ✅: LocationRecorder wired to both
      BLEScanner.onDeviceWentStale (automatic) AND the "Found it!" → Save
      Location flow (explicit, with a description field), Map tab +
      Previous Locations both render it.
- [x] M4 — paywall ✅: real PaywallView matching PodSpot's reference
      exactly, ASC subscription live (`com.awdia.podradar.pro.weekly`,
      2,99 $/wk + 3-day trial, priced in all 175 territories), sandbox
      purchase confirmed working end to end 2026-07-19.
      **Onboarding funnel NOT built** — app currently opens straight to
      the hero "Tap to Scan" screen with no hook/permissions-explainer
      steps (matches PodSpot's own minimal flow, but worth a product call
      before submission — see Open product decisions).
- [x] M5 — localization ✅ 2026-07-19: all 68 user-facing strings across
      every view + both permission prompts translated into
      fr/es/de/it/pt-BR in Shared/Localizable.xcstrings and
      PodRadar/InfoPlist.xcstrings. Along the way, fixed several spots
      where a `String` (not `Text("literal")`) was passed to `Text(_:)` —
      SwiftUI only auto-localizes the literal form; the verbatim overload
      silently skips the catalog. Needs a device test to confirm strings
      actually switch when the iPhone's language changes (can't verify
      from CI/simulator alone) and to eyeball layout at the longer German/
      French string lengths.
- [ ] M6 — submission prep: **real app icon** (still the placeholder
      Theme.swift palette, needs user-supplied artwork like RepLock's),
      screenshots (radar hero → map → hot/cold), App Privacy
      questionnaire in ASC, legal pages (privacy policy + terms — no
      `podradar-legal` repo exists yet), remove any dev-only affordances,
      flip repo private, submit.

## Open product decisions

- App name: working title PodRadar — confirm before ASC record creation
  (bundle ID `com.awdia.podradar` already assumed throughout).
- Proximity feedback: percentage only, or add a sound-emission feature
  (competitors like Wunderfind rely on visual radar only; a "make it
  beep" feature needs the OTHER device to have speakers and pairing,
  usually out of scope for a pure BLE scanner — validate feasibility
  before promising it in marketing).
