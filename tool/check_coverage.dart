import 'dart:io';

void main(List<String> args) {
  final path = _readOption(args, '--lcov') ?? 'coverage/lcov.info';
  final minPercent =
      double.tryParse(_readOption(args, '--min') ?? '80') ?? 80.0;
  final scopes = _readRepeatedOption(args, '--scope');
  final includedScopes = scopes.isEmpty ? const ['lib/data'] : scopes;

  final file = File(path);
  if (!file.existsSync()) {
    stderr.writeln('Coverage file not found: $path');
    exitCode = 1;
    return;
  }

  final summaries = <_FileCoverage>[];
  String? currentFile;
  var currentFound = 0;
  var currentHit = 0;

  void flushCurrent() {
    if (currentFile == null || currentFound == 0) return;
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
      continue;
    }
    if (line.startsWith('DA:')) {
      final parts = line.substring(3).split(',');
      if (parts.length < 2) continue;
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

bool _shouldInclude(String rawPath, List<String> scopes) {
  final path = rawPath.replaceAll('\\', '/');
  if (path.endsWith('.g.dart')) return false;
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
