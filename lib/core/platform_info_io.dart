import 'dart:io';

bool get platformIsWeb => false;
bool get platformIsAndroid => Platform.isAndroid;
bool get platformIsIOS => Platform.isIOS;
bool get platformIsLinux => Platform.isLinux;
bool get platformIsMacOS => Platform.isMacOS;
bool get platformSupportsIcloud => Platform.isIOS || Platform.isMacOS;
bool get platformSupportsCameraScanner =>
    Platform.isIOS || Platform.isAndroid || Platform.isMacOS;
bool get defaultAlarmsEnabled => Platform.isAndroid || Platform.isIOS;

String get platformDeviceName => Platform.localHostname;
String get platformName => Platform.operatingSystem;
String get platformPathSeparator => Platform.pathSeparator;
