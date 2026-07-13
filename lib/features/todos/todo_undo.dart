import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/db/database.dart';
import '../../data/repositories/todo_repository.dart';

void showTodoUndoSnackBar({
  required ScaffoldMessengerState messenger,
  required TodoRepository repo,
  required Todo before,
  required Todo after,
  required String message,
}) {
  final changedFields = _changedFields(before, after);
  if (changedFields.isEmpty) return;
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: Text(message),
      action: SnackBarAction(
        label: 'Undo',
        onPressed: () =>
            unawaited(repo.restoreSnapshot(before, fields: changedFields)),
      ),
    ),
  );
}

// Must cover every synced todo column that a user action can change, or an
// undo silently leaves that field mutated — and, worse, an omission here that
// later gets requested would stamp a clock without restoring the value. Keep
// in sync with `syncColumns['todos']` / `TodoRepository.restoreSnapshot`.
Set<String> _changedFields(Todo before, Todo after) => {
  if (before.listId != after.listId) 'listId',
  if (before.parentId != after.parentId) 'parentId',
  if (before.title != after.title) 'title',
  if (before.notes != after.notes) 'notes',
  if (before.dueAtMs != after.dueAtMs) 'dueAtMs',
  if (before.recurrenceRule != after.recurrenceRule) 'recurrenceRule',
  if (before.completedAtMs != after.completedAtMs) 'completedAtMs',
  if (before.priority != after.priority) 'priority',
  if (before.tagsJson != after.tagsJson) 'tagsJson',
  if (before.section != after.section) 'section',
  if (before.sortKey != after.sortKey) 'sortKey',
  if (before.alarmOffsetsJson != after.alarmOffsetsJson) 'alarmOffsetsJson',
  if (before.lastDismissedMs != after.lastDismissedMs) 'lastDismissedMs',
  if (before.snoozeUntilMs != after.snoozeUntilMs) 'snoozeUntilMs',
  if (before.pinned != after.pinned) 'pinned',
  if (before.estimateMinutes != after.estimateMinutes) 'estimateMinutes',
  if (before.energy != after.energy) 'energy',
  if (before.nagIntervalMinutes != after.nagIntervalMinutes)
    'nagIntervalMinutes',
  if (before.assigneeDeviceId != after.assigneeDeviceId) 'assigneeDeviceId',
  if (before.currentStreak != after.currentStreak) 'currentStreak',
  if (before.deleted != after.deleted) 'deleted',
};
