/// Pure parsers for third-party import formats (TASKS.md 6.40, R11.2):
/// todo.txt, generic CSV, and the CSV exports produced by Todoist and
/// TickTick. Everything here is database-free so the mapping rules stay
/// unit-testable without a drift instance; [ExportService.importParsed]
/// turns the [ImportedTodo]s these return into stamped rows.
library;

import '../core/recurrence.dart';

/// One todo parsed from an external file, before it is assigned an id or
/// written. Priorities are already mapped onto Knot's 0–3 scale (0 none,
/// 1 low, 2 medium, 3 high). Dates are epoch milliseconds; a date-only source
/// value is interpreted at local midnight.
class ImportedTodo {
  const ImportedTodo({
    required this.title,
    this.notes = '',
    this.dueAtMs,
    this.priority = 0,
    this.tags = const [],
    this.completed = false,
    this.completedAtMs,
    this.recurrenceRule,
  });

  final String title;
  final String notes;
  final int? dueAtMs;
  final int priority;
  final List<String> tags;

  /// Whether the source marked this done. [completedAtMs] may still be null
  /// when the format records completion without a timestamp — the importer
  /// stamps the current clock in that case.
  final bool completed;
  final int? completedAtMs;
  final String? recurrenceRule;
}

/// Parses todo.txt content (one task per line) — the inverse of
/// [ExportService.exportTodoTxt]. Recognizes a leading `x` (+ optional
/// completion date), an `(A)`–`(Z)` priority, `+project`/`@context` tags,
/// `due:YYYY-MM-DD`, and `rec:` recurrence. Blank lines are skipped.
List<ImportedTodo> parseTodoTxt(String text) {
  final todos = <ImportedTodo>[];
  for (final raw in text.split('\n')) {
    final line = raw.trim();
    if (line.isEmpty) continue;
    var tokens = line.split(RegExp(r'\s+'));
    var completed = false;
    int? completedAtMs;
    var priority = 0;

    if (tokens.isNotEmpty && tokens.first == 'x') {
      completed = true;
      tokens = tokens.sublist(1);
      if (tokens.isNotEmpty && _dateOnly.hasMatch(tokens.first)) {
        completedAtMs = _parseDate(tokens.first);
        tokens = tokens.sublist(1);
      }
    } else if (tokens.isNotEmpty && _priorityTag.hasMatch(tokens.first)) {
      // (A) = highest → 3, matching exportTodoTxt's A/B/C = high/med/low.
      priority = ('C'.codeUnitAt(0) - tokens.first.codeUnitAt(1)) + 1;
      if (priority < 0) priority = 0;
      if (priority > 3) priority = 3;
      tokens = tokens.sublist(1);
    }

    final titleWords = <String>[];
    final tags = <String>[];
    int? dueAtMs;
    String? recurrenceRule;
    for (final token in tokens) {
      if ((token.startsWith('+') || token.startsWith('@')) &&
          token.length > 1) {
        tags.add(token.substring(1).replaceAll('_', ' '));
      } else if (token.startsWith('due:')) {
        dueAtMs = _parseDate(token.substring(4));
      } else if (token.startsWith('rec:')) {
        recurrenceRule = _recurrenceFromTag(token.substring(4));
      } else if (token.contains(':') && !token.startsWith(':')) {
        // Unknown key:value metadata — drop it rather than treat as title.
      } else {
        titleWords.add(token);
      }
    }
    final title = titleWords.join(' ').trim();
    if (title.isEmpty) continue;
    todos.add(
      ImportedTodo(
        title: title,
        priority: priority,
        tags: tags,
        dueAtMs: dueAtMs,
        recurrenceRule: recurrenceRule,
        completed: completed,
        completedAtMs: completedAtMs,
      ),
    );
  }
  return todos;
}

