import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/db/database.dart';
import 'eisenhower.dart';
import 'todo_editor.dart';

/// Eisenhower priority-matrix view (TASKS.md 6.49): active todos laid out in
/// four importance × urgency quadrants. A read-only lens over the same data
/// as the list — tapping a todo opens the normal editor.
class EisenhowerScreen extends ConsumerWidget {
  const EisenhowerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todos = ref.watch(allActiveTodosProvider);
    final now = ref.watch(clockProvider).now();
    return Scaffold(
      appBar: AppBar(title: const Text('Priority matrix')),
      body: switch (todos) {
        AsyncData(:final value) => _Matrix(
          buckets: eisenhowerBuckets(value, now),
        ),
        AsyncError(:final error) => Center(child: Text('Error: $error')),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _Matrix extends StatelessWidget {
  const _Matrix({required this.buckets});

  final EisenhowerBuckets buckets;

  @override
  Widget build(BuildContext context) {
    Widget cell(EisenhowerQuadrant q) => Expanded(
      child: _QuadrantCard(quadrant: q, todos: buckets[q]),
    );
    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              cell(EisenhowerQuadrant.doFirst),
              cell(EisenhowerQuadrant.schedule),
            ],
          ),
        ),
        Expanded(
          child: Row(
            children: [
              cell(EisenhowerQuadrant.delegate),
              cell(EisenhowerQuadrant.eliminate),
            ],
          ),
        ),
      ],
    );
  }
}

class _QuadrantCard extends StatelessWidget {
  const _QuadrantCard({required this.quadrant, required this.todos});

  final EisenhowerQuadrant quadrant;
  final List<Todo> todos;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.all(6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${quadrant.title} (${todos.length})',
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(color: scheme.primary),
                ),
                Text(
                  quadrant.subtitle,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Expanded(
            child: todos.isEmpty
                ? Center(
                    child: Text(
                      'Nothing here',
                      style: TextStyle(color: scheme.outline),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.only(bottom: 8),
                    children: [
                      for (final todo in todos)
                        ListTile(
                          dense: true,
                          title: Text(
                            todo.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => TodoEditorScreen(todo: todo),
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
