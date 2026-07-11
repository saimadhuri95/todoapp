import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../core/platform_info.dart';

/// Platform seam for dictation into quick add (TASKS.md 6.46), so the UI
/// and tests never touch the speech plugin directly.
abstract interface class VoiceInput {
  /// Whether this platform has a speech backend at all — decides if the
  /// mic button is shown. Lives on the seam (not a bare platform check in
  /// the UI) so widget tests behave the same on every CI host.
  bool get supported;

  /// Initializes the recognizer and asks for mic/speech permission.
  /// False when the platform, hardware, or user says no.
  Future<bool> ensureAvailable();

  /// Starts a dictation session; [onResult] receives the running transcript
  /// (already accumulated by the recognizer) and whether it is final.
  Future<void> start(void Function(String text, bool isFinal) onResult);

  Future<void> stop();
}

/// On-device platform speech APIs via speech_to_text: SpeechRecognizer on
/// Android/iOS/macOS, Web Speech, Windows SAPI. No Linux backend — the mic
/// button never shows there ([platformSupportsVoiceInput]). `onDevice`
/// keeps recognition local (invariant 3: nothing leaves the device),
/// matching the task's "on-device only".
class SpeechVoiceInput implements VoiceInput {
  final _speech = SpeechToText();
  var _ready = false;

  @override
  bool get supported => platformSupportsVoiceInput;

  @override
  Future<bool> ensureAvailable() async {
    if (!supported) return false;
    if (_ready) return true;
    try {
      _ready = await _speech.initialize();
    } on Exception {
      _ready = false;
    }
    return _ready;
  }

  @override
  Future<void> start(void Function(String text, bool isFinal) onResult) =>
      _speech.listen(
        onResult: (result) =>
            onResult(result.recognizedWords, result.finalResult),
        listenOptions: SpeechListenOptions(
          onDevice: true,
          listenMode: ListenMode.dictation,
          partialResults: true,
        ),
      );

  @override
  Future<void> stop() => _speech.stop();
}

final voiceInputProvider = Provider<VoiceInput>((_) => SpeechVoiceInput());
