# CI and Merge Checklist

Use the same flow for every patch before merging to `main`.

## Local Checks

Before changing tests, revalidate the production behavior and the original
failure. Tests are evidence, not a shortcut: update them only when the product
requirement or public behavior has intentionally changed, or when the test is
proven wrong or flaky after code-level investigation. Prefer fixing production
code, setup, teardown, or platform assumptions first.

Every code change must be correct across all supported platforms: Android,
iOS, macOS, Windows, Linux, and web. When a feature has platform-specific
paths such as LAN server/client roles, notification permissions, filesystem
access, or Apple sandbox behavior, validate the relevant path directly or
document why GitHub CI/device testing is the source of truth.

Run these from the repository root and fix every failure locally before opening
or merging a pull request:

```powershell
C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe format lib test integration_test tool
C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe format --output=none --set-exit-if-changed lib test integration_test tool
C:\src\flutter\bin\flutter.bat analyze
C:\src\flutter\bin\flutter.bat test --coverage
C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe tool\check_coverage.dart --lcov coverage\lcov.info --min 100 --scope lib/core --scope lib/data
C:\src\flutter\bin\flutter.bat test test\core\dst_test.dart
C:\src\flutter\bin\flutter.bat test integration_test\app_smoke_test.dart -d windows
```

For changes with a narrow blast radius, run the focused tests first, then still
run the full suite before merge. Example:

```powershell
C:\src\flutter\bin\flutter.bat test test\data\sync_orchestrator_test.dart test\app\alarm_service_test.dart
```

The GitHub workflow also runs:

- the explicit Phase 0 unit suites,
- the convergence + fake-transport simulator gate,
- the DST suite with `TZ=America/New_York` on Linux,
- the `integration_test` smoke flow on Linux/Windows/macOS,
- and debug build gates for Linux/Android/Windows/macOS/iOS.

The merge CI is intentionally parallelized and should usually finish in about
10 minutes. Android and iOS simulator smoke tests are not part of every merge
because they have been the slowest and flakiest jobs; run targeted simulator or
device validation for mobile UI/runtime changes and before release builds.

On Windows, rely on GitHub CI for the exact `TZ=America/New_York` run; setting
`$env:TZ` locally can still use Windows time-zone behavior and produce false
failures.

## Pull Request Flow

1. Start from a feature branch, not `main`.
2. Commit only intended source, test, docs, and task-list changes.
3. Do not stage line-ending-only generated plugin files.
4. Push the branch and open a pull request into `main`.
5. Wait for every GitHub Actions check to pass:
   `Analyze & verify`, `Smoke linux`, `Smoke windows`, `Smoke macos`,
   `Build linux`, `Build android`, `Build windows`, `Build macos`, and
   `Build ios`.
6. Merge with the normal GitHub merge commit after CI is green.

## GitHub Status Commands

```powershell
gh pr status
gh pr checks --watch
gh run list --limit 10
```