/// Parses a CSV export into todos. Handles a generic sheet as well as the
/// specific column layouts of Todoist and TickTick exports, which are detected
/// from the header row (TickTick prefixes several metadata lines that are
/// skipped until the header is found). Columns are matched by name aliases,
/// so a hand-rolled CSV with `title,due,priority` columns works too.
List<ImportedTodo> parseCsv(String text) {
  final records = _parseDelimited(text);
  if (records.isEmpty) return const [];

  // Skip any preamble (TickTick prefixes metadata lines) and locate the
  // header: the first row that names a title-like column. Preamble lines
  // ("Date: …") don't match a title alias, so they're passed over.
  var headerIndex = -1;
  for (var i = 0; i < records.length; i++) {
    if (records[i].any((c) => _titleAliases.contains(c.trim().toLowerCase()))) {
      headerIndex = i;
      break;
    }
  }
  if (headerIndex == -1) return const [];

  final header = [for (final c in records[headerIndex]) c.trim().toLowerCase()];
  int col(Set<String> aliases, {int except = -1}) {
    for (var i = 0; i < header.length; i++) {
      if (i != except && aliases.contains(header[i])) return i;
    }
    return -1;
  }

  String cell(List<String> row, int index) =>
      (index >= 0 && index < row.length) ? row[index].trim() : '';

  final titleCol = col(_titleAliases);
  // 'content' is a title in Todoist but notes in TickTick — only treat it as
  // notes when it isn't the column already claimed by the title.
  final notesCol = col(_notesAliases, except: titleCol);
  final dueCol = col(_dueAliases);
  final priorityCol = col(_priorityAliases);
  final tagsCol = col(_tagsAliases);
  final statusCol = col(_statusAliases);
  final completedAtCol = col(_completedAtAliases);
  final typeCol = header.indexOf('type');

  final source = _detectSource(header);

  final todos = <ImportedTodo>[];
  for (var i = headerIndex + 1; i < records.length; i++) {
    final row = records[i];
    if (row.length == 1 && row.first.trim().isEmpty) continue;
    // Todoist rows include non-task types (note, section) — keep only tasks.
    if (typeCol >= 0) {
      final type = cell(row, typeCol).toLowerCase();
      if (type.isNotEmpty && type != 'task') continue;
    }
    final title = cell(row, titleCol);
    if (title.isEmpty) continue;

    final completedAt = _parseDate(cell(row, completedAtCol));
    final status = cell(row, statusCol).toLowerCase();
    final completed =
        completedAt != null || _completedStatuses.contains(status);

    todos.add(
      ImportedTodo(
        title: title,
        notes: cell(row, notesCol),
        dueAtMs: _parseDate(cell(row, dueCol)),
        priority: _mapPriority(cell(row, priorityCol), source),
        tags: _splitTags(cell(row, tagsCol)),
        completed: completed,
        completedAtMs: completedAt,
        recurrenceRule: _recurrenceFromRRule(cell(row, col(_repeatAliases))),
      ),
    );
  }
  return todos;
}

enum _CsvSource { generic, todoist, tickTick }

_CsvSource _detectSource(List<String> header) {
  final set = header.toSet();
  if (set.containsAll({'type', 'content', 'priority'})) {
    return _CsvSource.todoist;
  }
  if (set.contains('kind') ||
      set.contains('list name') ||
      set.contains('is check list')) {
    return _CsvSource.tickTick;
  }
  return _CsvSource.generic;
}

/// Maps a source priority string onto Knot's 0–3 scale. The two supported
/// tools disagree on encoding, so each is mapped explicitly:
/// Todoist export uses 1–4 with 4 = p1 (highest); TickTick uses 0/1/3/5.
/// A generic sheet is assumed to already speak the 0–3 scale.
int _mapPriority(String value, _CsvSource source) {
  final n = int.tryParse(value.trim());
  if (n == null) return 0;
  final mapped = switch (source) {
    _CsvSource.todoist => const {4: 3, 3: 2, 2: 1, 1: 0}[n] ?? 0,
    _CsvSource.tickTick => const {5: 3, 3: 2, 1: 1, 0: 0}[n] ?? 0,
    _CsvSource.generic => n,
  };
  return mapped.clamp(0, 3);
}

List<String> _splitTags(String value) => [
  for (final tag in value.split(RegExp(r'[,;]')))
    if (tag.trim().isNotEmpty) tag.trim(),
];

const _titleAliases = {'title', 'content', 'name', 'task', 'subject'};
const _notesAliases = {'notes', 'description', 'note', 'memo', 'content'};
const _dueAliases = {'due', 'due date', 'date', 'deadline'};
const _priorityAliases = {'priority', 'prio'};
const _tagsAliases = {'tags', 'labels', 'label', 'context'};
const _statusAliases = {'status', 'completed', 'done', 'state'};
const _completedAtAliases = {
  'completed time',
  'completed at',
  'completed date',
};
const _repeatAliases = {'repeat', 'recurrence', 'rrule', 'rec'};
const _completedStatuses = {'1', '2', 'completed', 'done', 'x', 'true', 'yes'};

