# 0006 - Device Testing: Firebase Test Lab For Mobile Real-Device Runs

Date: 2026-07-14
Status: accepted

## Context

Several open tasks need the app exercised on **real** mobile hardware we do not
own: the old/low-RAM Android floor (#53), the install → relaunch → folder-still-
syncs check on a fresh release build (#25), and the mobile slice of the
five-platform beta round (#29). Emulators and simulators (already used locally
and in the `smoke-desktop` CI job) catch functional regressions but not real
silicon performance, real notification/permission behaviour, or device-specific
rendering.

We evaluated hosted device clouds. The desktop targets (Windows, macOS, Linux)
are out of scope for all of them — no cloud runs native desktop Flutter apps —
so this decision only concerns Android and iOS.

| Option | Flutter fit | Old/low-end Android | iOS without our Apple acct | Pricing | Notes |
|---|---|---|---|---|---|
| **Firebase Test Lab** | Runs `integration_test` directly | Yes (physical + virtual) | Yes (physical devices) | Free daily quota (Spark), then per-minute | First-party Google, `gcloud` CLI |
| AWS Device Farm | Appium/instrumentation | Yes | Yes | Per-minute, no subscription | More setup, no native Flutter runner |
| LambdaTest | Appium | Some | Yes | Cheaper than BrowserStack | Mobile+web only |
| BrowserStack | Appium; App Live re-signs iOS | Yes | Yes (re-signs uploads) | Subscription | Priciest for CI use |

## Decision

Adopt **Firebase Test Lab** as the mobile real-device testing channel.

Rationale: it runs our existing `integration_test/` suite unchanged (via the new
`test_driver/integration_test.dart` entrypoint), it exposes genuinely old and
low-RAM Android models for #53, it covers physical iOS devices without us owning
an Apple Developer account, and its free daily quota fits the project's
cost-sensitivity — we pay per-minute only past the free tier.

Enablement is **owner-gated**: it requires a Google Cloud / Firebase project and
a service-account key that only the project owner can create. The workflow lands
now as `.github/workflows/device-test.yml`, triggered by `workflow_dispatch`
only, and stays inert until the `GCP_PROJECT` and `GCP_SA_KEY` repository secrets
are populated.

### Relationship to the source-available license (ADR 0005)

Uploading build **binaries** to Test Lab to run our own tests is not
redistribution: the artifact is not published to third parties for their use,
it is handed to a CI runner we control. This is consistent with ADR 0005, which
reserves *redistribution*, not private build/test usage. No user data is
uploaded — only the app under test and its instrumentation.

## Consequences

- `test_driver/integration_test.dart` is added so `flutter drive` and Test Lab
  can run the same suite CI already runs headless.
- The device-test workflow is manual-dispatch and secret-gated; it will no-op
  (skip with a clear message) until the owner adds the secrets, so it never
  breaks required CI.
- Test Lab covers the **mobile** portions of #53/#25/#29 only. The real-hardware
  behaviours no cloud reproduces well — alarms firing over hours with the app
  closed (#19) and battery/wake-lock audits (#28) — still need a physical
  low-end device (tracked in #157) and are explicitly out of scope here.
- If free-tier quota proves too tight for regular CI use, AWS Device Farm
  (per-minute, no subscription) is the documented fallback; revisit in a new ADR.
