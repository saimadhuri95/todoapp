// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $TodoListsTable extends TodoLists
    with TableInfo<$TodoListsTable, TodoList> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TodoListsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _colorMeta = const VerificationMeta('color');
  @override
  late final GeneratedColumn<int> color = GeneratedColumn<int>(
    'color',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _deletedMeta = const VerificationMeta(
    'deleted',
  );
  @override
  late final GeneratedColumn<bool> deleted = GeneratedColumn<bool>(
    'deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, color, sortOrder, deleted];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'todo_lists';
  @override
  VerificationContext validateIntegrity(
    Insertable<TodoList> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('color')) {
      context.handle(
        _colorMeta,
        color.isAcceptableOrUnknown(data['color']!, _colorMeta),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('deleted')) {
      context.handle(
        _deletedMeta,
        deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TodoList map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TodoList(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      color: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}color'],
      ),
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      deleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}deleted'],
      )!,
    );
  }

  @override
  $TodoListsTable createAlias(String alias) {
    return $TodoListsTable(attachedDatabase, alias);
  }
}

class TodoList extends DataClass implements Insertable<TodoList> {
  final String id;
  final String name;
  final int? color;
  final int sortOrder;
  final bool deleted;
  const TodoList({
    required this.id,
    required this.name,
    this.color,
    required this.sortOrder,
    required this.deleted,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || color != null) {
      map['color'] = Variable<int>(color);
    }
    map['sort_order'] = Variable<int>(sortOrder);
    map['deleted'] = Variable<bool>(deleted);
    return map;
  }

  TodoListsCompanion toCompanion(bool nullToAbsent) {
    return TodoListsCompanion(
      id: Value(id),
      name: Value(name),
      color: color == null && nullToAbsent
          ? const Value.absent()
          : Value(color),
      sortOrder: Value(sortOrder),
      deleted: Value(deleted),
    );
  }

  factory TodoList.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TodoList(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      color: serializer.fromJson<int?>(json['color']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      deleted: serializer.fromJson<bool>(json['deleted']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'color': serializer.toJson<int?>(color),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'deleted': serializer.toJson<bool>(deleted),
    };
  }

  TodoList copyWith({
    String? id,
    String? name,
    Value<int?> color = const Value.absent(),
    int? sortOrder,
    bool? deleted,
  }) => TodoList(
    id: id ?? this.id,
    name: name ?? this.name,
    color: color.present ? color.value : this.color,
    sortOrder: sortOrder ?? this.sortOrder,
    deleted: deleted ?? this.deleted,
  );
  TodoList copyWithCompanion(TodoListsCompanion data) {
    return TodoList(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      color: data.color.present ? data.color.value : this.color,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TodoList(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('color: $color, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('deleted: $deleted')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, color, sortOrder, deleted);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TodoList &&
          other.id == this.id &&
          other.name == this.name &&
          other.color == this.color &&
          other.sortOrder == this.sortOrder &&
          other.deleted == this.deleted);
}

class TodoListsCompanion extends UpdateCompanion<TodoList> {
  final Value<String> id;
  final Value<String> name;
  final Value<int?> color;
  final Value<int> sortOrder;
  final Value<bool> deleted;
  final Value<int> rowid;
  const TodoListsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.color = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.deleted = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TodoListsCompanion.insert({
    required String id,
    required String name,
    this.color = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.deleted = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name);
  static Insertable<TodoList> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<int>? color,
    Expression<int>? sortOrder,
    Expression<bool>? deleted,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (color != null) 'color': color,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (deleted != null) 'deleted': deleted,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TodoListsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<int?>? color,
    Value<int>? sortOrder,
    Value<bool>? deleted,
    Value<int>? rowid,
  }) {
    return TodoListsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
      sortOrder: sortOrder ?? this.sortOrder,
      deleted: deleted ?? this.deleted,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (color.present) {
      map['color'] = Variable<int>(color.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<bool>(deleted.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TodoListsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('color: $color, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('deleted: $deleted, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TodosTable extends Todos with TableInfo<$TodosTable, Todo> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TodosTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _listIdMeta = const VerificationMeta('listId');
  @override
  late final GeneratedColumn<String> listId = GeneratedColumn<String>(
    'list_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES todo_lists (id)',
    ),
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _dueAtMsMeta = const VerificationMeta(
    'dueAtMs',
  );
  @override
  late final GeneratedColumn<int> dueAtMs = GeneratedColumn<int>(
    'due_at_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _recurrenceRuleMeta = const VerificationMeta(
    'recurrenceRule',
  );
  @override
  late final GeneratedColumn<String> recurrenceRule = GeneratedColumn<String>(
    'recurrence_rule',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _completedAtMsMeta = const VerificationMeta(
    'completedAtMs',
  );
  @override
  late final GeneratedColumn<int> completedAtMs = GeneratedColumn<int>(
    'completed_at_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _priorityMeta = const VerificationMeta(
    'priority',
  );
  @override
  late final GeneratedColumn<int> priority = GeneratedColumn<int>(
    'priority',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _tagsJsonMeta = const VerificationMeta(
    'tagsJson',
  );
  @override
  late final GeneratedColumn<String> tagsJson = GeneratedColumn<String>(
    'tags_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _deletedMeta = const VerificationMeta(
    'deleted',
  );
  @override
  late final GeneratedColumn<bool> deleted = GeneratedColumn<bool>(
    'deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    listId,
    title,
    notes,
    dueAtMs,
    recurrenceRule,
    completedAtMs,
    priority,
    tagsJson,
    deleted,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'todos';
  @override
  VerificationContext validateIntegrity(
    Insertable<Todo> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('list_id')) {
      context.handle(
        _listIdMeta,
        listId.isAcceptableOrUnknown(data['list_id']!, _listIdMeta),
      );
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('due_at_ms')) {
      context.handle(
        _dueAtMsMeta,
        dueAtMs.isAcceptableOrUnknown(data['due_at_ms']!, _dueAtMsMeta),
      );
    }
    if (data.containsKey('recurrence_rule')) {
      context.handle(
        _recurrenceRuleMeta,
        recurrenceRule.isAcceptableOrUnknown(
          data['recurrence_rule']!,
          _recurrenceRuleMeta,
        ),
      );
    }
    if (data.containsKey('completed_at_ms')) {
      context.handle(
        _completedAtMsMeta,
        completedAtMs.isAcceptableOrUnknown(
          data['completed_at_ms']!,
          _completedAtMsMeta,
        ),
      );
    }
    if (data.containsKey('priority')) {
      context.handle(
        _priorityMeta,
        priority.isAcceptableOrUnknown(data['priority']!, _priorityMeta),
      );
    }
    if (data.containsKey('tags_json')) {
      context.handle(
        _tagsJsonMeta,
        tagsJson.isAcceptableOrUnknown(data['tags_json']!, _tagsJsonMeta),
      );
    }
    if (data.containsKey('deleted')) {
      context.handle(
        _deletedMeta,
        deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Todo map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Todo(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      listId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}list_id'],
      ),
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      )!,
      dueAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}due_at_ms'],
      ),
      recurrenceRule: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}recurrence_rule'],
      ),
      completedAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}completed_at_ms'],
      ),
      priority: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}priority'],
      )!,
      tagsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tags_json'],
      )!,
      deleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}deleted'],
      )!,
    );
  }

  @override
  $TodosTable createAlias(String alias) {
    return $TodosTable(attachedDatabase, alias);
  }
}

class Todo extends DataClass implements Insertable<Todo> {
  final String id;
  final String? listId;
  final String title;
  final String notes;
  final int? dueAtMs;
  final String? recurrenceRule;
  final int? completedAtMs;
  final int priority;
  final String tagsJson;
  final bool deleted;
  const Todo({
    required this.id,
    this.listId,
    required this.title,
    required this.notes,
    this.dueAtMs,
    this.recurrenceRule,
    this.completedAtMs,
    required this.priority,
    required this.tagsJson,
    required this.deleted,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || listId != null) {
      map['list_id'] = Variable<String>(listId);
    }
    map['title'] = Variable<String>(title);
    map['notes'] = Variable<String>(notes);
    if (!nullToAbsent || dueAtMs != null) {
      map['due_at_ms'] = Variable<int>(dueAtMs);
    }
    if (!nullToAbsent || recurrenceRule != null) {
      map['recurrence_rule'] = Variable<String>(recurrenceRule);
    }
    if (!nullToAbsent || completedAtMs != null) {
      map['completed_at_ms'] = Variable<int>(completedAtMs);
    }
    map['priority'] = Variable<int>(priority);
    map['tags_json'] = Variable<String>(tagsJson);
    map['deleted'] = Variable<bool>(deleted);
    return map;
  }