/// RFC 4180-ish CSV/TSV tokenizer: honors double-quoted fields with embedded
/// separators, newlines, and doubled `""` escapes. The delimiter is inferred
/// per file (comma unless the first line has more tabs than commas). Returns
/// one list of fields per record.
List<List<String>> _parseDelimited(String text) {
  if (text.isEmpty) return const [];
  final firstLine = text.split('\n').first;
  final comma = ','.allMatches(firstLine).length;
  final tab = '\t'.allMatches(firstLine).length;
  final delimiter = tab > comma ? '\t' : ',';

  final records = <List<String>>[];
  var record = <String>[];
  final field = StringBuffer();
  var inQuotes = false;
  var i = 0;
  while (i < text.length) {
    final ch = text[i];
    if (inQuotes) {
      if (ch == '"') {
        if (i + 1 < text.length && text[i + 1] == '"') {
          field.write('"');
          i += 2;
          continue;
        }
        inQuotes = false;
      } else {
        field.write(ch);
      }
      i++;
      continue;
    }
    if (ch == '"') {
      inQuotes = true;
    } else if (ch == delimiter) {
      record.add(field.toString());
      field.clear();
    } else if (ch == '\n' || ch == '\r') {
      // Consume \r\n as a single break; end the record on any newline.
      if (ch == '\r' && i + 1 < text.length && text[i + 1] == '\n') i++;
      record.add(field.toString());
      field.clear();
      records.add(record);
      record = <String>[];
    } else {
      field.write(ch);
    }
    i++;
  }
  // Flush a trailing field/record with no closing newline.
  if (field.isNotEmpty || record.isNotEmpty) {
    record.add(field.toString());
    records.add(record);
  }
  return records;
}

final _dateOnly = RegExp(r'^\d{4}-\d{2}-\d{2}$');

/// Parses `YYYY-MM-DD` (interpreted at local midnight) or a full ISO-8601
/// timestamp into epoch milliseconds. Returns null for empty or unparseable
/// input so a bad cell drops the field instead of failing the whole import.
int? _parseDate(String value) {
  final v = value.trim();
  if (v.isEmpty) return null;
  if (_dateOnly.hasMatch(v)) {
    final parts = v.split('-').map(int.parse).toList();
    return DateTime(parts[0], parts[1], parts[2]).millisecondsSinceEpoch;
  }
  return DateTime.tryParse(v)?.millisecondsSinceEpoch;
}

final _priorityTag = RegExp(r'^\([A-Z]\)$');

final _recTag = RegExp(r'^(\d+)([dwmy])$');

/// todo.txt `rec:` value (1d/2w/…) → an iCalendar FREQ rule, the inverse of
/// [ExportService] `_recTag`. Returns null for anything unrecognized.
String? _recurrenceFromTag(String value) {
  final m = _recTag.firstMatch(value.trim());
  if (m == null) return null;
  const unit = {'d': 'DAILY', 'w': 'WEEKLY', 'm': 'MONTHLY', 'y': 'YEARLY'};
  final n = int.parse(m.group(1)!);
  final freq = unit[m.group(2)]!;
  return n == 1 ? 'FREQ=$freq' : 'FREQ=$freq;INTERVAL=$n';
}

/// Accepts an RRULE-style recurrence cell (with or without a leading
/// `RRULE:`) and keeps it only when Knot can actually act on it. A source
/// export may carry RRULE features Knot doesn't support (`FREQ=HOURLY`,
/// positional `BYDAY=1MO`, `BYMONTHDAY`, …); storing those verbatim leaves a
/// todo with a rule that never recurs and can't be edited, so — like the
/// todo.txt `rec:` path — anything the app can't parse is dropped and the
/// task imports as non-recurring.
String? _recurrenceFromRRule(String value) {
  var v = value.trim();
  if (v.isEmpty) return null;
  if (v.toUpperCase().startsWith('RRULE:')) v = v.substring(6);
  if (!v.toUpperCase().startsWith('FREQ=')) return null;
  try {
    Recurrence.parse(v);
    return v;
  } on FormatException {
    return null;
  }
}
