// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Knot';

  @override
  String get todosTitle => 'Todos';

  @override
  String get emptyStateTitle => 'No todos yet — add one!';

  @override
  String get emptyStateHint => 'Tap + to add a todo. Ctrl/Cmd+N works too.';

  @override
  String get pairAnotherDevice => 'Pair another device';

  @override
  String get addTodoTooltip => 'Add todo';

  @override
  String get settingsTooltip => 'Settings';

  @override
  String get newTodoTitle => 'New todo';

  @override
  String get newTodoHint => 'What needs doing?';

  @override
  String get add => 'Add';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';
}
