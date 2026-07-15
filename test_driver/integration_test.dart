// Driver entrypoint for `flutter drive` and device clouds (Firebase Test Lab).
//
// The tests themselves live in integration_test/; this file only wires the
// driver side so the same suite that CI runs headless (integration_test/
// app_smoke_test.dart, see .github/workflows/ci.yml `smoke-desktop`) can also
// run on real Android/iOS hardware via `flutter drive` or Test Lab. See
// docs/decisions/0006-device-testing-cloud.md.
import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver();
