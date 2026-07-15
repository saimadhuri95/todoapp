import 'dart:io';

void main(List<String> args) {
  final path = _readOption(args, '--lcov') ?? 'coverage/lcov.info';
  // The pure-logic layers are held at 100%; generated (.g.dart), declarative
  // schema, and platform-channel/native files are excluded (see _platformOnly
  // and `// coverage:ignore-*` markers).
  final minPercent =
      double.tryParse(_readOption(args, '--min') ?? '100') ?? 100.0;
  final scopes = _readRepeatedOption(args, '--scope');
  final includedScopes = scopes.isEmpty
      ? const ['lib/core', 'lib/data']
      : scopes;

  final file = File(path);
  if (!file.existsSync()) {
    stderr.writeln('Coverage file not found: $path');
    exitCode = 1;
    return;
  }

  final summaries = <_FileCoverage>[];
  String? currentFile;
  Set<int>? ignoredLines; // null once the whole file is ignored
  var fileIgnored = false;
  var currentFound = 0;
  var currentHit = 0;

  void flushCurrent() {
    if (currentFile == null || fileIgnored || currentFound == 0) return;
    final path = currentFile;
    if (_shouldInclude(path, includedScopes)) {
      summaries.add(_FileCoverage(path, currentHit, currentFound));
    }
  }

  for (final rawLine in file.readAsLinesSync()) {
    final line = rawLine.trim();
    if (line.startsWith('SF:')) {
      flushCurrent();
      currentFile = line.substring(3);
      currentFound = 0;
      currentHit = 0;
      // Honor `// coverage:ignore-*` markers (the lcov/dart convention) so
      // genuinely-unreachable lines — production I/O entrypoints, defensive
      // catches for protocol-impossible states — don't block a 100% floor.
      final (ignore, fileWide) = _ignoredLinesFor(currentFile);
      ignoredLines = ignore;
      fileIgnored = fileWide;
      continue;
    }
    if (line.startsWith('DA:')) {
      final parts = line.substring(3).split(',');
      if (parts.length < 2) continue;
      final lineNo = int.tryParse(parts[0]);
      if (lineNo != null && (ignoredLines?.contains(lineNo) ?? false)) continue;
      currentFound++;
      if ((int.tryParse(parts[1]) ?? 0) > 0) currentHit++;
      continue;
    }
    if (line == 'end_of_record') {
      flushCurrent();
      currentFile = null;
      currentFound = 0;
      currentHit = 0;
    }
  }
  flushCurrent();

  if (summaries.isEmpty) {
    stderr.writeln(
      'No matching coverage entries found for scopes: ${includedScopes.join(', ')}',
    );
    exitCode = 1;
    return;
  }

  summaries.sort((a, b) => a.percent.compareTo(b.percent));
  final totalHit = summaries.fold<int>(0, (sum, item) => sum + item.hit);
  final totalFound = summaries.fold<int>(0, (sum, item) => sum + item.found);
  final totalPercent = totalFound == 0 ? 100.0 : totalHit * 100 / totalFound;

  stdout.writeln('Coverage scope: ${includedScopes.join(', ')}');
  for (final summary in summaries) {
    stdout.writeln(
      '${summary.percent.toStringAsFixed(1).padLeft(5)}%  '
      '${summary.hit}/${summary.found}  ${summary.displayPath}',
    );
  }
  stdout.writeln(
    'Total: ${totalPercent.toStringAsFixed(1)}% '
    '($totalHit/$totalFound covered lines)',
  );

  if (totalPercent < minPercent) {
    stderr.writeln(
      'Coverage floor failed: ${totalPercent.toStringAsFixed(1)}% < '
      '${minPercent.toStringAsFixed(1)}%',
    );
    exitCode = 1;
  }
}

/// Reads [sourcePath] and returns (ignored 1-based line numbers, whole-file
/// ignored) from `// coverage:ignore-line`, `// coverage:ignore-start` …
/// `// coverage:ignore-end`, and `// coverage:ignore-file` markers. A missing
/// source file (shouldn't happen for lib/) ignores nothing.
(Set<int>, bool) _ignoredLinesFor(String sourcePath) {
  final file = File(sourcePath);
  if (!file.existsSync()) return (const <int>{}, false);
  final ignored = <int>{};
  var inBlock = false;
  final lines = file.readAsLinesSync();
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    if (line.contains('coverage:ignore-file')) return (const <int>{}, true);
    if (line.contains('coverage:ignore-start')) inBlock = true;
    if (inBlock) ignored.add(i + 1);
    if (line.contains('coverage:ignore-end')) inBlock = false;
    if (line.contains('coverage:ignore-line')) ignored.add(i + 1);
  }
  return (ignored, false);
}

String? _readOption(List<String> args, String name) {
  for (var i = 0; i < args.length - 1; i++) {
    if (args[i] == name) return args[i + 1];
  }
  return null;
}

List<String> _readRepeatedOption(List<String> args, String name) {
  final values = <String>[];
  for (var i = 0; i < args.length - 1; i++) {
    if (args[i] == name) values.add(args[i + 1]);
  }
  return values;
}

/// Files excluded from the pure-logic floor: they run real platform
/// channels, native plugins, or on-disk I/O and cannot execute in the
/// headless Flutter test host. (Generated `.g.dart` is excluded separately.)
/// Kept here rather than as per-file `coverage:ignore-file` markers so the
/// list of what's *outside* the logic floor lives in one reviewable place.
const _platformOnly = <String>{
  // Drift table DSL — declarative schema read by codegen, not executed.
  'lib/data/db/tables.dart',
  // Real SQLite file open via path_provider (platform channel).
  'lib/data/db/open_connection.dart',
  'lib/data/db/open_connection_native.dart',
  'lib/data/db/open_connection_web.dart',
  // dart:io HttpClient / browser fetch wrappers.
  'lib/data/cloud/cloud_http_native.dart',
  'lib/data/cloud/cloud_http_web.dart',
  // OAuth browser-launch + redirect-receiver plumbing (platform channels).
  'lib/data/cloud/cloud_account_service_native.dart',
  'lib/data/cloud/cloud_account_service_web.dart',
  // Platform detection (Platform.isX) — host-dependent, no logic to test.
  'lib/core/platform_info_io.dart',
  'lib/core/platform_info_web.dart',
  // flutter_secure_storage keychain wrapper (platform channel).
  'lib/data/sync/device_identity.dart',
  // bonsoir mDNS discovery (native).
  'lib/data/sync/lan_discovery.dart',
};

bool _shouldInclude(String rawPath, List<String> scopes) {
  final path = rawPath.replaceAll('\\', '/');
  if (path.endsWith('.g.dart')) return false;
  if (_platformOnly.any((p) => path == p || path.endsWith('/$p'))) return false;
  for (final rawScope in scopes) {
    final scope = rawScope.replaceAll('\\', '/');
    if (path == scope ||
        path.startsWith('$scope/') ||
        path.contains('/$scope/') ||
        path.endsWith('/$scope')) {
      return true;
    }
  }
  return false;
}

class _FileCoverage {
  const _FileCoverage(this.path, this.hit, this.found);

  final String path;
  final int hit;
  final int found;

  double get percent => found == 0 ? 100.0 : hit * 100 / found;

  String get displayPath => path.replaceAll('\\', '/');
}
