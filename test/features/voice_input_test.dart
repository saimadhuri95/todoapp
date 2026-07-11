import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todoapp/app/providers.dart';
import 'package:todoapp/app/voice_input.dart';
import 'package:todoapp/core/clock.dart';
import 'package:todoapp/data/db/database.dart';
import 'package:todoapp/main.dart';

/// Same drift-safe teardown as the other widget tests: advance fake time so
/// the stream keep-alive timer fires before the binding asserts !timersPending.
void testApp(String description, Future<void> Function(WidgetTester) body) {
  testWidgets(description, (tester) async {
    await body(tester);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(minutes: 1));
  });
}

/// Scripted recognizer: emits [script] as one partial + final transcript.
class FakeVoiceInput implements VoiceInput {
  FakeVoiceInput({this.available = true, this.script = ''});

  final bool available;
  final String script;
  var started = 0;
  var stopped = 0;

  @override
  bool get supported => true;

  @override
  Future<bool> ensureAvailable() async => available;

  @override
  Future<void> start(void Function(String text, bool isFinal) onResult) async {
    started++;
    onResult(script.split(' ').first, false); // partial
    onResult(script, true);
  }

  @override
  Future<void> stop() async {
    stopped++;
  }
}

void main() {
  late AppDatabase db;
  final clock = FixedClock(DateTime.utc(2026, 7, 6, 12));

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Widget app(VoiceInput voice) => ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(db),
      deviceIdProvider.overrideWithValue('voice-device'),
      clockProvider.overrideWithValue(clock),
      voiceInputProvider.overrideWithValue(voice),
    ],
    child: const TodoApp(),
  );

  final micButton = find.byTooltip('Dictate');
  final dialogField = find.descendant(
    of: find.byType(AlertDialog),
    matching: find.byType(TextField),
  );

  testApp('dictation fills the quick-add field and parses dates', (
    tester,
  ) async {
    final voice = FakeVoiceInput(script: 'water plants tomorrow');
    await tester.pumpWidget(app(voice));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.tap(micButton);
    await tester.pumpAndSettle();

    expect(voice.started, 1);
    expect(
      tester.widget<TextField>(dialogField).controller!.text,
      'water plants tomorrow',
    );
    // The natural-date preview ran on the dictated text.
    expect(find.textContaining('Due 2026-07-07'), findsOneWidget);
  });

  testApp('dictation appends to typed text instead of clobbering it', (
    tester,
  ) async {
    final voice = FakeVoiceInput(script: 'buy milk');
    await tester.pumpWidget(app(voice));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(dialogField, 'urgent:');
    await tester.tap(micButton);
    await tester.pumpAndSettle();

    expect(
      tester.widget<TextField>(dialogField).controller!.text,
      'urgent: buy milk',
    );
  });

  testApp('unavailable voice input degrades to a message', (tester) async {
    final voice = FakeVoiceInput(available: false);
    await tester.pumpWidget(app(voice));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.tap(micButton);
    await tester.pumpAndSettle();

    expect(voice.started, 0);
    expect(find.text('Voice input is not available here'), findsOneWidget);
  });
}
