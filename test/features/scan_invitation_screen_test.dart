import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:todoapp/features/settings/scan_invitation_screen.dart';

import '../support/widget_test_support.dart';

void main() {
  testApp('pops with the first detected invitation payload', (tester) async {
    String? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () async {
                  result = await Navigator.of(context).push<String>(
                    MaterialPageRoute(
                      builder: (_) => ScanInvitationScreen(
                        scannerBuilder:
                            (
                              BuildContext context,
                              MobileScannerController controller,
                              void Function(String value) onValue,
                            ) => Center(
                              child: FilledButton(
                                onPressed: () => onValue('secret-invitation'),
                                child: const Text('Emit QR'),
                              ),
                            ),
                      ),
                    ),
                  );
                },
                child: const Text('Open scanner'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open scanner'));
    await tester.pumpAndSettle();
    expect(find.text('Scan invitation'), findsOneWidget);

    await tester.tap(find.text('Emit QR'));
    await tester.pumpAndSettle();

    expect(result, 'secret-invitation');
  });

  testApp('keeps the aiming frame around the scanner surface', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ScanInvitationScreen(
          scannerBuilder:
              (
                BuildContext context,
                MobileScannerController controller,
                void Function(String value) onValue,
              ) => const Center(child: Text('Fake camera surface')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Fake camera surface'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is IgnorePointer && widget.ignoring,
      ),
      findsOneWidget,
    );
  });
}
