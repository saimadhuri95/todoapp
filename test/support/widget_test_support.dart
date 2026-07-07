import 'package:drift/drift.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// testWidgets + drift-safe teardown. Drift schedules a stream keep-alive
/// Timer in the fake-async zone once the tree unmounts and riverpod cancels
/// its stream subscriptions; without advancing fake time that timer never
/// fires, and db.close() can hang waiting on the stream store.
void testApp(String description, Future<void> Function(WidgetTester) body) {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  testWidgets(description, (tester) async {
    await body(tester);
    await pumpPastDriftTeardown(tester);
  });
}

Future<void> pumpPastDriftTeardown(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
  await tester.pump(const Duration(minutes: 1));
}
