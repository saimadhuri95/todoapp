import 'dart:io';

/// Hand-rolled "start at login" registration (TASKS.md 5.2) — an XDG
/// autostart entry on Linux and a HKCU Run registry value on Windows; both
/// are plain file/registry writes, unit-testable with an injected home and
/// exec path. No plugin: launch_at_startup pins win32 ^5 and conflicts
/// with wakelock_plus. macOS goes through the sandbox-safe SMAppService
/// channel instead (see background_mode_native.dart) — a sandboxed app
/// cannot write ~/Library/LaunchAgents.
class LoginItem {
  LoginItem({required this.execPath, this.args = const ['--hidden']});

  final String execPath;

  /// Passed to the login launch so the window can come up hidden.
  final List<String> args;

  static const _id = 'com.sai.knot';
  static const _registryValueName = 'Knot';

  String get _quotedCommand =>
      '"$execPath"${args.isEmpty ? '' : ' ${args.join(' ')}'}';

  /// Linux: ~/.config/autostart/com.sai.knot.desktop (XDG autostart).
  String desktopEntry() =>
      '''
[Desktop Entry]
Type=Application
Name=Knot
Comment=Todo sync in the background
Exec=$_quotedCommand
Terminal=false
X-GNOME-Autostart-enabled=true
''';

  File linuxAutostartFile(String home) =>
      File('$home/.config/autostart/$_id.desktop');

  /// Windows `reg` invocation (add or delete the HKCU Run value); returned
  /// as (executable, args) so tests can assert without touching the
  /// registry.
  (String, List<String>) windowsRegCommand({required bool enabled}) {
    const key = r'HKCU\Software\Microsoft\Windows\CurrentVersion\Run';
    return enabled
        ? (
            'reg',
            [
              'add',
              key,
              '/v',
              _registryValueName,
              '/t',
              'REG_SZ',
              '/d',
              _quotedCommand,
              '/f',
            ],
          )
        : ('reg', ['delete', key, '/v', _registryValueName, '/f']);
  }

  /// Installs or removes the login item for the current platform. [home]
  /// and [runProcess] are injectable for tests.
  Future<void> apply({
    required bool enabled,
    String? home,
    Future<ProcessResult> Function(String, List<String>)? runProcess,
  }) async {
    final resolvedHome =
        home ??
        Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        '';
    if (Platform.isLinux) {
      await _applyFile(
        linuxAutostartFile(resolvedHome),
        desktopEntry(),
        enabled,
      );
    } else if (Platform.isWindows) {
      final (exe, cmdArgs) = windowsRegCommand(enabled: enabled);
      await (runProcess ?? Process.run)(exe, cmdArgs);
    }
  }

  static Future<void> _applyFile(
    File file,
    String contents,
    bool enabled,
  ) async {
    if (enabled) {
      await file.parent.create(recursive: true);
      await file.writeAsString(contents);
    } else if (await file.exists()) {
      await file.delete();
    }
  }
}
