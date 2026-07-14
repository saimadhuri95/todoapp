import '../data/db/database.dart';

/// The data a home-screen widget shows (TASKS.md 6.24): how many todos are due
/// today and the first few titles. Pure so it is testable without any native
/// widget host; the platform bridge just serialises this.
class HomeWidgetSummary {
  const HomeWidgetSummary({required this.dueToday, required this.titles});

  /// Total active todos due on or before the end of today (overdue included).
  final int dueToday;

  /// Up to [maxTitles] of those todos' titles, soonest-due first.
  final List<String> titles;

  Map<String, Object?> toJson() => {'dueToday': dueToday, 'titles': titles};
}

/// Maximum titles shown on the widget before it just reads "+N more".
const kHomeWidgetMaxTitles = 3;

/// Builds the widget summary from [todos] relative to [now]. Counts active,
/// top-level todos due before the start of tomorrow (matching the "Today"
/// list section), ordered soonest-due first, and keeps the first
/// [maxTitles] titles.
HomeWidgetSummary homeWidgetSummary(
  List<Todo> todos,
  DateTime now, {
  int maxTitles = kHomeWidgetMaxTitles,
}) {
  final cutoff = DateTime(
    now.year,
    now.month,
    now.day + 1,
  ).millisecondsSinceEpoch;
  final due = [
    for (final todo in todos)
      if (!todo.deleted &&
          todo.completedAtMs == null &&
          todo.parentId == null &&
          todo.dueAtMs != null &&
          todo.dueAtMs! < cutoff)
        todo,
  ]..sort((a, b) => a.dueAtMs!.compareTo(b.dueAtMs!));
  return HomeWidgetSummary(
    dueToday: due.length,
    titles: [for (final todo in due.take(maxTitles)) todo.title],
  );
}

/// Headline line for the widget. Formatting lives here (not in native code)
/// so it is tested once and every platform widget just renders the string.
String homeWidgetHeadline(HomeWidgetSummary summary) =>
    switch (summary.dueToday) {
      0 => 'Nothing due today',
      1 => '1 due today',
      _ => '${summary.dueToday} due today',
    };

/// Body line(s): the shown titles, with a "+N more" tail when the count
/// exceeds the titles listed. Empty when nothing is due.
String homeWidgetBody(HomeWidgetSummary summary) {
  if (summary.dueToday == 0) return '';
  final lines = [...summary.titles];
  final remaining = summary.dueToday - summary.titles.length;
  if (remaining > 0) lines.add('+$remaining more');
  return lines.join('\n');
}
