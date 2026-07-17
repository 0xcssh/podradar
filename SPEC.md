# SPEC — PodRadar

Clone of PodSpot: Find My Headphones (App Store id1611422396, ~$5k/mo MRR,
abandoned since Jan 2024 — see app-marketing-context.md for the full
competitive analysis). Native iOS, Bluetooth Low Energy device finder with
a differentiating last-known-position map.

## Core loop

1. User opens the app because they just lost an earbud/headphone.
2. Radar tab scans all nearby BLE peripherals, shows a live list sorted by
   proximity (closest first), with a hot/cold trend per device.
3. Tapping a device shows a full-screen proximity view (percentage +
   hot/cold + optional sound/vibration cue as the user gets closer).
4. If a device goes stale (not heard from in ~8s) while the app has
   location permission, PodRadar stamps its last-known GPS position —
   visible later on the Map tab. This is the answer to the niche's #1
   complaint ("useless once the device goes out of range/off").

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
