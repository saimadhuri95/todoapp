import 'dart:io';

bool get platformIsWeb => false;
bool get platformIsAndroid => Platform.isAndroid;
bool get platformIsIOS => Platform.isIOS;
bool get platformIsLinux => Platform.isLinux;
bool get platformIsMacOS => Platform.isMacOS;
bool get platformIsWindows => Platform.isWindows;
bool get platformIsDesktop =>
    Platform.isLinux || Platform.isMacOS || Platform.isWindows;
bool get platformSupportsIcloud => Platform.isIOS || Platform.isMacOS;
bool get platformSupportsCameraScanner =>
    Platform.isIOS || Platform.isAndroid || Platform.isMacOS;
// speech_to_text backends: SpeechRecognizer (Android/iOS/macOS), SAPI
// (Windows). No Linux implementation.
bool get platformSupportsVoiceInput =>
    Platform.isIOS ||
    Platform.isAndroid ||
    Platform.isMacOS ||
    Platform.isWindows;
bool get defaultAlarmsEnabled => Platform.isAndroid || Platform.isIOS;

String get platformDeviceName => Platform.localHostname;
String get platformName => Platform.operatingSystem;
String get platformPathSeparator => Platform.pathSeparator;