  TodosCompanion toCompanion(bool nullToAbsent) {
    return TodosCompanion(
      id: Value(id),
      listId: listId == null && nullToAbsent
          ? const Value.absent()
          : Value(listId),
      title: Value(title),
      notes: Value(notes),
      dueAtMs: dueAtMs == null && nullToAbsent
          ? const Value.absent()
          : Value(dueAtMs),
      recurrenceRule: recurrenceRule == null && nullToAbsent
          ? const Value.absent()
          : Value(recurrenceRule),
      completedAtMs: completedAtMs == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAtMs),
      priority: Value(priority),
      tagsJson: Value(tagsJson),
      deleted: Value(deleted),
    );
  }

  factory Todo.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Todo(
      id: serializer.fromJson<String>(json['id']),
      listId: serializer.fromJson<String?>(json['listId']),
      title: serializer.fromJson<String>(json['title']),
      notes: serializer.fromJson<String>(json['notes']),
      dueAtMs: serializer.fromJson<int?>(json['dueAtMs']),
      recurrenceRule: serializer.fromJson<String?>(json['recurrenceRule']),
      completedAtMs: serializer.fromJson<int?>(json['completedAtMs']),
      priority: serializer.fromJson<int>(json['priority']),
      tagsJson: serializer.fromJson<String>(json['tagsJson']),
      deleted: serializer.fromJson<bool>(json['deleted']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'listId': serializer.toJson<String?>(listId),
      'title': serializer.toJson<String>(title),
      'notes': serializer.toJson<String>(notes),
      'dueAtMs': serializer.toJson<int?>(dueAtMs),
      'recurrenceRule': serializer.toJson<String?>(recurrenceRule),
      'completedAtMs': serializer.toJson<int?>(completedAtMs),
      'priority': serializer.toJson<int>(priority),
      'tagsJson': serializer.toJson<String>(tagsJson),
      'deleted': serializer.toJson<bool>(deleted),
    };
  }

  Todo copyWith({
    String? id,
    Value<String?> listId = const Value.absent(),
    String? title,
    String? notes,
    Value<int?> dueAtMs = const Value.absent(),
    Value<String?> recurrenceRule = const Value.absent(),
    Value<int?> completedAtMs = const Value.absent(),
    int? priority,
    String? tagsJson,
    bool? deleted,
  }) => Todo(
    id: id ?? this.id,
    listId: listId.present ? listId.value : this.listId,
    title: title ?? this.title,
    notes: notes ?? this.notes,
    dueAtMs: dueAtMs.present ? dueAtMs.value : this.dueAtMs,
    recurrenceRule: recurrenceRule.present
        ? recurrenceRule.value
        : this.recurrenceRule,
    completedAtMs: completedAtMs.present
        ? completedAtMs.value
        : this.completedAtMs,
    priority: priority ?? this.priority,
    tagsJson: tagsJson ?? this.tagsJson,
    deleted: deleted ?? this.deleted,
  );
  Todo copyWithCompanion(TodosCompanion data) {
    return Todo(
      id: data.id.present ? data.id.value : this.id,
      listId: data.listId.present ? data.listId.value : this.listId,
      title: data.title.present ? data.title.value : this.title,
      notes: data.notes.present ? data.notes.value : this.notes,
      dueAtMs: data.dueAtMs.present ? data.dueAtMs.value : this.dueAtMs,
      recurrenceRule: data.recurrenceRule.present
          ? data.recurrenceRule.value
          : this.recurrenceRule,
      completedAtMs: data.completedAtMs.present
          ? data.completedAtMs.value
          : this.completedAtMs,
      priority: data.priority.present ? data.priority.value : this.priority,
      tagsJson: data.tagsJson.present ? data.tagsJson.value : this.tagsJson,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Todo(')
          ..write('id: $id, ')
          ..write('listId: $listId, ')
          ..write('title: $title, ')
          ..write('notes: $notes, ')
          ..write('dueAtMs: $dueAtMs, ')
          ..write('recurrenceRule: $recurrenceRule, ')
          ..write('completedAtMs: $completedAtMs, ')
          ..write('priority: $priority, ')
          ..write('tagsJson: $tagsJson, ')
          ..write('deleted: $deleted')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    listId,
    title,
    notes,
    dueAtMs,
    recurrenceRule,
    completedAtMs,
    priority,
    tagsJson,
    deleted,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Todo &&
          other.id == this.id &&
          other.listId == this.listId &&
          other.title == this.title &&
          other.notes == this.notes &&
          other.dueAtMs == this.dueAtMs &&
          other.recurrenceRule == this.recurrenceRule &&
          other.completedAtMs == this.completedAtMs &&
          other.priority == this.priority &&
          other.tagsJson == this.tagsJson &&
          other.deleted == this.deleted);
}

class TodosCompanion extends UpdateCompanion<Todo> {
  final Value<String> id;
  final Value<String?> listId;
  final Value<String> title;
  final Value<String> notes;
  final Value<int?> dueAtMs;
  final Value<String?> recurrenceRule;
  final Value<int?> completedAtMs;
  final Value<int> priority;
  final Value<String> tagsJson;
  final Value<bool> deleted;
  final Value<int> rowid;
  const TodosCompanion({
    this.id = const Value.absent(),
    this.listId = const Value.absent(),
    this.title = const Value.absent(),
    this.notes = const Value.absent(),
    this.dueAtMs = const Value.absent(),
    this.recurrenceRule = const Value.absent(),
    this.completedAtMs = const Value.absent(),
    this.priority = const Value.absent(),
    this.tagsJson = const Value.absent(),
    this.deleted = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TodosCompanion.insert({
    required String id,
    this.listId = const Value.absent(),
    required String title,
    this.notes = const Value.absent(),
    this.dueAtMs = const Value.absent(),
    this.recurrenceRule = const Value.absent(),
    this.completedAtMs = const Value.absent(),
    this.priority = const Value.absent(),
    this.tagsJson = const Value.absent(),
    this.deleted = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       title = Value(title);
  static Insertable<Todo> custom({
    Expression<String>? id,
    Expression<String>? listId,
    Expression<String>? title,
    Expression<String>? notes,
    Expression<int>? dueAtMs,
    Expression<String>? recurrenceRule,
    Expression<int>? completedAtMs,
    Expression<int>? priority,
    Expression<String>? tagsJson,
    Expression<bool>? deleted,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (listId != null) 'list_id': listId,
      if (title != null) 'title': title,
      if (notes != null) 'notes': notes,
      if (dueAtMs != null) 'due_at_ms': dueAtMs,
      if (recurrenceRule != null) 'recurrence_rule': recurrenceRule,
      if (completedAtMs != null) 'completed_at_ms': completedAtMs,
      if (priority != null) 'priority': priority,
      if (tagsJson != null) 'tags_json': tagsJson,
      if (deleted != null) 'deleted': deleted,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TodosCompanion copyWith({
    Value<String>? id,
    Value<String?>? listId,
    Value<String>? title,
    Value<String>? notes,
    Value<int?>? dueAtMs,
    Value<String?>? recurrenceRule,
    Value<int?>? completedAtMs,
    Value<int>? priority,
    Value<String>? tagsJson,
    Value<bool>? deleted,
    Value<int>? rowid,
  }) {
    return TodosCompanion(
      id: id ?? this.id,
      listId: listId ?? this.listId,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      dueAtMs: dueAtMs ?? this.dueAtMs,
      recurrenceRule: recurrenceRule ?? this.recurrenceRule,
      completedAtMs: completedAtMs ?? this.completedAtMs,
      priority: priority ?? this.priority,
      tagsJson: tagsJson ?? this.tagsJson,
      deleted: deleted ?? this.deleted,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (listId.present) {
      map['list_id'] = Variable<String>(listId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (dueAtMs.present) {
      map['due_at_ms'] = Variable<int>(dueAtMs.value);
    }
    if (recurrenceRule.present) {
      map['recurrence_rule'] = Variable<String>(recurrenceRule.value);
    }
    if (completedAtMs.present) {
      map['completed_at_ms'] = Variable<int>(completedAtMs.value);
    }
    if (priority.present) {
      map['priority'] = Variable<int>(priority.value);
    }
    if (tagsJson.present) {
      map['tags_json'] = Variable<String>(tagsJson.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<bool>(deleted.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TodosCompanion(')
          ..write('id: $id, ')
          ..write('listId: $listId, ')
          ..write('title: $title, ')
          ..write('notes: $notes, ')
          ..write('dueAtMs: $dueAtMs, ')
          ..write('recurrenceRule: $recurrenceRule, ')
          ..write('completedAtMs: $completedAtMs, ')
          ..write('priority: $priority, ')
          ..write('tagsJson: $tagsJson, ')
          ..write('deleted: $deleted, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TodoAlarmsTable extends TodoAlarms
    with TableInfo<$TodoAlarmsTable, TodoAlarm> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TodoAlarmsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _todoIdMeta = const VerificationMeta('todoId');
  @override
  late final GeneratedColumn<String> todoId = GeneratedColumn<String>(
    'todo_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES todos (id)',
    ),
  );
  static const VerificationMeta _atLocalMeta = const VerificationMeta(
    'atLocal',
  );
  @override
  late final GeneratedColumn<String> atLocal = GeneratedColumn<String>(
    'at_local',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tzMeta = const VerificationMeta('tz');
  @override
  late final GeneratedColumn<String> tz = GeneratedColumn<String>(
    'tz',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedMeta = const VerificationMeta(
    'deleted',
  );
  @override
  late final GeneratedColumn<bool> deleted = GeneratedColumn<bool>(
    'deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [id, todoId, atLocal, tz, deleted];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'todo_alarms';
  @override
  VerificationContext validateIntegrity(
    Insertable<TodoAlarm> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('todo_id')) {
      context.handle(
        _todoIdMeta,
        todoId.isAcceptableOrUnknown(data['todo_id']!, _todoIdMeta),
      );
    } else if (isInserting) {
      context.missing(_todoIdMeta);
    }
    if (data.containsKey('at_local')) {
      context.handle(
        _atLocalMeta,
        atLocal.isAcceptableOrUnknown(data['at_local']!, _atLocalMeta),
      );
    } else if (isInserting) {
      context.missing(_atLocalMeta);
    }
    if (data.containsKey('tz')) {
      context.handle(_tzMeta, tz.isAcceptableOrUnknown(data['tz']!, _tzMeta));
    } else if (isInserting) {
      context.missing(_tzMeta);
    }
    if (data.containsKey('deleted')) {
      context.handle(
        _deletedMeta,
        deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TodoAlarm map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TodoAlarm(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      todoId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}todo_id'],
      )!,
      atLocal: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}at_local'],
      )!,
      tz: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tz'],
      )!,
      deleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}deleted'],
      )!,
    );
  }

  @override
  $TodoAlarmsTable createAlias(String alias) {
    return $TodoAlarmsTable(attachedDatabase, alias);
  }
}

class TodoAlarm extends DataClass implements Insertable<TodoAlarm> {
  final String id;
  final String todoId;

  /// Local wall time, ISO-8601 without offset (e.g. `2026-07-05T09:00`).
  final String atLocal;

  /// IANA zone id the wall time is anchored to (e.g. `Asia/Kolkata`).
  final String tz;
  final bool deleted;
  const TodoAlarm({
    required this.id,
    required this.todoId,
    required this.atLocal,
    required this.tz,
    required this.deleted,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['todo_id'] = Variable<String>(todoId);
    map['at_local'] = Variable<String>(atLocal);
    map['tz'] = Variable<String>(tz);
    map['deleted'] = Variable<bool>(deleted);
    return map;
  }

  TodoAlarmsCompanion toCompanion(bool nullToAbsent) {
    return TodoAlarmsCompanion(
      id: Value(id),
      todoId: Value(todoId),
      atLocal: Value(atLocal),
      tz: Value(tz),
      deleted: Value(deleted),
    );
  }

  factory TodoAlarm.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TodoAlarm(
      id: serializer.fromJson<String>(json['id']),
      todoId: serializer.fromJson<String>(json['todoId']),
      atLocal: serializer.fromJson<String>(json['atLocal']),
      tz: serializer.fromJson<String>(json['tz']),
      deleted: serializer.fromJson<bool>(json['deleted']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'todoId': serializer.toJson<String>(todoId),
      'atLocal': serializer.toJson<String>(atLocal),
      'tz': serializer.toJson<String>(tz),
      'deleted': serializer.toJson<bool>(deleted),
    };
  }

  TodoAlarm copyWith({
    String? id,
    String? todoId,
    String? atLocal,
    String? tz,
    bool? deleted,
  }) => TodoAlarm(
    id: id ?? this.id,
    todoId: todoId ?? this.todoId,
    atLocal: atLocal ?? this.atLocal,
    tz: tz ?? this.tz,
    deleted: deleted ?? this.deleted,
  );
  TodoAlarm copyWithCompanion(TodoAlarmsCompanion data) {
    return TodoAlarm(
      id: data.id.present ? data.id.value : this.id,
      todoId: data.todoId.present ? data.todoId.value : this.todoId,
      atLocal: data.atLocal.present ? data.atLocal.value : this.atLocal,
      tz: data.tz.present ? data.tz.value : this.tz,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TodoAlarm(')
          ..write('id: $id, ')
          ..write('todoId: $todoId, ')
          ..write('atLocal: $atLocal, ')
          ..write('tz: $tz, ')
          ..write('deleted: $deleted')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, todoId, atLocal, tz, deleted);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TodoAlarm &&
          other.id == this.id &&
          other.todoId == this.todoId &&
          other.atLocal == this.atLocal &&
          other.tz == this.tz &&
          other.deleted == this.deleted);
}

class TodoAlarmsCompanion extends UpdateCompanion<TodoAlarm> {
  final Value<String> id;
  final Value<String> todoId;
  final Value<String> atLocal;
  final Value<String> tz;
  final Value<bool> deleted;
  final Value<int> rowid;
  const TodoAlarmsCompanion({
    this.id = const Value.absent(),
    this.todoId = const Value.absent(),
    this.atLocal = const Value.absent(),
    this.tz = const Value.absent(),
    this.deleted = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TodoAlarmsCompanion.insert({
    required String id,
    required String todoId,
    required String atLocal,
    required String tz,
    this.deleted = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       todoId = Value(todoId),
       atLocal = Value(atLocal),
       tz = Value(tz);
  static Insertable<TodoAlarm> custom({
    Expression<String>? id,
    Expression<String>? todoId,
    Expression<String>? atLocal,
    Expression<String>? tz,
    Expression<bool>? deleted,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (todoId != null) 'todo_id': todoId,
      if (atLocal != null) 'at_local': atLocal,
      if (tz != null) 'tz': tz,
      if (deleted != null) 'deleted': deleted,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TodoAlarmsCompanion copyWith({
    Value<String>? id,
    Value<String>? todoId,
    Value<String>? atLocal,
    Value<String>? tz,
    Value<bool>? deleted,
    Value<int>? rowid,
  }) {
    return TodoAlarmsCompanion(
      id: id ?? this.id,
      todoId: todoId ?? this.todoId,
      atLocal: atLocal ?? this.atLocal,
      tz: tz ?? this.tz,
      deleted: deleted ?? this.deleted,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (todoId.present) {
      map['todo_id'] = Variable<String>(todoId.value);
    }
    if (atLocal.present) {
      map['at_local'] = Variable<String>(atLocal.value);
    }
    if (tz.present) {
      map['tz'] = Variable<String>(tz.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<bool>(deleted.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TodoAlarmsCompanion(')
          ..write('id: $id, ')
          ..write('todoId: $todoId, ')
          ..write('atLocal: $atLocal, ')
          ..write('tz: $tz, ')
          ..write('deleted: $deleted, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DevicesTable extends Devices with TableInfo<$DevicesTable, Device> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DevicesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _platformMeta = const VerificationMeta(
    'platform',
  );
  @override
  late final GeneratedColumn<String> platform = GeneratedColumn<String>(
    'platform',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _publicKeyMeta = const VerificationMeta(
    'publicKey',
  );
  @override
  late final GeneratedColumn<String> publicKey = GeneratedColumn<String>(
    'public_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastSeenAtMsMeta = const VerificationMeta(
    'lastSeenAtMs',
  );
  @override
  late final GeneratedColumn<int> lastSeenAtMs = GeneratedColumn<int>(
    'last_seen_at_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    platform,
    publicKey,
    lastSeenAtMs,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'devices';
  @override
  VerificationContext validateIntegrity(
    Insertable<Device> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('platform')) {
      context.handle(
        _platformMeta,
        platform.isAcceptableOrUnknown(data['platform']!, _platformMeta),
      );
    } else if (isInserting) {
      context.missing(_platformMeta);
    }
    if (data.containsKey('public_key')) {
      context.handle(
        _publicKeyMeta,
        publicKey.isAcceptableOrUnknown(data['public_key']!, _publicKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_publicKeyMeta);
    }
    if (data.containsKey('last_seen_at_ms')) {
      context.handle(
        _lastSeenAtMsMeta,
        lastSeenAtMs.isAcceptableOrUnknown(
          data['last_seen_at_ms']!,
          _lastSeenAtMsMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Device map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Device(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      platform: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}platform'],
      )!,
      publicKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}public_key'],
      )!,
      lastSeenAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_seen_at_ms'],
      ),
    );
  }

  @override
  $DevicesTable createAlias(String alias) {
    return $DevicesTable(attachedDatabase, alias);
  }
}

class Device extends DataClass implements Insertable<Device> {
  final String id;
  final String name;
  final String platform;
  final String publicKey;
  final int? lastSeenAtMs;
  const Device({
    required this.id,
    required this.name,
    required this.platform,
    required this.publicKey,
    this.lastSeenAtMs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['platform'] = Variable<String>(platform);
    map['public_key'] = Variable<String>(publicKey);
    if (!nullToAbsent || lastSeenAtMs != null) {
      map['last_seen_at_ms'] = Variable<int>(lastSeenAtMs);
    }
    return map;
  }

  DevicesCompanion toCompanion(bool nullToAbsent) {
    return DevicesCompanion(
      id: Value(id),
      name: Value(name),
      platform: Value(platform),
      publicKey: Value(publicKey),
      lastSeenAtMs: lastSeenAtMs == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSeenAtMs),
    );
  }

  factory Device.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Device(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      platform: serializer.fromJson<String>(json['platform']),
      publicKey: serializer.fromJson<String>(json['publicKey']),
      lastSeenAtMs: serializer.fromJson<int?>(json['lastSeenAtMs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'platform': serializer.toJson<String>(platform),
      'publicKey': serializer.toJson<String>(publicKey),
      'lastSeenAtMs': serializer.toJson<int?>(lastSeenAtMs),
    };
  }

  Device copyWith({
    String? id,
    String? name,
    String? platform,
    String? publicKey,
    Value<int?> lastSeenAtMs = const Value.absent(),
  }) => Device(
    id: id ?? this.id,
    name: name ?? this.name,
    platform: platform ?? this.platform,
    publicKey: publicKey ?? this.publicKey,
    lastSeenAtMs: lastSeenAtMs.present ? lastSeenAtMs.value : this.lastSeenAtMs,
  );
  Device copyWithCompanion(DevicesCompanion data) {
    return Device(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      platform: data.platform.present ? data.platform.value : this.platform,
      publicKey: data.publicKey.present ? data.publicKey.value : this.publicKey,
      lastSeenAtMs: data.lastSeenAtMs.present
          ? data.lastSeenAtMs.value
          : this.lastSeenAtMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Device(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('platform: $platform, ')
          ..write('publicKey: $publicKey, ')
          ..write('lastSeenAtMs: $lastSeenAtMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, platform, publicKey, lastSeenAtMs);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Device &&
          other.id == this.id &&
          other.name == this.name &&
          other.platform == this.platform &&
          other.publicKey == this.publicKey &&
          other.lastSeenAtMs == this.lastSeenAtMs);
}

class DevicesCompanion extends UpdateCompanion<Device> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> platform;
  final Value<String> publicKey;
  final Value<int?> lastSeenAtMs;
  final Value<int> rowid;
  const DevicesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.platform = const Value.absent(),
    this.publicKey = const Value.absent(),
    this.lastSeenAtMs = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DevicesCompanion.insert({
    required String id,
    required String name,
    required String platform,
    required String publicKey,
    this.lastSeenAtMs = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       platform = Value(platform),
       publicKey = Value(publicKey);
  static Insertable<Device> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? platform,
    Expression<String>? publicKey,
    Expression<int>? lastSeenAtMs,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (platform != null) 'platform': platform,
      if (publicKey != null) 'public_key': publicKey,
      if (lastSeenAtMs != null) 'last_seen_at_ms': lastSeenAtMs,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DevicesCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? platform,
    Value<String>? publicKey,
    Value<int?>? lastSeenAtMs,
    Value<int>? rowid,
  }) {
    return DevicesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      platform: platform ?? this.platform,
      publicKey: publicKey ?? this.publicKey,
      lastSeenAtMs: lastSeenAtMs ?? this.lastSeenAtMs,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (platform.present) {
      map['platform'] = Variable<String>(platform.value);
    }
    if (publicKey.present) {
      map['public_key'] = Variable<String>(publicKey.value);
    }
    if (lastSeenAtMs.present) {
      map['last_seen_at_ms'] = Variable<int>(lastSeenAtMs.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DevicesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('platform: $platform, ')
          ..write('publicKey: $publicKey, ')
          ..write('lastSeenAtMs: $lastSeenAtMs, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncLogTable extends SyncLog with TableInfo<$SyncLogTable, SyncLogData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncLogTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _peerIdMeta = const VerificationMeta('peerId');
  @override
  late final GeneratedColumn<String> peerId = GeneratedColumn<String>(
    'peer_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastAppliedHlcMeta = const VerificationMeta(
    'lastAppliedHlc',
  );
  @override
  late final GeneratedColumn<String> lastAppliedHlc = GeneratedColumn<String>(
    'last_applied_hlc',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  @override
  List<GeneratedColumn> get $columns => [peerId, lastAppliedHlc];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_log';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncLogData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('peer_id')) {
      context.handle(
        _peerIdMeta,
        peerId.isAcceptableOrUnknown(data['peer_id']!, _peerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_peerIdMeta);
    }
    if (data.containsKey('last_applied_hlc')) {
      context.handle(
        _lastAppliedHlcMeta,
        lastAppliedHlc.isAcceptableOrUnknown(
          data['last_applied_hlc']!,
          _lastAppliedHlcMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {peerId};
  @override
  SyncLogData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncLogData(
      peerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}peer_id'],
      )!,
      lastAppliedHlc: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_applied_hlc'],
      )!,
    );
  }

  @override
  $SyncLogTable createAlias(String alias) {
    return $SyncLogTable(attachedDatabase, alias);
  }
}

class SyncLogData extends DataClass implements Insertable<SyncLogData> {
  final String peerId;
  final String lastAppliedHlc;
  const SyncLogData({required this.peerId, required this.lastAppliedHlc});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['peer_id'] = Variable<String>(peerId);
    map['last_applied_hlc'] = Variable<String>(lastAppliedHlc);
    return map;
  }

  SyncLogCompanion toCompanion(bool nullToAbsent) {
    return SyncLogCompanion(
      peerId: Value(peerId),
      lastAppliedHlc: Value(lastAppliedHlc),
    );
  }

  factory SyncLogData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncLogData(
      peerId: serializer.fromJson<String>(json['peerId']),
      lastAppliedHlc: serializer.fromJson<String>(json['lastAppliedHlc']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'peerId': serializer.toJson<String>(peerId),
      'lastAppliedHlc': serializer.toJson<String>(lastAppliedHlc),
    };
  }

  SyncLogData copyWith({String? peerId, String? lastAppliedHlc}) => SyncLogData(
    peerId: peerId ?? this.peerId,
    lastAppliedHlc: lastAppliedHlc ?? this.lastAppliedHlc,
  );
  SyncLogData copyWithCompanion(SyncLogCompanion data) {
    return SyncLogData(
      peerId: data.peerId.present ? data.peerId.value : this.peerId,
      lastAppliedHlc: data.lastAppliedHlc.present
          ? data.lastAppliedHlc.value
          : this.lastAppliedHlc,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncLogData(')
          ..write('peerId: $peerId, ')
          ..write('lastAppliedHlc: $lastAppliedHlc')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(peerId, lastAppliedHlc);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncLogData &&
          other.peerId == this.peerId &&
          other.lastAppliedHlc == this.lastAppliedHlc);
}

class SyncLogCompanion extends UpdateCompanion<SyncLogData> {
  final Value<String> peerId;
  final Value<String> lastAppliedHlc;
  final Value<int> rowid;
  const SyncLogCompanion({
    this.peerId = const Value.absent(),
    this.lastAppliedHlc = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncLogCompanion.insert({
    required String peerId,
    this.lastAppliedHlc = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : peerId = Value(peerId);
  static Insertable<SyncLogData> custom({
    Expression<String>? peerId,
    Expression<String>? lastAppliedHlc,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (peerId != null) 'peer_id': peerId,
      if (lastAppliedHlc != null) 'last_applied_hlc': lastAppliedHlc,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncLogCompanion copyWith({
    Value<String>? peerId,
    Value<String>? lastAppliedHlc,
    Value<int>? rowid,
  }) {
    return SyncLogCompanion(
      peerId: peerId ?? this.peerId,
      lastAppliedHlc: lastAppliedHlc ?? this.lastAppliedHlc,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (peerId.present) {
      map['peer_id'] = Variable<String>(peerId.value);
    }
    if (lastAppliedHlc.present) {
      map['last_applied_hlc'] = Variable<String>(lastAppliedHlc.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncLogCompanion(')
          ..write('peerId: $peerId, ')
          ..write('lastAppliedHlc: $lastAppliedHlc, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AlarmDismissalsTable extends AlarmDismissals
    with TableInfo<$AlarmDismissalsTable, AlarmDismissal> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AlarmDismissalsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _alarmIdMeta = const VerificationMeta(
    'alarmId',
  );
  @override
  late final GeneratedColumn<String> alarmId = GeneratedColumn<String>(
    'alarm_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES todo_alarms (id)',
    ),
  );
  static const VerificationMeta _occurrenceMsMeta = const VerificationMeta(
    'occurrenceMs',
  );
  @override
  late final GeneratedColumn<int> occurrenceMs = GeneratedColumn<int>(
    'occurrence_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dismissedByMeta = const VerificationMeta(
    'dismissedBy',
  );
  @override
  late final GeneratedColumn<String> dismissedBy = GeneratedColumn<String>(
    'dismissed_by',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _hlcMeta = const VerificationMeta('hlc');
  @override
  late final GeneratedColumn<String> hlc = GeneratedColumn<String>(
    'hlc',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _actionMeta = const VerificationMeta('action');
  @override
  late final GeneratedColumn<String> action = GeneratedColumn<String>(
    'action',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _snoozeUntilMsMeta = const VerificationMeta(
    'snoozeUntilMs',
  );
  @override
  late final GeneratedColumn<int> snoozeUntilMs = GeneratedColumn<int>(
    'snooze_until_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    alarmId,
    occurrenceMs,
    dismissedBy,
    hlc,
    action,
    snoozeUntilMs,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'alarm_dismissals';
  @override
  VerificationContext validateIntegrity(
    Insertable<AlarmDismissal> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('alarm_id')) {
      context.handle(
        _alarmIdMeta,
        alarmId.isAcceptableOrUnknown(data['alarm_id']!, _alarmIdMeta),
      );
    } else if (isInserting) {
      context.missing(_alarmIdMeta);
    }
    if (data.containsKey('occurrence_ms')) {
      context.handle(
        _occurrenceMsMeta,
        occurrenceMs.isAcceptableOrUnknown(
          data['occurrence_ms']!,
          _occurrenceMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_occurrenceMsMeta);
    }
    if (data.containsKey('dismissed_by')) {
      context.handle(
        _dismissedByMeta,
        dismissedBy.isAcceptableOrUnknown(
          data['dismissed_by']!,
          _dismissedByMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_dismissedByMeta);
    }
    if (data.containsKey('hlc')) {
      context.handle(
        _hlcMeta,
        hlc.isAcceptableOrUnknown(data['hlc']!, _hlcMeta),
      );
    } else if (isInserting) {
      context.missing(_hlcMeta);
    }
    if (data.containsKey('action')) {
      context.handle(
        _actionMeta,
        action.isAcceptableOrUnknown(data['action']!, _actionMeta),
      );
    } else if (isInserting) {
      context.missing(_actionMeta);
    }
    if (data.containsKey('snooze_until_ms')) {
      context.handle(
        _snoozeUntilMsMeta,
        snoozeUntilMs.isAcceptableOrUnknown(
          data['snooze_until_ms']!,
          _snoozeUntilMsMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {alarmId, occurrenceMs};
  @override
  AlarmDismissal map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AlarmDismissal(
      alarmId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}alarm_id'],
      )!,
      occurrenceMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}occurrence_ms'],
      )!,
      dismissedBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}dismissed_by'],
      )!,
      hlc: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}hlc'],
      )!,
      action: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}action'],
      )!,
      snoozeUntilMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}snooze_until_ms'],
      ),
    );
  }

  @override
  $AlarmDismissalsTable createAlias(String alias) {
    return $AlarmDismissalsTable(attachedDatabase, alias);
  }
}

class AlarmDismissal extends DataClass implements Insertable<AlarmDismissal> {
  final String alarmId;

  /// Which occurrence (UTC epoch millis) — recurring alarms fire many times.
  final int occurrenceMs;
  final String dismissedBy;
  final String hlc;

  /// 'dismiss' | 'snooze'
  final String action;
  final int? snoozeUntilMs;
  const AlarmDismissal({
    required this.alarmId,
    required this.occurrenceMs,
    required this.dismissedBy,
    required this.hlc,
    required this.action,
    this.snoozeUntilMs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['alarm_id'] = Variable<String>(alarmId);
    map['occurrence_ms'] = Variable<int>(occurrenceMs);
    map['dismissed_by'] = Variable<String>(dismissedBy);
    map['hlc'] = Variable<String>(hlc);
    map['action'] = Variable<String>(action);
    if (!nullToAbsent || snoozeUntilMs != null) {
      map['snooze_until_ms'] = Variable<int>(snoozeUntilMs);
    }
    return map;
  }

  AlarmDismissalsCompanion toCompanion(bool nullToAbsent) {
    return AlarmDismissalsCompanion(
      alarmId: Value(alarmId),
      occurrenceMs: Value(occurrenceMs),
      dismissedBy: Value(dismissedBy),
      hlc: Value(hlc),
      action: Value(action),
      snoozeUntilMs: snoozeUntilMs == null && nullToAbsent
          ? const Value.absent()
          : Value(snoozeUntilMs),
    );
  }

  factory AlarmDismissal.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AlarmDismissal(
      alarmId: serializer.fromJson<String>(json['alarmId']),
      occurrenceMs: serializer.fromJson<int>(json['occurrenceMs']),
      dismissedBy: serializer.fromJson<String>(json['dismissedBy']),
      hlc: serializer.fromJson<String>(json['hlc']),
      action: serializer.fromJson<String>(json['action']),
      snoozeUntilMs: serializer.fromJson<int?>(json['snoozeUntilMs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'alarmId': serializer.toJson<String>(alarmId),
      'occurrenceMs': serializer.toJson<int>(occurrenceMs),
      'dismissedBy': serializer.toJson<String>(dismissedBy),
      'hlc': serializer.toJson<String>(hlc),
      'action': serializer.toJson<String>(action),
      'snoozeUntilMs': serializer.toJson<int?>(snoozeUntilMs),
    };
  }

  AlarmDismissal copyWith({
    String? alarmId,
    int? occurrenceMs,
    String? dismissedBy,
    String? hlc,
    String? action,
    Value<int?> snoozeUntilMs = const Value.absent(),
  }) => AlarmDismissal(
    alarmId: alarmId ?? this.alarmId,
    occurrenceMs: occurrenceMs ?? this.occurrenceMs,
    dismissedBy: dismissedBy ?? this.dismissedBy,
    hlc: hlc ?? this.hlc,
    action: action ?? this.action,
    snoozeUntilMs: snoozeUntilMs.present
        ? snoozeUntilMs.value
        : this.snoozeUntilMs,
  );
  AlarmDismissal copyWithCompanion(AlarmDismissalsCompanion data) {
    return AlarmDismissal(
      alarmId: data.alarmId.present ? data.alarmId.value : this.alarmId,
      occurrenceMs: data.occurrenceMs.present
          ? data.occurrenceMs.value
          : this.occurrenceMs,
      dismissedBy: data.dismissedBy.present
          ? data.dismissedBy.value
          : this.dismissedBy,
      hlc: data.hlc.present ? data.hlc.value : this.hlc,
      action: data.action.present ? data.action.value : this.action,
      snoozeUntilMs: data.snoozeUntilMs.present
          ? data.snoozeUntilMs.value
          : this.snoozeUntilMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AlarmDismissal(')
          ..write('alarmId: $alarmId, ')
          ..write('occurrenceMs: $occurrenceMs, ')
          ..write('dismissedBy: $dismissedBy, ')
          ..write('hlc: $hlc, ')
          ..write('action: $action, ')
          ..write('snoozeUntilMs: $snoozeUntilMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    alarmId,
    occurrenceMs,
    dismissedBy,
    hlc,
    action,
    snoozeUntilMs,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AlarmDismissal &&
          other.alarmId == this.alarmId &&
          other.occurrenceMs == this.occurrenceMs &&
          other.dismissedBy == this.dismissedBy &&
          other.hlc == this.hlc &&
          other.action == this.action &&
          other.snoozeUntilMs == this.snoozeUntilMs);
}

class AlarmDismissalsCompanion extends UpdateCompanion<AlarmDismissal> {
  final Value<String> alarmId;
  final Value<int> occurrenceMs;
  final Value<String> dismissedBy;
  final Value<String> hlc;
  final Value<String> action;
  final Value<int?> snoozeUntilMs;
  final Value<int> rowid;
  const AlarmDismissalsCompanion({
    this.alarmId = const Value.absent(),
    this.occurrenceMs = const Value.absent(),
    this.dismissedBy = const Value.absent(),
    this.hlc = const Value.absent(),
    this.action = const Value.absent(),
    this.snoozeUntilMs = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AlarmDismissalsCompanion.insert({
    required String alarmId,
    required int occurrenceMs,
    required String dismissedBy,
    required String hlc,
    required String action,
    this.snoozeUntilMs = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : alarmId = Value(alarmId),
       occurrenceMs = Value(occurrenceMs),
       dismissedBy = Value(dismissedBy),
       hlc = Value(hlc),
       action = Value(action);
  static Insertable<AlarmDismissal> custom({
    Expression<String>? alarmId,
    Expression<int>? occurrenceMs,
    Expression<String>? dismissedBy,
    Expression<String>? hlc,
    Expression<String>? action,
    Expression<int>? snoozeUntilMs,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (alarmId != null) 'alarm_id': alarmId,
      if (occurrenceMs != null) 'occurrence_ms': occurrenceMs,
      if (dismissedBy != null) 'dismissed_by': dismissedBy,
      if (hlc != null) 'hlc': hlc,
      if (action != null) 'action': action,
      if (snoozeUntilMs != null) 'snooze_until_ms': snoozeUntilMs,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AlarmDismissalsCompanion copyWith({
    Value<String>? alarmId,
    Value<int>? occurrenceMs,
    Value<String>? dismissedBy,
    Value<String>? hlc,
    Value<String>? action,
    Value<int?>? snoozeUntilMs,
    Value<int>? rowid,
  }) {
    return AlarmDismissalsCompanion(
      alarmId: alarmId ?? this.alarmId,
      occurrenceMs: occurrenceMs ?? this.occurrenceMs,
      dismissedBy: dismissedBy ?? this.dismissedBy,
      hlc: hlc ?? this.hlc,
      action: action ?? this.action,
      snoozeUntilMs: snoozeUntilMs ?? this.snoozeUntilMs,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (alarmId.present) {
      map['alarm_id'] = Variable<String>(alarmId.value);
    }
    if (occurrenceMs.present) {
      map['occurrence_ms'] = Variable<int>(occurrenceMs.value);
    }
    if (dismissedBy.present) {
      map['dismissed_by'] = Variable<String>(dismissedBy.value);
    }
    if (hlc.present) {
      map['hlc'] = Variable<String>(hlc.value);
    }
    if (action.present) {
      map['action'] = Variable<String>(action.value);
    }
    if (snoozeUntilMs.present) {
      map['snooze_until_ms'] = Variable<int>(snoozeUntilMs.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AlarmDismissalsCompanion(')
          ..write('alarmId: $alarmId, ')
          ..write('occurrenceMs: $occurrenceMs, ')
          ..write('dismissedBy: $dismissedBy, ')
          ..write('hlc: $hlc, ')
          ..write('action: $action, ')
          ..write('snoozeUntilMs: $snoozeUntilMs, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $FieldClocksTable extends FieldClocks
    with TableInfo<$FieldClocksTable, FieldClock> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FieldClocksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _entityMeta = const VerificationMeta('entity');
  @override
  late final GeneratedColumn<String> entity = GeneratedColumn<String>(
    'entity',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rowIdMeta = const VerificationMeta('rowId');
  @override
  late final GeneratedColumn<String> rowId = GeneratedColumn<String>(
    'row_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fieldNameMeta = const VerificationMeta(
    'fieldName',
  );
  @override
  late final GeneratedColumn<String> fieldName = GeneratedColumn<String>(
    'field_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _hlcMeta = const VerificationMeta('hlc');
  @override
  late final GeneratedColumn<String> hlc = GeneratedColumn<String>(
    'hlc',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [entity, rowId, fieldName, hlc];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'field_clocks';
  @override
  VerificationContext validateIntegrity(
    Insertable<FieldClock> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('entity')) {
      context.handle(
        _entityMeta,
        entity.isAcceptableOrUnknown(data['entity']!, _entityMeta),
      );
    } else if (isInserting) {
      context.missing(_entityMeta);
    }
    if (data.containsKey('row_id')) {
      context.handle(
        _rowIdMeta,
        rowId.isAcceptableOrUnknown(data['row_id']!, _rowIdMeta),
      );
    } else if (isInserting) {
      context.missing(_rowIdMeta);
    }
    if (data.containsKey('field_name')) {
      context.handle(
        _fieldNameMeta,
        fieldName.isAcceptableOrUnknown(data['field_name']!, _fieldNameMeta),
      );
    } else if (isInserting) {
      context.missing(_fieldNameMeta);
    }
    if (data.containsKey('hlc')) {
      context.handle(
        _hlcMeta,
        hlc.isAcceptableOrUnknown(data['hlc']!, _hlcMeta),
      );
    } else if (isInserting) {
      context.missing(_hlcMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {entity, rowId, fieldName};
  @override
  FieldClock map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FieldClock(
      entity: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity'],
      )!,
      rowId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}row_id'],
      )!,
      fieldName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}field_name'],
      )!,
      hlc: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}hlc'],
      )!,
    );
  }

  @override
  $FieldClocksTable createAlias(String alias) {
    return $FieldClocksTable(attachedDatabase, alias);
  }
}

class FieldClock extends DataClass implements Insertable<FieldClock> {
  /// Which table the row lives in, e.g. 'todos'. (Named `entity` because
  /// `tableName` collides with drift's `Table.tableName`.)
  final String entity;
  final String rowId;
  final String fieldName;
  final String hlc;
  const FieldClock({
    required this.entity,
    required this.rowId,
    required this.fieldName,
    required this.hlc,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['entity'] = Variable<String>(entity);
    map['row_id'] = Variable<String>(rowId);
    map['field_name'] = Variable<String>(fieldName);
    map['hlc'] = Variable<String>(hlc);
    return map;
  }

  FieldClocksCompanion toCompanion(bool nullToAbsent) {
    return FieldClocksCompanion(
      entity: Value(entity),
      rowId: Value(rowId),
      fieldName: Value(fieldName),
      hlc: Value(hlc),
    );
  }

  factory FieldClock.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FieldClock(
      entity: serializer.fromJson<String>(json['entity']),
      rowId: serializer.fromJson<String>(json['rowId']),
      fieldName: serializer.fromJson<String>(json['fieldName']),
      hlc: serializer.fromJson<String>(json['hlc']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'entity': serializer.toJson<String>(entity),
      'rowId': serializer.toJson<String>(rowId),
      'fieldName': serializer.toJson<String>(fieldName),
      'hlc': serializer.toJson<String>(hlc),
    };
  }

  FieldClock copyWith({
    String? entity,
    String? rowId,
    String? fieldName,
    String? hlc,
  }) => FieldClock(
    entity: entity ?? this.entity,
    rowId: rowId ?? this.rowId,
    fieldName: fieldName ?? this.fieldName,
    hlc: hlc ?? this.hlc,
  );
  FieldClock copyWithCompanion(FieldClocksCompanion data) {
    return FieldClock(
      entity: data.entity.present ? data.entity.value : this.entity,
      rowId: data.rowId.present ? data.rowId.value : this.rowId,
      fieldName: data.fieldName.present ? data.fieldName.value : this.fieldName,
      hlc: data.hlc.present ? data.hlc.value : this.hlc,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FieldClock(')
          ..write('entity: $entity, ')
          ..write('rowId: $rowId, ')
          ..write('fieldName: $fieldName, ')
          ..write('hlc: $hlc')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(entity, rowId, fieldName, hlc);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FieldClock &&
          other.entity == this.entity &&
          other.rowId == this.rowId &&
          other.fieldName == this.fieldName &&
          other.hlc == this.hlc);
}

class FieldClocksCompanion extends UpdateCompanion<FieldClock> {
  final Value<String> entity;
  final Value<String> rowId;
  final Value<String> fieldName;
  final Value<String> hlc;
  final Value<int> rowid;
  const FieldClocksCompanion({
    this.entity = const Value.absent(),
    this.rowId = const Value.absent(),
    this.fieldName = const Value.absent(),
    this.hlc = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FieldClocksCompanion.insert({
    required String entity,
    required String rowId,
    required String fieldName,
    required String hlc,
    this.rowid = const Value.absent(),
  }) : entity = Value(entity),
       rowId = Value(rowId),
       fieldName = Value(fieldName),
       hlc = Value(hlc);
  static Insertable<FieldClock> custom({
    Expression<String>? entity,
    Expression<String>? rowId,
    Expression<String>? fieldName,
    Expression<String>? hlc,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (entity != null) 'entity': entity,
      if (rowId != null) 'row_id': rowId,
      if (fieldName != null) 'field_name': fieldName,
      if (hlc != null) 'hlc': hlc,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FieldClocksCompanion copyWith({
    Value<String>? entity,
    Value<String>? rowId,
    Value<String>? fieldName,
    Value<String>? hlc,
    Value<int>? rowid,
  }) {
    return FieldClocksCompanion(
      entity: entity ?? this.entity,
      rowId: rowId ?? this.rowId,
      fieldName: fieldName ?? this.fieldName,
      hlc: hlc ?? this.hlc,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (entity.present) {
      map['entity'] = Variable<String>(entity.value);
    }
    if (rowId.present) {
      map['row_id'] = Variable<String>(rowId.value);
    }
    if (fieldName.present) {
      map['field_name'] = Variable<String>(fieldName.value);
    }
    if (hlc.present) {
      map['hlc'] = Variable<String>(hlc.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FieldClocksCompanion(')
          ..write('entity: $entity, ')
          ..write('rowId: $rowId, ')
          ..write('fieldName: $fieldName, ')
          ..write('hlc: $hlc, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $TodoListsTable todoLists = $TodoListsTable(this);
  late final $TodosTable todos = $TodosTable(this);
  late final $TodoAlarmsTable todoAlarms = $TodoAlarmsTable(this);
  late final $DevicesTable devices = $DevicesTable(this);
  late final $SyncLogTable syncLog = $SyncLogTable(this);
  late final $AlarmDismissalsTable alarmDismissals = $AlarmDismissalsTable(
    this,
  );
  late final $FieldClocksTable fieldClocks = $FieldClocksTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    todoLists,
    todos,
    todoAlarms,
    devices,
    syncLog,
    alarmDismissals,
    fieldClocks,
  ];
}

typedef $$TodoListsTableCreateCompanionBuilder =
    TodoListsCompanion Function({
      required String id,
      required String name,
      Value<int?> color,
      Value<int> sortOrder,
      Value<bool> deleted,
      Value<int> rowid,
    });
typedef $$TodoListsTableUpdateCompanionBuilder =
    TodoListsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<int?> color,
      Value<int> sortOrder,
      Value<bool> deleted,
      Value<int> rowid,
    });

final class $$TodoListsTableReferences
    extends BaseReferences<_$AppDatabase, $TodoListsTable, TodoList> {
  $$TodoListsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$TodosTable, List<Todo>> _todosRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.todos,
    aliasName: 'todo_lists__id__todos__list_id',
  );

  $$TodosTableProcessedTableManager get todosRefs {
    final manager = $$TodosTableTableManager(
      $_db,
      $_db.todos,
    ).filter((f) => f.listId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_todosRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$TodoListsTableFilterComposer
    extends Composer<_$AppDatabase, $TodoListsTable> {
  $$TodoListsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> todosRefs(
    Expression<bool> Function($$TodosTableFilterComposer f) f,
  ) {
    final $$TodosTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.todos,
      getReferencedColumn: (t) => t.listId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TodosTableFilterComposer(
            $db: $db,
            $table: $db.todos,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TodoListsTableOrderingComposer
    extends Composer<_$AppDatabase, $TodoListsTable> {
  $$TodoListsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TodoListsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TodoListsTable> {
  $$TodoListsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get color =>
      $composableBuilder(column: $table.color, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);

  Expression<T> todosRefs<T extends Object>(
    Expression<T> Function($$TodosTableAnnotationComposer a) f,
  ) {
    final $$TodosTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.todos,
      getReferencedColumn: (t) => t.listId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TodosTableAnnotationComposer(
            $db: $db,
            $table: $db.todos,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TodoListsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TodoListsTable,
          TodoList,
          $$TodoListsTableFilterComposer,
          $$TodoListsTableOrderingComposer,
          $$TodoListsTableAnnotationComposer,
          $$TodoListsTableCreateCompanionBuilder,
          $$TodoListsTableUpdateCompanionBuilder,
          (TodoList, $$TodoListsTableReferences),
          TodoList,
          PrefetchHooks Function({bool todosRefs})
        > {
  $$TodoListsTableTableManager(_$AppDatabase db, $TodoListsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TodoListsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TodoListsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TodoListsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int?> color = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TodoListsCompanion(
                id: id,
                name: name,
                color: color,
                sortOrder: sortOrder,
                deleted: deleted,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<int?> color = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TodoListsCompanion.insert(
                id: id,
                name: name,
                color: color,
                sortOrder: sortOrder,
                deleted: deleted,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$TodoListsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({todosRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (todosRefs) db.todos],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (todosRefs)
                    await $_getPrefetchedData<TodoList, $TodoListsTable, Todo>(
                      currentTable: table,
                      referencedTable: $$TodoListsTableReferences
                          ._todosRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$TodoListsTableReferences(db, table, p0).todosRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.listId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$TodoListsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TodoListsTable,
      TodoList,
      $$TodoListsTableFilterComposer,
      $$TodoListsTableOrderingComposer,
      $$TodoListsTableAnnotationComposer,
      $$TodoListsTableCreateCompanionBuilder,
      $$TodoListsTableUpdateCompanionBuilder,
      (TodoList, $$TodoListsTableReferences),
      TodoList,
      PrefetchHooks Function({bool todosRefs})
    >;
typedef $$TodosTableCreateCompanionBuilder =
    TodosCompanion Function({
      required String id,
      Value<String?> listId,
      required String title,
      Value<String> notes,
      Value<int?> dueAtMs,
      Value<String?> recurrenceRule,
      Value<int?> completedAtMs,
      Value<int> priority,
      Value<String> tagsJson,
      Value<bool> deleted,
      Value<int> rowid,
    });
typedef $$TodosTableUpdateCompanionBuilder =
    TodosCompanion Function({
      Value<String> id,
      Value<String?> listId,
      Value<String> title,
      Value<String> notes,
      Value<int?> dueAtMs,
      Value<String?> recurrenceRule,
      Value<int?> completedAtMs,
      Value<int> priority,
      Value<String> tagsJson,
      Value<bool> deleted,
      Value<int> rowid,
    });

final class $$TodosTableReferences
    extends BaseReferences<_$AppDatabase, $TodosTable, Todo> {
  $$TodosTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $TodoListsTable _listIdTable(_$AppDatabase db) =>
      db.todoLists.createAlias('todos__list_id__todo_lists__id');

  $$TodoListsTableProcessedTableManager? get listId {
    final $_column = $_itemColumn<String>('list_id');
    if ($_column == null) return null;
    final manager = $$TodoListsTableTableManager(
      $_db,
      $_db.todoLists,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_listIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$TodoAlarmsTable, List<TodoAlarm>>
  _todoAlarmsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.todoAlarms,
    aliasName: 'todos__id__todo_alarms__todo_id',
  );

  $$TodoAlarmsTableProcessedTableManager get todoAlarmsRefs {
    final manager = $$TodoAlarmsTableTableManager(
      $_db,
      $_db.todoAlarms,
    ).filter((f) => f.todoId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_todoAlarmsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$TodosTableFilterComposer extends Composer<_$AppDatabase, $TodosTable> {
  $$TodosTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get dueAtMs => $composableBuilder(
    column: $table.dueAtMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get recurrenceRule => $composableBuilder(
    column: $table.recurrenceRule,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get completedAtMs => $composableBuilder(
    column: $table.completedAtMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tagsJson => $composableBuilder(
    column: $table.tagsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnFilters(column),
  );

  $$TodoListsTableFilterComposer get listId {
    final $$TodoListsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.listId,
      referencedTable: $db.todoLists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TodoListsTableFilterComposer(
            $db: $db,
            $table: $db.todoLists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> todoAlarmsRefs(
    Expression<bool> Function($$TodoAlarmsTableFilterComposer f) f,
  ) {
    final $$TodoAlarmsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.todoAlarms,
      getReferencedColumn: (t) => t.todoId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TodoAlarmsTableFilterComposer(
            $db: $db,
            $table: $db.todoAlarms,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TodosTableOrderingComposer
    extends Composer<_$AppDatabase, $TodosTable> {
  $$TodosTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dueAtMs => $composableBuilder(
    column: $table.dueAtMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recurrenceRule => $composableBuilder(
    column: $table.recurrenceRule,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get completedAtMs => $composableBuilder(
    column: $table.completedAtMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tagsJson => $composableBuilder(
    column: $table.tagsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnOrderings(column),
  );

  $$TodoListsTableOrderingComposer get listId {
    final $$TodoListsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.listId,
      referencedTable: $db.todoLists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TodoListsTableOrderingComposer(
            $db: $db,
            $table: $db.todoLists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TodosTableAnnotationComposer
    extends Composer<_$AppDatabase, $TodosTable> {
  $$TodosTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<int> get dueAtMs =>
      $composableBuilder(column: $table.dueAtMs, builder: (column) => column);

  GeneratedColumn<String> get recurrenceRule => $composableBuilder(
    column: $table.recurrenceRule,
    builder: (column) => column,
  );

  GeneratedColumn<int> get completedAtMs => $composableBuilder(
    column: $table.completedAtMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get priority =>
      $composableBuilder(column: $table.priority, builder: (column) => column);

  GeneratedColumn<String> get tagsJson =>
      $composableBuilder(column: $table.tagsJson, builder: (column) => column);

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);

  $$TodoListsTableAnnotationComposer get listId {
    final $$TodoListsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.listId,
      referencedTable: $db.todoLists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TodoListsTableAnnotationComposer(
            $db: $db,
            $table: $db.todoLists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> todoAlarmsRefs<T extends Object>(
    Expression<T> Function($$TodoAlarmsTableAnnotationComposer a) f,
  ) {
    final $$TodoAlarmsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.todoAlarms,
      getReferencedColumn: (t) => t.todoId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TodoAlarmsTableAnnotationComposer(
            $db: $db,
            $table: $db.todoAlarms,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TodosTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TodosTable,
          Todo,
          $$TodosTableFilterComposer,
          $$TodosTableOrderingComposer,
          $$TodosTableAnnotationComposer,
          $$TodosTableCreateCompanionBuilder,
          $$TodosTableUpdateCompanionBuilder,
          (Todo, $$TodosTableReferences),
          Todo,
          PrefetchHooks Function({bool listId, bool todoAlarmsRefs})
        > {
  $$TodosTableTableManager(_$AppDatabase db, $TodosTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TodosTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TodosTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TodosTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> listId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> notes = const Value.absent(),
                Value<int?> dueAtMs = const Value.absent(),
                Value<String?> recurrenceRule = const Value.absent(),
                Value<int?> completedAtMs = const Value.absent(),
                Value<int> priority = const Value.absent(),
                Value<String> tagsJson = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TodosCompanion(
                id: id,
                listId: listId,
                title: title,
                notes: notes,
                dueAtMs: dueAtMs,
                recurrenceRule: recurrenceRule,
                completedAtMs: completedAtMs,
                priority: priority,
                tagsJson: tagsJson,
                deleted: deleted,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> listId = const Value.absent(),
                required String title,
                Value<String> notes = const Value.absent(),
                Value<int?> dueAtMs = const Value.absent(),
                Value<String?> recurrenceRule = const Value.absent(),
                Value<int?> completedAtMs = const Value.absent(),
                Value<int> priority = const Value.absent(),
                Value<String> tagsJson = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TodosCompanion.insert(
                id: id,
                listId: listId,
                title: title,
                notes: notes,
                dueAtMs: dueAtMs,
                recurrenceRule: recurrenceRule,
                completedAtMs: completedAtMs,
                priority: priority,
                tagsJson: tagsJson,
                deleted: deleted,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$TodosTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback: ({listId = false, todoAlarmsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (todoAlarmsRefs) db.todoAlarms],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (listId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.listId,
                                referencedTable: $$TodosTableReferences
                                    ._listIdTable(db),
                                referencedColumn: $$TodosTableReferences
                                    ._listIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (todoAlarmsRefs)
                    await $_getPrefetchedData<Todo, $TodosTable, TodoAlarm>(
                      currentTable: table,
                      referencedTable: $$TodosTableReferences
                          ._todoAlarmsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$TodosTableReferences(db, table, p0).todoAlarmsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.todoId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$TodosTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TodosTable,
      Todo,
      $$TodosTableFilterComposer,
      $$TodosTableOrderingComposer,
      $$TodosTableAnnotationComposer,
      $$TodosTableCreateCompanionBuilder,
      $$TodosTableUpdateCompanionBuilder,
      (Todo, $$TodosTableReferences),
      Todo,
      PrefetchHooks Function({bool listId, bool todoAlarmsRefs})
    >;
typedef $$TodoAlarmsTableCreateCompanionBuilder =
    TodoAlarmsCompanion Function({
      required String id,
      required String todoId,
      required String atLocal,
      required String tz,
      Value<bool> deleted,
      Value<int> rowid,
    });
typedef $$TodoAlarmsTableUpdateCompanionBuilder =
    TodoAlarmsCompanion Function({
      Value<String> id,
      Value<String> todoId,
      Value<String> atLocal,
      Value<String> tz,
      Value<bool> deleted,
      Value<int> rowid,
    });

final class $$TodoAlarmsTableReferences
    extends BaseReferences<_$AppDatabase, $TodoAlarmsTable, TodoAlarm> {
  $$TodoAlarmsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $TodosTable _todoIdTable(_$AppDatabase db) =>
      db.todos.createAlias('todo_alarms__todo_id__todos__id');

  $$TodosTableProcessedTableManager get todoId {
    final $_column = $_itemColumn<String>('todo_id')!;

    final manager = $$TodosTableTableManager(
      $_db,
      $_db.todos,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_todoIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$AlarmDismissalsTable, List<AlarmDismissal>>
  _alarmDismissalsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.alarmDismissals,
    aliasName: 'todo_alarms__id__alarm_dismissals__alarm_id',
  );

  $$AlarmDismissalsTableProcessedTableManager get alarmDismissalsRefs {
    final manager = $$AlarmDismissalsTableTableManager(
      $_db,
      $_db.alarmDismissals,
    ).filter((f) => f.alarmId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _alarmDismissalsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$TodoAlarmsTableFilterComposer
    extends Composer<_$AppDatabase, $TodoAlarmsTable> {
  $$TodoAlarmsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get atLocal => $composableBuilder(
    column: $table.atLocal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tz => $composableBuilder(
    column: $table.tz,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnFilters(column),
  );

  $$TodosTableFilterComposer get todoId {
    final $$TodosTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.todoId,
      referencedTable: $db.todos,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TodosTableFilterComposer(
            $db: $db,
            $table: $db.todos,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> alarmDismissalsRefs(
    Expression<bool> Function($$AlarmDismissalsTableFilterComposer f) f,
  ) {
    final $$AlarmDismissalsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.alarmDismissals,
      getReferencedColumn: (t) => t.alarmId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AlarmDismissalsTableFilterComposer(
            $db: $db,
            $table: $db.alarmDismissals,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TodoAlarmsTableOrderingComposer
    extends Composer<_$AppDatabase, $TodoAlarmsTable> {
  $$TodoAlarmsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get atLocal => $composableBuilder(
    column: $table.atLocal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tz => $composableBuilder(
    column: $table.tz,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnOrderings(column),
  );

  $$TodosTableOrderingComposer get todoId {
    final $$TodosTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.todoId,
      referencedTable: $db.todos,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TodosTableOrderingComposer(
            $db: $db,
            $table: $db.todos,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TodoAlarmsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TodoAlarmsTable> {
  $$TodoAlarmsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get atLocal =>
      $composableBuilder(column: $table.atLocal, builder: (column) => column);

  GeneratedColumn<String> get tz =>
      $composableBuilder(column: $table.tz, builder: (column) => column);

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);

  $$TodosTableAnnotationComposer get todoId {
    final $$TodosTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.todoId,
      referencedTable: $db.todos,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TodosTableAnnotationComposer(
            $db: $db,
            $table: $db.todos,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> alarmDismissalsRefs<T extends Object>(
    Expression<T> Function($$AlarmDismissalsTableAnnotationComposer a) f,
  ) {
    final $$AlarmDismissalsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.alarmDismissals,
      getReferencedColumn: (t) => t.alarmId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AlarmDismissalsTableAnnotationComposer(
            $db: $db,
            $table: $db.alarmDismissals,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TodoAlarmsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TodoAlarmsTable,
          TodoAlarm,
          $$TodoAlarmsTableFilterComposer,
          $$TodoAlarmsTableOrderingComposer,
          $$TodoAlarmsTableAnnotationComposer,
          $$TodoAlarmsTableCreateCompanionBuilder,
          $$TodoAlarmsTableUpdateCompanionBuilder,
          (TodoAlarm, $$TodoAlarmsTableReferences),
          TodoAlarm,
          PrefetchHooks Function({bool todoId, bool alarmDismissalsRefs})
        > {
  $$TodoAlarmsTableTableManager(_$AppDatabase db, $TodoAlarmsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TodoAlarmsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TodoAlarmsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TodoAlarmsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> todoId = const Value.absent(),
                Value<String> atLocal = const Value.absent(),
                Value<String> tz = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TodoAlarmsCompanion(
                id: id,
                todoId: todoId,
                atLocal: atLocal,
                tz: tz,
                deleted: deleted,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String todoId,
                required String atLocal,
                required String tz,
                Value<bool> deleted = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TodoAlarmsCompanion.insert(
                id: id,
                todoId: todoId,
                atLocal: atLocal,
                tz: tz,
                deleted: deleted,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$TodoAlarmsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({todoId = false, alarmDismissalsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (alarmDismissalsRefs) db.alarmDismissals,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (todoId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.todoId,
                                    referencedTable: $$TodoAlarmsTableReferences
                                        ._todoIdTable(db),
                                    referencedColumn:
                                        $$TodoAlarmsTableReferences
                                            ._todoIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (alarmDismissalsRefs)
                        await $_getPrefetchedData<
                          TodoAlarm,
                          $TodoAlarmsTable,
                          AlarmDismissal
                        >(
                          currentTable: table,
                          referencedTable: $$TodoAlarmsTableReferences
                              ._alarmDismissalsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$TodoAlarmsTableReferences(
                                db,
                                table,
                                p0,
                              ).alarmDismissalsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.alarmId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$TodoAlarmsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TodoAlarmsTable,
      TodoAlarm,
      $$TodoAlarmsTableFilterComposer,
      $$TodoAlarmsTableOrderingComposer,
      $$TodoAlarmsTableAnnotationComposer,
      $$TodoAlarmsTableCreateCompanionBuilder,
      $$TodoAlarmsTableUpdateCompanionBuilder,
      (TodoAlarm, $$TodoAlarmsTableReferences),
      TodoAlarm,
      PrefetchHooks Function({bool todoId, bool alarmDismissalsRefs})
    >;
typedef $$DevicesTableCreateCompanionBuilder =
    DevicesCompanion Function({
      required String id,
      required String name,
      required String platform,
      required String publicKey,
      Value<int?> lastSeenAtMs,
      Value<int> rowid,
    });
typedef $$DevicesTableUpdateCompanionBuilder =
    DevicesCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> platform,
      Value<String> publicKey,
      Value<int?> lastSeenAtMs,
      Value<int> rowid,
    });

class $$DevicesTableFilterComposer
    extends Composer<_$AppDatabase, $DevicesTable> {
  $$DevicesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get platform => $composableBuilder(
    column: $table.platform,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get publicKey => $composableBuilder(
    column: $table.publicKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastSeenAtMs => $composableBuilder(
    column: $table.lastSeenAtMs,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DevicesTableOrderingComposer
    extends Composer<_$AppDatabase, $DevicesTable> {
  $$DevicesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get platform => $composableBuilder(
    column: $table.platform,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get publicKey => $composableBuilder(
    column: $table.publicKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastSeenAtMs => $composableBuilder(
    column: $table.lastSeenAtMs,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DevicesTableAnnotationComposer
    extends Composer<_$AppDatabase, $DevicesTable> {
  $$DevicesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get platform =>
      $composableBuilder(column: $table.platform, builder: (column) => column);

  GeneratedColumn<String> get publicKey =>
      $composableBuilder(column: $table.publicKey, builder: (column) => column);

  GeneratedColumn<int> get lastSeenAtMs => $composableBuilder(
    column: $table.lastSeenAtMs,
    builder: (column) => column,
  );
}

class $$DevicesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DevicesTable,
          Device,
          $$DevicesTableFilterComposer,
          $$DevicesTableOrderingComposer,
          $$DevicesTableAnnotationComposer,
          $$DevicesTableCreateCompanionBuilder,
          $$DevicesTableUpdateCompanionBuilder,
          (Device, BaseReferences<_$AppDatabase, $DevicesTable, Device>),
          Device,
          PrefetchHooks Function()
        > {
  $$DevicesTableTableManager(_$AppDatabase db, $DevicesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DevicesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DevicesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DevicesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> platform = const Value.absent(),
                Value<String> publicKey = const Value.absent(),
                Value<int?> lastSeenAtMs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DevicesCompanion(
                id: id,
                name: name,
                platform: platform,
                publicKey: publicKey,
                lastSeenAtMs: lastSeenAtMs,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String platform,
                required String publicKey,
                Value<int?> lastSeenAtMs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DevicesCompanion.insert(
                id: id,
                name: name,
                platform: platform,
                publicKey: publicKey,
                lastSeenAtMs: lastSeenAtMs,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DevicesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DevicesTable,
      Device,
      $$DevicesTableFilterComposer,
      $$DevicesTableOrderingComposer,
      $$DevicesTableAnnotationComposer,
      $$DevicesTableCreateCompanionBuilder,
      $$DevicesTableUpdateCompanionBuilder,
      (Device, BaseReferences<_$AppDatabase, $DevicesTable, Device>),
      Device,
      PrefetchHooks Function()
    >;
typedef $$SyncLogTableCreateCompanionBuilder =
    SyncLogCompanion Function({
      required String peerId,
      Value<String> lastAppliedHlc,
      Value<int> rowid,
    });
typedef $$SyncLogTableUpdateCompanionBuilder =
    SyncLogCompanion Function({
      Value<String> peerId,
      Value<String> lastAppliedHlc,
      Value<int> rowid,
    });

class $$SyncLogTableFilterComposer
    extends Composer<_$AppDatabase, $SyncLogTable> {
  $$SyncLogTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get peerId => $composableBuilder(
    column: $table.peerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastAppliedHlc => $composableBuilder(
    column: $table.lastAppliedHlc,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncLogTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncLogTable> {
  $$SyncLogTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get peerId => $composableBuilder(
    column: $table.peerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastAppliedHlc => $composableBuilder(
    column: $table.lastAppliedHlc,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncLogTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncLogTable> {
  $$SyncLogTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get peerId =>
      $composableBuilder(column: $table.peerId, builder: (column) => column);

  GeneratedColumn<String> get lastAppliedHlc => $composableBuilder(
    column: $table.lastAppliedHlc,
    builder: (column) => column,
  );
}

class $$SyncLogTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncLogTable,
          SyncLogData,
          $$SyncLogTableFilterComposer,
          $$SyncLogTableOrderingComposer,
          $$SyncLogTableAnnotationComposer,
          $$SyncLogTableCreateCompanionBuilder,
          $$SyncLogTableUpdateCompanionBuilder,
          (
            SyncLogData,
            BaseReferences<_$AppDatabase, $SyncLogTable, SyncLogData>,
          ),
          SyncLogData,
          PrefetchHooks Function()
        > {
  $$SyncLogTableTableManager(_$AppDatabase db, $SyncLogTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncLogTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncLogTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncLogTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> peerId = const Value.absent(),
                Value<String> lastAppliedHlc = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncLogCompanion(
                peerId: peerId,
                lastAppliedHlc: lastAppliedHlc,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String peerId,
                Value<String> lastAppliedHlc = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncLogCompanion.insert(
                peerId: peerId,
                lastAppliedHlc: lastAppliedHlc,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncLogTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncLogTable,
      SyncLogData,
      $$SyncLogTableFilterComposer,
      $$SyncLogTableOrderingComposer,
      $$SyncLogTableAnnotationComposer,
      $$SyncLogTableCreateCompanionBuilder,
      $$SyncLogTableUpdateCompanionBuilder,
      (SyncLogData, BaseReferences<_$AppDatabase, $SyncLogTable, SyncLogData>),
      SyncLogData,
      PrefetchHooks Function()
    >;
typedef $$AlarmDismissalsTableCreateCompanionBuilder =
    AlarmDismissalsCompanion Function({
      required String alarmId,
      required int occurrenceMs,
      required String dismissedBy,
      required String hlc,
      required String action,
      Value<int?> snoozeUntilMs,
      Value<int> rowid,
    });
typedef $$AlarmDismissalsTableUpdateCompanionBuilder =
    AlarmDismissalsCompanion Function({
      Value<String> alarmId,
      Value<int> occurrenceMs,
      Value<String> dismissedBy,
      Value<String> hlc,
      Value<String> action,
      Value<int?> snoozeUntilMs,
      Value<int> rowid,
    });

final class $$AlarmDismissalsTableReferences
    extends
        BaseReferences<_$AppDatabase, $AlarmDismissalsTable, AlarmDismissal> {
  $$AlarmDismissalsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $TodoAlarmsTable _alarmIdTable(_$AppDatabase db) =>
      db.todoAlarms.createAlias('alarm_dismissals__alarm_id__todo_alarms__id');

  $$TodoAlarmsTableProcessedTableManager get alarmId {
    final $_column = $_itemColumn<String>('alarm_id')!;

    final manager = $$TodoAlarmsTableTableManager(
      $_db,
      $_db.todoAlarms,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_alarmIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$AlarmDismissalsTableFilterComposer
    extends Composer<_$AppDatabase, $AlarmDismissalsTable> {
  $$AlarmDismissalsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get occurrenceMs => $composableBuilder(
    column: $table.occurrenceMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dismissedBy => $composableBuilder(
    column: $table.dismissedBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get hlc => $composableBuilder(
    column: $table.hlc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get action => $composableBuilder(
    column: $table.action,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get snoozeUntilMs => $composableBuilder(
    column: $table.snoozeUntilMs,
    builder: (column) => ColumnFilters(column),
  );

  $$TodoAlarmsTableFilterComposer get alarmId {
    final $$TodoAlarmsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.alarmId,
      referencedTable: $db.todoAlarms,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TodoAlarmsTableFilterComposer(
            $db: $db,
            $table: $db.todoAlarms,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AlarmDismissalsTableOrderingComposer
    extends Composer<_$AppDatabase, $AlarmDismissalsTable> {
  $$AlarmDismissalsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get occurrenceMs => $composableBuilder(
    column: $table.occurrenceMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dismissedBy => $composableBuilder(
    column: $table.dismissedBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get hlc => $composableBuilder(
    column: $table.hlc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get action => $composableBuilder(
    column: $table.action,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get snoozeUntilMs => $composableBuilder(
    column: $table.snoozeUntilMs,
    builder: (column) => ColumnOrderings(column),
  );

  $$TodoAlarmsTableOrderingComposer get alarmId {
    final $$TodoAlarmsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.alarmId,
      referencedTable: $db.todoAlarms,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TodoAlarmsTableOrderingComposer(
            $db: $db,
            $table: $db.todoAlarms,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AlarmDismissalsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AlarmDismissalsTable> {
  $$AlarmDismissalsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get occurrenceMs => $composableBuilder(
    column: $table.occurrenceMs,
    builder: (column) => column,
  );

  GeneratedColumn<String> get dismissedBy => $composableBuilder(
    column: $table.dismissedBy,
    builder: (column) => column,
  );

  GeneratedColumn<String> get hlc =>
      $composableBuilder(column: $table.hlc, builder: (column) => column);

  GeneratedColumn<String> get action =>
      $composableBuilder(column: $table.action, builder: (column) => column);

  GeneratedColumn<int> get snoozeUntilMs => $composableBuilder(
    column: $table.snoozeUntilMs,
    builder: (column) => column,
  );

  $$TodoAlarmsTableAnnotationComposer get alarmId {
    final $$TodoAlarmsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.alarmId,
      referencedTable: $db.todoAlarms,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TodoAlarmsTableAnnotationComposer(
            $db: $db,
            $table: $db.todoAlarms,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AlarmDismissalsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AlarmDismissalsTable,
          AlarmDismissal,
          $$AlarmDismissalsTableFilterComposer,
          $$AlarmDismissalsTableOrderingComposer,
          $$AlarmDismissalsTableAnnotationComposer,
          $$AlarmDismissalsTableCreateCompanionBuilder,
          $$AlarmDismissalsTableUpdateCompanionBuilder,
          (AlarmDismissal, $$AlarmDismissalsTableReferences),
          AlarmDismissal,
          PrefetchHooks Function({bool alarmId})
        > {
  $$AlarmDismissalsTableTableManager(
    _$AppDatabase db,
    $AlarmDismissalsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AlarmDismissalsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AlarmDismissalsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AlarmDismissalsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> alarmId = const Value.absent(),
                Value<int> occurrenceMs = const Value.absent(),
                Value<String> dismissedBy = const Value.absent(),
                Value<String> hlc = const Value.absent(),
                Value<String> action = const Value.absent(),
                Value<int?> snoozeUntilMs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AlarmDismissalsCompanion(
                alarmId: alarmId,
                occurrenceMs: occurrenceMs,
                dismissedBy: dismissedBy,
                hlc: hlc,
                action: action,
                snoozeUntilMs: snoozeUntilMs,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String alarmId,
                required int occurrenceMs,
                required String dismissedBy,
                required String hlc,
                required String action,
                Value<int?> snoozeUntilMs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AlarmDismissalsCompanion.insert(
                alarmId: alarmId,
                occurrenceMs: occurrenceMs,
                dismissedBy: dismissedBy,
                hlc: hlc,
                action: action,
                snoozeUntilMs: snoozeUntilMs,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$AlarmDismissalsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({alarmId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (alarmId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.alarmId,
                                referencedTable:
                                    $$AlarmDismissalsTableReferences
                                        ._alarmIdTable(db),
                                referencedColumn:
                                    $$AlarmDismissalsTableReferences
                                        ._alarmIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$AlarmDismissalsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AlarmDismissalsTable,
      AlarmDismissal,
      $$AlarmDismissalsTableFilterComposer,
      $$AlarmDismissalsTableOrderingComposer,
      $$AlarmDismissalsTableAnnotationComposer,
      $$AlarmDismissalsTableCreateCompanionBuilder,
      $$AlarmDismissalsTableUpdateCompanionBuilder,
      (AlarmDismissal, $$AlarmDismissalsTableReferences),
      AlarmDismissal,
      PrefetchHooks Function({bool alarmId})
    >;
typedef $$FieldClocksTableCreateCompanionBuilder =
    FieldClocksCompanion Function({
      required String entity,
      required String rowId,
      required String fieldName,
      required String hlc,
      Value<int> rowid,
    });
typedef $$FieldClocksTableUpdateCompanionBuilder =
    FieldClocksCompanion Function({
      Value<String> entity,
      Value<String> rowId,
      Value<String> fieldName,
      Value<String> hlc,
      Value<int> rowid,
    });

class $$FieldClocksTableFilterComposer
    extends Composer<_$AppDatabase, $FieldClocksTable> {
  $$FieldClocksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get entity => $composableBuilder(
    column: $table.entity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rowId => $composableBuilder(
    column: $table.rowId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fieldName => $composableBuilder(
    column: $table.fieldName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get hlc => $composableBuilder(
    column: $table.hlc,
    builder: (column) => ColumnFilters(column),
  );
}

class $$FieldClocksTableOrderingComposer
    extends Composer<_$AppDatabase, $FieldClocksTable> {
  $$FieldClocksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get entity => $composableBuilder(
    column: $table.entity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rowId => $composableBuilder(
    column: $table.rowId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fieldName => $composableBuilder(
    column: $table.fieldName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get hlc => $composableBuilder(
    column: $table.hlc,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$FieldClocksTableAnnotationComposer
    extends Composer<_$AppDatabase, $FieldClocksTable> {
  $$FieldClocksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get entity =>
      $composableBuilder(column: $table.entity, builder: (column) => column);

  GeneratedColumn<String> get rowId =>
      $composableBuilder(column: $table.rowId, builder: (column) => column);

  GeneratedColumn<String> get fieldName =>
      $composableBuilder(column: $table.fieldName, builder: (column) => column);

  GeneratedColumn<String> get hlc =>
      $composableBuilder(column: $table.hlc, builder: (column) => column);
}

class $$FieldClocksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FieldClocksTable,
          FieldClock,
          $$FieldClocksTableFilterComposer,
          $$FieldClocksTableOrderingComposer,
          $$FieldClocksTableAnnotationComposer,
          $$FieldClocksTableCreateCompanionBuilder,
          $$FieldClocksTableUpdateCompanionBuilder,
          (
            FieldClock,
            BaseReferences<_$AppDatabase, $FieldClocksTable, FieldClock>,
          ),
          FieldClock,
          PrefetchHooks Function()
        > {
  $$FieldClocksTableTableManager(_$AppDatabase db, $FieldClocksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FieldClocksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FieldClocksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FieldClocksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> entity = const Value.absent(),
                Value<String> rowId = const Value.absent(),
                Value<String> fieldName = const Value.absent(),
                Value<String> hlc = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FieldClocksCompanion(
                entity: entity,
                rowId: rowId,
                fieldName: fieldName,
                hlc: hlc,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String entity,
                required String rowId,
                required String fieldName,
                required String hlc,
                Value<int> rowid = const Value.absent(),
              }) => FieldClocksCompanion.insert(
                entity: entity,
                rowId: rowId,
                fieldName: fieldName,
                hlc: hlc,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$FieldClocksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FieldClocksTable,
      FieldClock,
      $$FieldClocksTableFilterComposer,
      $$FieldClocksTableOrderingComposer,
      $$FieldClocksTableAnnotationComposer,
      $$FieldClocksTableCreateCompanionBuilder,
      $$FieldClocksTableUpdateCompanionBuilder,
      (
        FieldClock,
        BaseReferences<_$AppDatabase, $FieldClocksTable, FieldClock>,
      ),
      FieldClock,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$TodoListsTableTableManager get todoLists =>
      $$TodoListsTableTableManager(_db, _db.todoLists);
  $$TodosTableTableManager get todos =>
      $$TodosTableTableManager(_db, _db.todos);
  $$TodoAlarmsTableTableManager get todoAlarms =>
      $$TodoAlarmsTableTableManager(_db, _db.todoAlarms);
  $$DevicesTableTableManager get devices =>
      $$DevicesTableTableManager(_db, _db.devices);
  $$SyncLogTableTableManager get syncLog =>
      $$SyncLogTableTableManager(_db, _db.syncLog);
  $$AlarmDismissalsTableTableManager get alarmDismissals =>
      $$AlarmDismissalsTableTableManager(_db, _db.alarmDismissals);
  $$FieldClocksTableTableManager get fieldClocks =>
      $$FieldClocksTableTableManager(_db, _db.fieldClocks);
}
