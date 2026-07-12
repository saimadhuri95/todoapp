// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $SyncGroupsTable extends SyncGroups
    with TableInfo<$SyncGroupsTable, SyncGroup> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncGroupsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _backendKindMeta = const VerificationMeta(
    'backendKind',
  );
  @override
  late final GeneratedColumn<String> backendKind = GeneratedColumn<String>(
    'backend_kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _localAccountRefMeta = const VerificationMeta(
    'localAccountRef',
  );
  @override
  late final GeneratedColumn<String> localAccountRef = GeneratedColumn<String>(
    'local_account_ref',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
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
    name,
    backendKind,
    localAccountRef,
    deleted,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_groups';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncGroup> instance, {
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
    if (data.containsKey('backend_kind')) {
      context.handle(
        _backendKindMeta,
        backendKind.isAcceptableOrUnknown(
          data['backend_kind']!,
          _backendKindMeta,
        ),
      );
    }
    if (data.containsKey('local_account_ref')) {
      context.handle(
        _localAccountRefMeta,
        localAccountRef.isAcceptableOrUnknown(
          data['local_account_ref']!,
          _localAccountRefMeta,
        ),
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
  SyncGroup map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncGroup(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      backendKind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}backend_kind'],
      )!,
      localAccountRef: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_account_ref'],
      ),
      deleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}deleted'],
      )!,
    );
  }

  @override
  $SyncGroupsTable createAlias(String alias) {
    return $SyncGroupsTable(attachedDatabase, alias);
  }
}

class SyncGroup extends DataClass implements Insertable<SyncGroup> {
  final String id;
  final String name;

  /// Where the group's mailbox lives — a CloudProviderId name ('icloud',
  /// 'webdav', 'dropbox', …) or 'folder' for a plain synced directory.
  /// Group-global: every member uses the same backend kind.
  final String backendKind;

  /// Device-local pointer to *this device's* way into the backend (its
  /// own account id / folder path). Deliberately **not** a synced field:
  /// each member brings their own account (ADR 0004).
  final String? localAccountRef;
  final bool deleted;
  const SyncGroup({
    required this.id,
    required this.name,
    required this.backendKind,
    this.localAccountRef,
    required this.deleted,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['backend_kind'] = Variable<String>(backendKind);
    if (!nullToAbsent || localAccountRef != null) {
      map['local_account_ref'] = Variable<String>(localAccountRef);
    }
    map['deleted'] = Variable<bool>(deleted);
    return map;
  }

  SyncGroupsCompanion toCompanion(bool nullToAbsent) {
    return SyncGroupsCompanion(
      id: Value(id),
      name: Value(name),
      backendKind: Value(backendKind),
      localAccountRef: localAccountRef == null && nullToAbsent
          ? const Value.absent()
          : Value(localAccountRef),
      deleted: Value(deleted),
    );
  }

  factory SyncGroup.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncGroup(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      backendKind: serializer.fromJson<String>(json['backendKind']),
      localAccountRef: serializer.fromJson<String?>(json['localAccountRef']),
      deleted: serializer.fromJson<bool>(json['deleted']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'backendKind': serializer.toJson<String>(backendKind),
      'localAccountRef': serializer.toJson<String?>(localAccountRef),
      'deleted': serializer.toJson<bool>(deleted),
    };
  }

  SyncGroup copyWith({
    String? id,
    String? name,
    String? backendKind,
    Value<String?> localAccountRef = const Value.absent(),
    bool? deleted,
  }) => SyncGroup(
    id: id ?? this.id,
    name: name ?? this.name,
    backendKind: backendKind ?? this.backendKind,
    localAccountRef: localAccountRef.present
        ? localAccountRef.value
        : this.localAccountRef,
    deleted: deleted ?? this.deleted,
  );
  SyncGroup copyWithCompanion(SyncGroupsCompanion data) {
    return SyncGroup(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      backendKind: data.backendKind.present
          ? data.backendKind.value
          : this.backendKind,
      localAccountRef: data.localAccountRef.present
          ? data.localAccountRef.value
          : this.localAccountRef,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncGroup(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('backendKind: $backendKind, ')
          ..write('localAccountRef: $localAccountRef, ')
          ..write('deleted: $deleted')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, name, backendKind, localAccountRef, deleted);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncGroup &&
          other.id == this.id &&
          other.name == this.name &&
          other.backendKind == this.backendKind &&
          other.localAccountRef == this.localAccountRef &&
          other.deleted == this.deleted);
}

class SyncGroupsCompanion extends UpdateCompanion<SyncGroup> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> backendKind;
  final Value<String?> localAccountRef;
  final Value<bool> deleted;
  final Value<int> rowid;
  const SyncGroupsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.backendKind = const Value.absent(),
    this.localAccountRef = const Value.absent(),
    this.deleted = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncGroupsCompanion.insert({
    required String id,
    required String name,
    this.backendKind = const Value.absent(),
    this.localAccountRef = const Value.absent(),
    this.deleted = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name);
  static Insertable<SyncGroup> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? backendKind,
    Expression<String>? localAccountRef,
    Expression<bool>? deleted,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (backendKind != null) 'backend_kind': backendKind,
      if (localAccountRef != null) 'local_account_ref': localAccountRef,
      if (deleted != null) 'deleted': deleted,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncGroupsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? backendKind,
    Value<String?>? localAccountRef,
    Value<bool>? deleted,
    Value<int>? rowid,
  }) {
    return SyncGroupsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      backendKind: backendKind ?? this.backendKind,
      localAccountRef: localAccountRef ?? this.localAccountRef,
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
    if (backendKind.present) {
      map['backend_kind'] = Variable<String>(backendKind.value);
    }
    if (localAccountRef.present) {
      map['local_account_ref'] = Variable<String>(localAccountRef.value);
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
    return (StringBuffer('SyncGroupsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('backendKind: $backendKind, ')
          ..write('localAccountRef: $localAccountRef, ')
          ..write('deleted: $deleted, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

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
  static const VerificationMeta _groupIdMeta = const VerificationMeta(
    'groupId',
  );
  @override
  late final GeneratedColumn<String> groupId = GeneratedColumn<String>(
    'group_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES sync_groups (id)',
    ),
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
    name,
    color,
    sortOrder,
    groupId,
    deleted,
  ];
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
    if (data.containsKey('group_id')) {
      context.handle(
        _groupIdMeta,
        groupId.isAcceptableOrUnknown(data['group_id']!, _groupIdMeta),
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
      groupId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}group_id'],
      ),
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

  /// Sharing group this list syncs through (schema v4, ADR 0004);
  /// **null = local-only, the default** — the list never leaves the
  /// device until the user assigns a group.
  final String? groupId;
  final bool deleted;
  const TodoList({
    required this.id,
    required this.name,
    this.color,
    required this.sortOrder,
    this.groupId,
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
    if (!nullToAbsent || groupId != null) {
      map['group_id'] = Variable<String>(groupId);
    }
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
      groupId: groupId == null && nullToAbsent
          ? const Value.absent()
          : Value(groupId),
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
      groupId: serializer.fromJson<String?>(json['groupId']),
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
      'groupId': serializer.toJson<String?>(groupId),
      'deleted': serializer.toJson<bool>(deleted),
    };
  }

  TodoList copyWith({
    String? id,
    String? name,
    Value<int?> color = const Value.absent(),
    int? sortOrder,
    Value<String?> groupId = const Value.absent(),
    bool? deleted,
  }) => TodoList(
    id: id ?? this.id,
    name: name ?? this.name,
    color: color.present ? color.value : this.color,
    sortOrder: sortOrder ?? this.sortOrder,
    groupId: groupId.present ? groupId.value : this.groupId,
    deleted: deleted ?? this.deleted,
  );
  TodoList copyWithCompanion(TodoListsCompanion data) {
    return TodoList(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      color: data.color.present ? data.color.value : this.color,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      groupId: data.groupId.present ? data.groupId.value : this.groupId,
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
          ..write('groupId: $groupId, ')
          ..write('deleted: $deleted')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, color, sortOrder, groupId, deleted);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TodoList &&
          other.id == this.id &&
          other.name == this.name &&
          other.color == this.color &&
          other.sortOrder == this.sortOrder &&
          other.groupId == this.groupId &&
          other.deleted == this.deleted);
}

class TodoListsCompanion extends UpdateCompanion<TodoList> {
  final Value<String> id;
  final Value<String> name;
  final Value<int?> color;
  final Value<int> sortOrder;
  final Value<String?> groupId;
  final Value<bool> deleted;
  final Value<int> rowid;
  const TodoListsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.color = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.groupId = const Value.absent(),
    this.deleted = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TodoListsCompanion.insert({
    required String id,
    required String name,
    this.color = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.groupId = const Value.absent(),
    this.deleted = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name);
  static Insertable<TodoList> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<int>? color,
    Expression<int>? sortOrder,
    Expression<String>? groupId,
    Expression<bool>? deleted,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (color != null) 'color': color,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (groupId != null) 'group_id': groupId,
      if (deleted != null) 'deleted': deleted,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TodoListsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<int?>? color,
    Value<int>? sortOrder,
    Value<String?>? groupId,
    Value<bool>? deleted,
    Value<int>? rowid,
  }) {
    return TodoListsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
      sortOrder: sortOrder ?? this.sortOrder,
      groupId: groupId ?? this.groupId,
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
    if (groupId.present) {
      map['group_id'] = Variable<String>(groupId.value);
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
          ..write('groupId: $groupId, ')
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
    name,
    platform,
    publicKey,
    lastSeenAtMs,
    deleted,
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
      deleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}deleted'],
      )!,
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

  /// Tombstone (schema v2): revoked devices stay as rows so the revocation
  /// itself replicates.
  final bool deleted;
  const Device({
    required this.id,
    required this.name,
    required this.platform,
    required this.publicKey,
    this.lastSeenAtMs,
    required this.deleted,
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
    map['deleted'] = Variable<bool>(deleted);
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
      deleted: Value(deleted),
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
      deleted: serializer.fromJson<bool>(json['deleted']),
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
      'deleted': serializer.toJson<bool>(deleted),
    };
  }

  Device copyWith({
    String? id,
    String? name,
    String? platform,
    String? publicKey,
    Value<int?> lastSeenAtMs = const Value.absent(),
    bool? deleted,
  }) => Device(
    id: id ?? this.id,
    name: name ?? this.name,
    platform: platform ?? this.platform,
    publicKey: publicKey ?? this.publicKey,
    lastSeenAtMs: lastSeenAtMs.present ? lastSeenAtMs.value : this.lastSeenAtMs,
    deleted: deleted ?? this.deleted,
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
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Device(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('platform: $platform, ')
          ..write('publicKey: $publicKey, ')
          ..write('lastSeenAtMs: $lastSeenAtMs, ')
          ..write('deleted: $deleted')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, name, platform, publicKey, lastSeenAtMs, deleted);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Device &&
          other.id == this.id &&
          other.name == this.name &&
          other.platform == this.platform &&
          other.publicKey == this.publicKey &&
          other.lastSeenAtMs == this.lastSeenAtMs &&
          other.deleted == this.deleted);
}

class DevicesCompanion extends UpdateCompanion<Device> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> platform;
  final Value<String> publicKey;
  final Value<int?> lastSeenAtMs;
  final Value<bool> deleted;
  final Value<int> rowid;
  const DevicesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.platform = const Value.absent(),
    this.publicKey = const Value.absent(),
    this.lastSeenAtMs = const Value.absent(),
    this.deleted = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DevicesCompanion.insert({
    required String id,
    required String name,
    required String platform,
    required String publicKey,
    this.lastSeenAtMs = const Value.absent(),
    this.deleted = const Value.absent(),
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
    Expression<bool>? deleted,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (platform != null) 'platform': platform,
      if (publicKey != null) 'public_key': publicKey,
      if (lastSeenAtMs != null) 'last_seen_at_ms': lastSeenAtMs,
      if (deleted != null) 'deleted': deleted,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DevicesCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? platform,
    Value<String>? publicKey,
    Value<int?>? lastSeenAtMs,
    Value<bool>? deleted,
    Value<int>? rowid,
  }) {
    return DevicesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      platform: platform ?? this.platform,
      publicKey: publicKey ?? this.publicKey,
      lastSeenAtMs: lastSeenAtMs ?? this.lastSeenAtMs,
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
    if (platform.present) {
      map['platform'] = Variable<String>(platform.value);
    }
    if (publicKey.present) {
      map['public_key'] = Variable<String>(publicKey.value);
    }
    if (lastSeenAtMs.present) {
      map['last_seen_at_ms'] = Variable<int>(lastSeenAtMs.value);
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
    return (StringBuffer('DevicesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('platform: $platform, ')
          ..write('publicKey: $publicKey, ')
          ..write('lastSeenAtMs: $lastSeenAtMs, ')
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
  static const VerificationMeta _parentIdMeta = const VerificationMeta(
    'parentId',
  );
  @override
  late final GeneratedColumn<String> parentId = GeneratedColumn<String>(
    'parent_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES todos (id)',
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
  static const VerificationMeta _sectionMeta = const VerificationMeta(
    'section',
  );
  @override
  late final GeneratedColumn<String> section = GeneratedColumn<String>(
    'section',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sortKeyMeta = const VerificationMeta(
    'sortKey',
  );
  @override
  late final GeneratedColumn<String> sortKey = GeneratedColumn<String>(
    'sort_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _alarmOffsetsJsonMeta = const VerificationMeta(
    'alarmOffsetsJson',
  );
  @override
  late final GeneratedColumn<String> alarmOffsetsJson = GeneratedColumn<String>(
    'alarm_offsets_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _lastDismissedMsMeta = const VerificationMeta(
    'lastDismissedMs',
  );
  @override
  late final GeneratedColumn<int> lastDismissedMs = GeneratedColumn<int>(
    'last_dismissed_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
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
  static const VerificationMeta _pinnedMeta = const VerificationMeta('pinned');
  @override
  late final GeneratedColumn<bool> pinned = GeneratedColumn<bool>(
    'pinned',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("pinned" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _estimateMinutesMeta = const VerificationMeta(
    'estimateMinutes',
  );
  @override
  late final GeneratedColumn<int> estimateMinutes = GeneratedColumn<int>(
    'estimate_minutes',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _energyMeta = const VerificationMeta('energy');
  @override
  late final GeneratedColumn<int> energy = GeneratedColumn<int>(
    'energy',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nagIntervalMinutesMeta =
      const VerificationMeta('nagIntervalMinutes');
  @override
  late final GeneratedColumn<int> nagIntervalMinutes = GeneratedColumn<int>(
    'nag_interval_minutes',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _assigneeDeviceIdMeta = const VerificationMeta(
    'assigneeDeviceId',
  );
  @override
  late final GeneratedColumn<String> assigneeDeviceId = GeneratedColumn<String>(
    'assignee_device_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES devices (id)',
    ),
  );
  static const VerificationMeta _currentStreakMeta = const VerificationMeta(
    'currentStreak',
  );
  @override
  late final GeneratedColumn<int> currentStreak = GeneratedColumn<int>(
    'current_streak',
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
  List<GeneratedColumn> get $columns => [
    id,
    listId,
    parentId,
    title,
    notes,
    dueAtMs,
    recurrenceRule,
    completedAtMs,
    priority,
    tagsJson,
    section,
    sortKey,
    alarmOffsetsJson,
    lastDismissedMs,
    snoozeUntilMs,
    pinned,
    estimateMinutes,
    energy,
    nagIntervalMinutes,
    assigneeDeviceId,
    currentStreak,
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
    if (data.containsKey('parent_id')) {
      context.handle(
        _parentIdMeta,
        parentId.isAcceptableOrUnknown(data['parent_id']!, _parentIdMeta),
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
    if (data.containsKey('section')) {
      context.handle(
        _sectionMeta,
        section.isAcceptableOrUnknown(data['section']!, _sectionMeta),
      );
    }
    if (data.containsKey('sort_key')) {
      context.handle(
        _sortKeyMeta,
        sortKey.isAcceptableOrUnknown(data['sort_key']!, _sortKeyMeta),
      );
    }
    if (data.containsKey('alarm_offsets_json')) {
      context.handle(
        _alarmOffsetsJsonMeta,
        alarmOffsetsJson.isAcceptableOrUnknown(
          data['alarm_offsets_json']!,
          _alarmOffsetsJsonMeta,
        ),
      );
    }
    if (data.containsKey('last_dismissed_ms')) {
      context.handle(
        _lastDismissedMsMeta,
        lastDismissedMs.isAcceptableOrUnknown(
          data['last_dismissed_ms']!,
          _lastDismissedMsMeta,
        ),
      );
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
    if (data.containsKey('pinned')) {
      context.handle(
        _pinnedMeta,
        pinned.isAcceptableOrUnknown(data['pinned']!, _pinnedMeta),
      );
    }
    if (data.containsKey('estimate_minutes')) {
      context.handle(
        _estimateMinutesMeta,
        estimateMinutes.isAcceptableOrUnknown(
          data['estimate_minutes']!,
          _estimateMinutesMeta,
        ),
      );
    }
    if (data.containsKey('energy')) {
      context.handle(
        _energyMeta,
        energy.isAcceptableOrUnknown(data['energy']!, _energyMeta),
      );
    }
    if (data.containsKey('nag_interval_minutes')) {
      context.handle(
        _nagIntervalMinutesMeta,
        nagIntervalMinutes.isAcceptableOrUnknown(
          data['nag_interval_minutes']!,
          _nagIntervalMinutesMeta,
        ),
      );
    }
    if (data.containsKey('assignee_device_id')) {
      context.handle(
        _assigneeDeviceIdMeta,
        assigneeDeviceId.isAcceptableOrUnknown(
          data['assignee_device_id']!,
          _assigneeDeviceIdMeta,
        ),
      );
    }
    if (data.containsKey('current_streak')) {
      context.handle(
        _currentStreakMeta,
        currentStreak.isAcceptableOrUnknown(
          data['current_streak']!,
          _currentStreakMeta,
        ),
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
      parentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parent_id'],
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
      section: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}section'],
      ),
      sortKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sort_key'],
      )!,
      alarmOffsetsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}alarm_offsets_json'],
      )!,
      lastDismissedMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_dismissed_ms'],
      ),
      snoozeUntilMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}snooze_until_ms'],
      ),
      pinned: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}pinned'],
      )!,
      estimateMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}estimate_minutes'],
      ),
      energy: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}energy'],
      ),
      nagIntervalMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}nag_interval_minutes'],
      ),
      assigneeDeviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}assignee_device_id'],
      ),
      currentStreak: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}current_streak'],
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

  /// Subtasks/checklist items are ordinary synced todo rows (schema v5).
  /// A null parent is a top-level task; child rows keep their own LWW clocks.
  final String? parentId;
  final String title;
  final String notes;
  final int? dueAtMs;
  final String? recurrenceRule;
  final int? completedAtMs;
  final int priority;
  final String tagsJson;

  /// User-defined section within a list, null for date-driven grouping.
  final String? section;

  /// Fractional, lexicographically sortable order key for manual ordering.
  final String sortKey;

  /// Alarms (schema v3): JSON array of minute-offsets before [dueAtMs]
  /// (0 = at due time). LWW fields on the todo so they sync like
  /// everything else — the todo_alarms table is unused (see docs/alarms.md).
  final String alarmOffsetsJson;

  /// Last dismissed occurrence (epoch ms). Dismissal *is* a synced field
  /// write: every device suppresses alarms for occurrences ≤ this.
  final int? lastDismissedMs;

  /// Snoozed-until moment (epoch ms); one extra fire at this time.
  final int? snoozeUntilMs;

  /// "Top 3" must-dos (schema v4, TASKS.md 6.34): pinned todos surface in a
  /// section above Today. A synced LWW field like the rest; the 3-item cap is
  /// a UI guardrail, not a storage constraint.
  final bool pinned;

  /// Rough time estimate in minutes (schema v7, TASKS.md 6.35): drives the
  /// "I have 10 minutes" quick-win filter. Null = unestimated.
  final int? estimateMinutes;

  /// Energy required (schema v7, TASKS.md 6.35): 0 low / 1 medium / 2 high.
  /// Null = unset. Metadata only for now; feeds future energy-aware views.
  final int? energy;

  /// Nag interval in minutes (schema v8, TASKS.md 6.44): once an occurrence
  /// is due, keep re-firing every N minutes until it is completed or
  /// dismissed. Null = no nagging. Scheduling itself stays local; the
  /// setting syncs like any other LWW field.
  final int? nagIntervalMinutes;

  /// Assignee for a shared-list task (schema v9, TASKS.md 6.51). Null =
  /// unassigned. A synced LWW field like the rest; the referenced device
  /// need not be a group member of this list's group by the time the write
  /// lands (FK springs like `listId`/`groupId`).
  final String? assigneeDeviceId;

  /// Consecutive on-time completions of a recurring todo (schema v9,
  /// TASKS.md 6.11). Incremented in [TodoRepository.complete] when the prior
  /// occurrence was completed before its *next* due moment, reset to 1
  /// otherwise. 0 for non-recurring or never-completed todos.
  final int currentStreak;
  final bool deleted;
  const Todo({
    required this.id,
    this.listId,
    this.parentId,
    required this.title,
    required this.notes,
    this.dueAtMs,
    this.recurrenceRule,
    this.completedAtMs,
    required this.priority,
    required this.tagsJson,
    this.section,
    required this.sortKey,
    required this.alarmOffsetsJson,
    this.lastDismissedMs,
    this.snoozeUntilMs,
    required this.pinned,
    this.estimateMinutes,
    this.energy,
    this.nagIntervalMinutes,
    this.assigneeDeviceId,
    required this.currentStreak,
    required this.deleted,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || listId != null) {
      map['list_id'] = Variable<String>(listId);
    }
    if (!nullToAbsent || parentId != null) {
      map['parent_id'] = Variable<String>(parentId);
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
    if (!nullToAbsent || section != null) {
      map['section'] = Variable<String>(section);
    }
    map['sort_key'] = Variable<String>(sortKey);
    map['alarm_offsets_json'] = Variable<String>(alarmOffsetsJson);
    if (!nullToAbsent || lastDismissedMs != null) {
      map['last_dismissed_ms'] = Variable<int>(lastDismissedMs);
    }
    if (!nullToAbsent || snoozeUntilMs != null) {
      map['snooze_until_ms'] = Variable<int>(snoozeUntilMs);
    }
    map['pinned'] = Variable<bool>(pinned);
    if (!nullToAbsent || estimateMinutes != null) {
      map['estimate_minutes'] = Variable<int>(estimateMinutes);
    }
    if (!nullToAbsent || energy != null) {
      map['energy'] = Variable<int>(energy);
    }
    if (!nullToAbsent || nagIntervalMinutes != null) {
      map['nag_interval_minutes'] = Variable<int>(nagIntervalMinutes);
    }
    if (!nullToAbsent || assigneeDeviceId != null) {
      map['assignee_device_id'] = Variable<String>(assigneeDeviceId);
    }
    map['current_streak'] = Variable<int>(currentStreak);
    map['deleted'] = Variable<bool>(deleted);
    return map;
  }

  TodosCompanion toCompanion(bool nullToAbsent) {
    return TodosCompanion(
      id: Value(id),
      listId: listId == null && nullToAbsent
          ? const Value.absent()
          : Value(listId),
      parentId: parentId == null && nullToAbsent
          ? const Value.absent()
          : Value(parentId),
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
      section: section == null && nullToAbsent
          ? const Value.absent()
          : Value(section),
      sortKey: Value(sortKey),
      alarmOffsetsJson: Value(alarmOffsetsJson),
      lastDismissedMs: lastDismissedMs == null && nullToAbsent
          ? const Value.absent()
          : Value(lastDismissedMs),
      snoozeUntilMs: snoozeUntilMs == null && nullToAbsent
          ? const Value.absent()
          : Value(snoozeUntilMs),
      pinned: Value(pinned),
      estimateMinutes: estimateMinutes == null && nullToAbsent
          ? const Value.absent()
          : Value(estimateMinutes),
      energy: energy == null && nullToAbsent
          ? const Value.absent()
          : Value(energy),
      nagIntervalMinutes: nagIntervalMinutes == null && nullToAbsent
          ? const Value.absent()
          : Value(nagIntervalMinutes),
      assigneeDeviceId: assigneeDeviceId == null && nullToAbsent
          ? const Value.absent()
          : Value(assigneeDeviceId),
      currentStreak: Value(currentStreak),
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
      parentId: serializer.fromJson<String?>(json['parentId']),
      title: serializer.fromJson<String>(json['title']),
      notes: serializer.fromJson<String>(json['notes']),
      dueAtMs: serializer.fromJson<int?>(json['dueAtMs']),
      recurrenceRule: serializer.fromJson<String?>(json['recurrenceRule']),
      completedAtMs: serializer.fromJson<int?>(json['completedAtMs']),
      priority: serializer.fromJson<int>(json['priority']),
      tagsJson: serializer.fromJson<String>(json['tagsJson']),
      section: serializer.fromJson<String?>(json['section']),
      sortKey: serializer.fromJson<String>(json['sortKey']),
      alarmOffsetsJson: serializer.fromJson<String>(json['alarmOffsetsJson']),
      lastDismissedMs: serializer.fromJson<int?>(json['lastDismissedMs']),
      snoozeUntilMs: serializer.fromJson<int?>(json['snoozeUntilMs']),
      pinned: serializer.fromJson<bool>(json['pinned']),
      estimateMinutes: serializer.fromJson<int?>(json['estimateMinutes']),
      energy: serializer.fromJson<int?>(json['energy']),
      nagIntervalMinutes: serializer.fromJson<int?>(json['nagIntervalMinutes']),
      assigneeDeviceId: serializer.fromJson<String?>(json['assigneeDeviceId']),
      currentStreak: serializer.fromJson<int>(json['currentStreak']),
      deleted: serializer.fromJson<bool>(json['deleted']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'listId': serializer.toJson<String?>(listId),
      'parentId': serializer.toJson<String?>(parentId),
      'title': serializer.toJson<String>(title),
      'notes': serializer.toJson<String>(notes),
      'dueAtMs': serializer.toJson<int?>(dueAtMs),
      'recurrenceRule': serializer.toJson<String?>(recurrenceRule),
      'completedAtMs': serializer.toJson<int?>(completedAtMs),
      'priority': serializer.toJson<int>(priority),
      'tagsJson': serializer.toJson<String>(tagsJson),
      'section': serializer.toJson<String?>(section),
      'sortKey': serializer.toJson<String>(sortKey),
      'alarmOffsetsJson': serializer.toJson<String>(alarmOffsetsJson),
      'lastDismissedMs': serializer.toJson<int?>(lastDismissedMs),
      'snoozeUntilMs': serializer.toJson<int?>(snoozeUntilMs),
      'pinned': serializer.toJson<bool>(pinned),
      'estimateMinutes': serializer.toJson<int?>(estimateMinutes),
      'energy': serializer.toJson<int?>(energy),
      'nagIntervalMinutes': serializer.toJson<int?>(nagIntervalMinutes),
      'assigneeDeviceId': serializer.toJson<String?>(assigneeDeviceId),
      'currentStreak': serializer.toJson<int>(currentStreak),
      'deleted': serializer.toJson<bool>(deleted),
    };
  }

  Todo copyWith({
    String? id,
    Value<String?> listId = const Value.absent(),
    Value<String?> parentId = const Value.absent(),
    String? title,
    String? notes,
    Value<int?> dueAtMs = const Value.absent(),
    Value<String?> recurrenceRule = const Value.absent(),
    Value<int?> completedAtMs = const Value.absent(),
    int? priority,
    String? tagsJson,
    Value<String?> section = const Value.absent(),
    String? sortKey,
    String? alarmOffsetsJson,
    Value<int?> lastDismissedMs = const Value.absent(),
    Value<int?> snoozeUntilMs = const Value.absent(),
    bool? pinned,
    Value<int?> estimateMinutes = const Value.absent(),
    Value<int?> energy = const Value.absent(),
    Value<int?> nagIntervalMinutes = const Value.absent(),
    Value<String?> assigneeDeviceId = const Value.absent(),
    int? currentStreak,
    bool? deleted,
  }) => Todo(
    id: id ?? this.id,
    listId: listId.present ? listId.value : this.listId,
    parentId: parentId.present ? parentId.value : this.parentId,
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
    section: section.present ? section.value : this.section,
    sortKey: sortKey ?? this.sortKey,
    alarmOffsetsJson: alarmOffsetsJson ?? this.alarmOffsetsJson,
    lastDismissedMs: lastDismissedMs.present
        ? lastDismissedMs.value
        : this.lastDismissedMs,
    snoozeUntilMs: snoozeUntilMs.present
        ? snoozeUntilMs.value
        : this.snoozeUntilMs,
    pinned: pinned ?? this.pinned,
    estimateMinutes: estimateMinutes.present
        ? estimateMinutes.value
        : this.estimateMinutes,
    energy: energy.present ? energy.value : this.energy,
    nagIntervalMinutes: nagIntervalMinutes.present
        ? nagIntervalMinutes.value
        : this.nagIntervalMinutes,
    assigneeDeviceId: assigneeDeviceId.present
        ? assigneeDeviceId.value
        : this.assigneeDeviceId,
    currentStreak: currentStreak ?? this.currentStreak,
    deleted: deleted ?? this.deleted,
  );
  Todo copyWithCompanion(TodosCompanion data) {
    return Todo(
      id: data.id.present ? data.id.value : this.id,
      listId: data.listId.present ? data.listId.value : this.listId,
      parentId: data.parentId.present ? data.parentId.value : this.parentId,
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
      section: data.section.present ? data.section.value : this.section,
      sortKey: data.sortKey.present ? data.sortKey.value : this.sortKey,
      alarmOffsetsJson: data.alarmOffsetsJson.present
          ? data.alarmOffsetsJson.value
          : this.alarmOffsetsJson,
      lastDismissedMs: data.lastDismissedMs.present
          ? data.lastDismissedMs.value
          : this.lastDismissedMs,
      snoozeUntilMs: data.snoozeUntilMs.present
          ? data.snoozeUntilMs.value
          : this.snoozeUntilMs,
      pinned: data.pinned.present ? data.pinned.value : this.pinned,
      estimateMinutes: data.estimateMinutes.present
          ? data.estimateMinutes.value
          : this.estimateMinutes,
      energy: data.energy.present ? data.energy.value : this.energy,
      nagIntervalMinutes: data.nagIntervalMinutes.present
          ? data.nagIntervalMinutes.value
          : this.nagIntervalMinutes,
      assigneeDeviceId: data.assigneeDeviceId.present
          ? data.assigneeDeviceId.value
          : this.assigneeDeviceId,
      currentStreak: data.currentStreak.present
          ? data.currentStreak.value
          : this.currentStreak,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Todo(')
          ..write('id: $id, ')
          ..write('listId: $listId, ')
          ..write('parentId: $parentId, ')
          ..write('title: $title, ')
          ..write('notes: $notes, ')
          ..write('dueAtMs: $dueAtMs, ')
          ..write('recurrenceRule: $recurrenceRule, ')
          ..write('completedAtMs: $completedAtMs, ')
          ..write('priority: $priority, ')
          ..write('tagsJson: $tagsJson, ')
          ..write('section: $section, ')
          ..write('sortKey: $sortKey, ')
          ..write('alarmOffsetsJson: $alarmOffsetsJson, ')
          ..write('lastDismissedMs: $lastDismissedMs, ')
          ..write('snoozeUntilMs: $snoozeUntilMs, ')
          ..write('pinned: $pinned, ')
          ..write('estimateMinutes: $estimateMinutes, ')
          ..write('energy: $energy, ')
          ..write('nagIntervalMinutes: $nagIntervalMinutes, ')
          ..write('assigneeDeviceId: $assigneeDeviceId, ')
          ..write('currentStreak: $currentStreak, ')
          ..write('deleted: $deleted')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    listId,
    parentId,
    title,
    notes,
    dueAtMs,
    recurrenceRule,
    completedAtMs,
    priority,
    tagsJson,
    section,
    sortKey,
    alarmOffsetsJson,
    lastDismissedMs,
    snoozeUntilMs,
    pinned,
    estimateMinutes,
    energy,
    nagIntervalMinutes,
    assigneeDeviceId,
    currentStreak,
    deleted,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Todo &&
          other.id == this.id &&
          other.listId == this.listId &&
          other.parentId == this.parentId &&
          other.title == this.title &&
          other.notes == this.notes &&
          other.dueAtMs == this.dueAtMs &&
          other.recurrenceRule == this.recurrenceRule &&
          other.completedAtMs == this.completedAtMs &&
          other.priority == this.priority &&
          other.tagsJson == this.tagsJson &&
          other.section == this.section &&
          other.sortKey == this.sortKey &&
          other.alarmOffsetsJson == this.alarmOffsetsJson &&
          other.lastDismissedMs == this.lastDismissedMs &&
          other.snoozeUntilMs == this.snoozeUntilMs &&
          other.pinned == this.pinned &&
          other.estimateMinutes == this.estimateMinutes &&
          other.energy == this.energy &&
          other.nagIntervalMinutes == this.nagIntervalMinutes &&
          other.assigneeDeviceId == this.assigneeDeviceId &&
          other.currentStreak == this.currentStreak &&
          other.deleted == this.deleted);
}

class TodosCompanion extends UpdateCompanion<Todo> {
  final Value<String> id;
  final Value<String?> listId;
  final Value<String?> parentId;
  final Value<String> title;
  final Value<String> notes;
  final Value<int?> dueAtMs;
  final Value<String?> recurrenceRule;
  final Value<int?> completedAtMs;
  final Value<int> priority;
  final Value<String> tagsJson;
  final Value<String?> section;
  final Value<String> sortKey;
  final Value<String> alarmOffsetsJson;
  final Value<int?> lastDismissedMs;
  final Value<int?> snoozeUntilMs;
  final Value<bool> pinned;
  final Value<int?> estimateMinutes;
  final Value<int?> energy;
  final Value<int?> nagIntervalMinutes;
  final Value<String?> assigneeDeviceId;
  final Value<int> currentStreak;
  final Value<bool> deleted;
  final Value<int> rowid;
  const TodosCompanion({
    this.id = const Value.absent(),
    this.listId = const Value.absent(),
    this.parentId = const Value.absent(),
    this.title = const Value.absent(),
    this.notes = const Value.absent(),
    this.dueAtMs = const Value.absent(),
    this.recurrenceRule = const Value.absent(),
    this.completedAtMs = const Value.absent(),
    this.priority = const Value.absent(),
    this.tagsJson = const Value.absent(),
    this.section = const Value.absent(),
    this.sortKey = const Value.absent(),
    this.alarmOffsetsJson = const Value.absent(),
    this.lastDismissedMs = const Value.absent(),
    this.snoozeUntilMs = const Value.absent(),
    this.pinned = const Value.absent(),
    this.estimateMinutes = const Value.absent(),
    this.energy = const Value.absent(),
    this.nagIntervalMinutes = const Value.absent(),
    this.assigneeDeviceId = const Value.absent(),
    this.currentStreak = const Value.absent(),
    this.deleted = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TodosCompanion.insert({
    required String id,
    this.listId = const Value.absent(),
    this.parentId = const Value.absent(),
    required String title,
    this.notes = const Value.absent(),
    this.dueAtMs = const Value.absent(),
    this.recurrenceRule = const Value.absent(),
    this.completedAtMs = const Value.absent(),
    this.priority = const Value.absent(),
    this.tagsJson = const Value.absent(),
    this.section = const Value.absent(),
    this.sortKey = const Value.absent(),
    this.alarmOffsetsJson = const Value.absent(),
    this.lastDismissedMs = const Value.absent(),
    this.snoozeUntilMs = const Value.absent(),
    this.pinned = const Value.absent(),
    this.estimateMinutes = const Value.absent(),
    this.energy = const Value.absent(),
    this.nagIntervalMinutes = const Value.absent(),
    this.assigneeDeviceId = const Value.absent(),
    this.currentStreak = const Value.absent(),
    this.deleted = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       title = Value(title);
  static Insertable<Todo> custom({
    Expression<String>? id,
    Expression<String>? listId,
    Expression<String>? parentId,
    Expression<String>? title,
    Expression<String>? notes,
    Expression<int>? dueAtMs,
    Expression<String>? recurrenceRule,
    Expression<int>? completedAtMs,
    Expression<int>? priority,
    Expression<String>? tagsJson,
    Expression<String>? section,
    Expression<String>? sortKey,
    Expression<String>? alarmOffsetsJson,
    Expression<int>? lastDismissedMs,
    Expression<int>? snoozeUntilMs,
    Expression<bool>? pinned,
    Expression<int>? estimateMinutes,
    Expression<int>? energy,
    Expression<int>? nagIntervalMinutes,
    Expression<String>? assigneeDeviceId,
    Expression<int>? currentStreak,
    Expression<bool>? deleted,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (listId != null) 'list_id': listId,
      if (parentId != null) 'parent_id': parentId,
      if (title != null) 'title': title,
      if (notes != null) 'notes': notes,
      if (dueAtMs != null) 'due_at_ms': dueAtMs,
      if (recurrenceRule != null) 'recurrence_rule': recurrenceRule,
      if (completedAtMs != null) 'completed_at_ms': completedAtMs,
      if (priority != null) 'priority': priority,
      if (tagsJson != null) 'tags_json': tagsJson,
      if (section != null) 'section': section,
      if (sortKey != null) 'sort_key': sortKey,
      if (alarmOffsetsJson != null) 'alarm_offsets_json': alarmOffsetsJson,
      if (lastDismissedMs != null) 'last_dismissed_ms': lastDismissedMs,
      if (snoozeUntilMs != null) 'snooze_until_ms': snoozeUntilMs,
      if (pinned != null) 'pinned': pinned,
      if (estimateMinutes != null) 'estimate_minutes': estimateMinutes,
      if (energy != null) 'energy': energy,
      if (nagIntervalMinutes != null)
        'nag_interval_minutes': nagIntervalMinutes,
      if (assigneeDeviceId != null) 'assignee_device_id': assigneeDeviceId,
      if (currentStreak != null) 'current_streak': currentStreak,
      if (deleted != null) 'deleted': deleted,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TodosCompanion copyWith({
    Value<String>? id,
    Value<String?>? listId,
    Value<String?>? parentId,
    Value<String>? title,
    Value<String>? notes,
    Value<int?>? dueAtMs,
    Value<String?>? recurrenceRule,
    Value<int?>? completedAtMs,
    Value<int>? priority,
    Value<String>? tagsJson,
    Value<String?>? section,
    Value<String>? sortKey,
    Value<String>? alarmOffsetsJson,
    Value<int?>? lastDismissedMs,
    Value<int?>? snoozeUntilMs,
    Value<bool>? pinned,
    Value<int?>? estimateMinutes,
    Value<int?>? energy,
    Value<int?>? nagIntervalMinutes,
    Value<String?>? assigneeDeviceId,
    Value<int>? currentStreak,
    Value<bool>? deleted,
    Value<int>? rowid,
  }) {
    return TodosCompanion(
      id: id ?? this.id,
      listId: listId ?? this.listId,
      parentId: parentId ?? this.parentId,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      dueAtMs: dueAtMs ?? this.dueAtMs,
      recurrenceRule: recurrenceRule ?? this.recurrenceRule,
      completedAtMs: completedAtMs ?? this.completedAtMs,
      priority: priority ?? this.priority,
      tagsJson: tagsJson ?? this.tagsJson,
      section: section ?? this.section,
      sortKey: sortKey ?? this.sortKey,
      alarmOffsetsJson: alarmOffsetsJson ?? this.alarmOffsetsJson,
      lastDismissedMs: lastDismissedMs ?? this.lastDismissedMs,
      snoozeUntilMs: snoozeUntilMs ?? this.snoozeUntilMs,
      pinned: pinned ?? this.pinned,
      estimateMinutes: estimateMinutes ?? this.estimateMinutes,
      energy: energy ?? this.energy,
      nagIntervalMinutes: nagIntervalMinutes ?? this.nagIntervalMinutes,
      assigneeDeviceId: assigneeDeviceId ?? this.assigneeDeviceId,
      currentStreak: currentStreak ?? this.currentStreak,
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
    if (parentId.present) {
      map['parent_id'] = Variable<String>(parentId.value);
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
    if (section.present) {
      map['section'] = Variable<String>(section.value);
    }
    if (sortKey.present) {
      map['sort_key'] = Variable<String>(sortKey.value);
    }
    if (alarmOffsetsJson.present) {
      map['alarm_offsets_json'] = Variable<String>(alarmOffsetsJson.value);
    }
    if (lastDismissedMs.present) {
      map['last_dismissed_ms'] = Variable<int>(lastDismissedMs.value);
    }
    if (snoozeUntilMs.present) {
      map['snooze_until_ms'] = Variable<int>(snoozeUntilMs.value);
    }
    if (pinned.present) {
      map['pinned'] = Variable<bool>(pinned.value);
    }
    if (estimateMinutes.present) {
      map['estimate_minutes'] = Variable<int>(estimateMinutes.value);
    }
    if (energy.present) {
      map['energy'] = Variable<int>(energy.value);
    }
    if (nagIntervalMinutes.present) {
      map['nag_interval_minutes'] = Variable<int>(nagIntervalMinutes.value);
    }
    if (assigneeDeviceId.present) {
      map['assignee_device_id'] = Variable<String>(assigneeDeviceId.value);
    }
    if (currentStreak.present) {
      map['current_streak'] = Variable<int>(currentStreak.value);
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
          ..write('parentId: $parentId, ')
          ..write('title: $title, ')
          ..write('notes: $notes, ')
          ..write('dueAtMs: $dueAtMs, ')
          ..write('recurrenceRule: $recurrenceRule, ')
          ..write('completedAtMs: $completedAtMs, ')
          ..write('priority: $priority, ')
          ..write('tagsJson: $tagsJson, ')
          ..write('section: $section, ')
          ..write('sortKey: $sortKey, ')
          ..write('alarmOffsetsJson: $alarmOffsetsJson, ')
          ..write('lastDismissedMs: $lastDismissedMs, ')
          ..write('snoozeUntilMs: $snoozeUntilMs, ')
          ..write('pinned: $pinned, ')
          ..write('estimateMinutes: $estimateMinutes, ')
          ..write('energy: $energy, ')
          ..write('nagIntervalMinutes: $nagIntervalMinutes, ')
          ..write('assigneeDeviceId: $assigneeDeviceId, ')
          ..write('currentStreak: $currentStreak, ')
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
  static const VerificationMeta _lastSyncedAtMsMeta = const VerificationMeta(
    'lastSyncedAtMs',
  );
  @override
  late final GeneratedColumn<int> lastSyncedAtMs = GeneratedColumn<int>(
    'last_synced_at_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    peerId,
    lastAppliedHlc,
    lastSyncedAtMs,
  ];
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
    if (data.containsKey('last_synced_at_ms')) {
      context.handle(
        _lastSyncedAtMsMeta,
        lastSyncedAtMs.isAcceptableOrUnknown(
          data['last_synced_at_ms']!,
          _lastSyncedAtMsMeta,
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
      lastSyncedAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_synced_at_ms'],
      ),
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

  /// Wall-clock time of the last exchange (schema v2) — for the
  /// "last synced" display only, never for merge decisions.
  final int? lastSyncedAtMs;
  const SyncLogData({
    required this.peerId,
    required this.lastAppliedHlc,
    this.lastSyncedAtMs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['peer_id'] = Variable<String>(peerId);
    map['last_applied_hlc'] = Variable<String>(lastAppliedHlc);
    if (!nullToAbsent || lastSyncedAtMs != null) {
      map['last_synced_at_ms'] = Variable<int>(lastSyncedAtMs);
    }
    return map;
  }

  SyncLogCompanion toCompanion(bool nullToAbsent) {
    return SyncLogCompanion(
      peerId: Value(peerId),
      lastAppliedHlc: Value(lastAppliedHlc),
      lastSyncedAtMs: lastSyncedAtMs == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSyncedAtMs),
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
      lastSyncedAtMs: serializer.fromJson<int?>(json['lastSyncedAtMs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'peerId': serializer.toJson<String>(peerId),
      'lastAppliedHlc': serializer.toJson<String>(lastAppliedHlc),
      'lastSyncedAtMs': serializer.toJson<int?>(lastSyncedAtMs),
    };
  }

  SyncLogData copyWith({
    String? peerId,
    String? lastAppliedHlc,
    Value<int?> lastSyncedAtMs = const Value.absent(),
  }) => SyncLogData(
    peerId: peerId ?? this.peerId,
    lastAppliedHlc: lastAppliedHlc ?? this.lastAppliedHlc,
    lastSyncedAtMs: lastSyncedAtMs.present
        ? lastSyncedAtMs.value
        : this.lastSyncedAtMs,
  );
  SyncLogData copyWithCompanion(SyncLogCompanion data) {
    return SyncLogData(
      peerId: data.peerId.present ? data.peerId.value : this.peerId,
      lastAppliedHlc: data.lastAppliedHlc.present
          ? data.lastAppliedHlc.value
          : this.lastAppliedHlc,
      lastSyncedAtMs: data.lastSyncedAtMs.present
          ? data.lastSyncedAtMs.value
          : this.lastSyncedAtMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncLogData(')
          ..write('peerId: $peerId, ')
          ..write('lastAppliedHlc: $lastAppliedHlc, ')
          ..write('lastSyncedAtMs: $lastSyncedAtMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(peerId, lastAppliedHlc, lastSyncedAtMs);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncLogData &&
          other.peerId == this.peerId &&
          other.lastAppliedHlc == this.lastAppliedHlc &&
          other.lastSyncedAtMs == this.lastSyncedAtMs);
}

class SyncLogCompanion extends UpdateCompanion<SyncLogData> {
  final Value<String> peerId;
  final Value<String> lastAppliedHlc;
  final Value<int?> lastSyncedAtMs;
  final Value<int> rowid;
  const SyncLogCompanion({
    this.peerId = const Value.absent(),
    this.lastAppliedHlc = const Value.absent(),
    this.lastSyncedAtMs = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncLogCompanion.insert({
    required String peerId,
    this.lastAppliedHlc = const Value.absent(),
    this.lastSyncedAtMs = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : peerId = Value(peerId);
  static Insertable<SyncLogData> custom({
    Expression<String>? peerId,
    Expression<String>? lastAppliedHlc,
    Expression<int>? lastSyncedAtMs,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (peerId != null) 'peer_id': peerId,
      if (lastAppliedHlc != null) 'last_applied_hlc': lastAppliedHlc,
      if (lastSyncedAtMs != null) 'last_synced_at_ms': lastSyncedAtMs,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncLogCompanion copyWith({
    Value<String>? peerId,
    Value<String>? lastAppliedHlc,
    Value<int?>? lastSyncedAtMs,
    Value<int>? rowid,
  }) {
    return SyncLogCompanion(
      peerId: peerId ?? this.peerId,
      lastAppliedHlc: lastAppliedHlc ?? this.lastAppliedHlc,
      lastSyncedAtMs: lastSyncedAtMs ?? this.lastSyncedAtMs,
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
    if (lastSyncedAtMs.present) {
      map['last_synced_at_ms'] = Variable<int>(lastSyncedAtMs.value);
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
          ..write('lastSyncedAtMs: $lastSyncedAtMs, ')
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

class $GroupMembersTable extends GroupMembers
    with TableInfo<$GroupMembersTable, GroupMember> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GroupMembersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _groupIdMeta = const VerificationMeta(
    'groupId',
  );
  @override
  late final GeneratedColumn<String> groupId = GeneratedColumn<String>(
    'group_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES sync_groups (id)',
    ),
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES devices (id)',
    ),
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
  List<GeneratedColumn> get $columns => [id, groupId, deviceId, deleted];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'group_members';
  @override
  VerificationContext validateIntegrity(
    Insertable<GroupMember> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('group_id')) {
      context.handle(
        _groupIdMeta,
        groupId.isAcceptableOrUnknown(data['group_id']!, _groupIdMeta),
      );
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
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
  GroupMember map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GroupMember(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      groupId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}group_id'],
      ),
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      ),
      deleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}deleted'],
      )!,
    );
  }

  @override
  $GroupMembersTable createAlias(String alias) {
    return $GroupMembersTable(attachedDatabase, alias);
  }
}

class GroupMember extends DataClass implements Insertable<GroupMember> {
  final String id;
  final String? groupId;
  final String? deviceId;
  final bool deleted;
  const GroupMember({
    required this.id,
    this.groupId,
    this.deviceId,
    required this.deleted,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || groupId != null) {
      map['group_id'] = Variable<String>(groupId);
    }
    if (!nullToAbsent || deviceId != null) {
      map['device_id'] = Variable<String>(deviceId);
    }
    map['deleted'] = Variable<bool>(deleted);
    return map;
  }

  GroupMembersCompanion toCompanion(bool nullToAbsent) {
    return GroupMembersCompanion(
      id: Value(id),
      groupId: groupId == null && nullToAbsent
          ? const Value.absent()
          : Value(groupId),
      deviceId: deviceId == null && nullToAbsent
          ? const Value.absent()
          : Value(deviceId),
      deleted: Value(deleted),
    );
  }

  factory GroupMember.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GroupMember(
      id: serializer.fromJson<String>(json['id']),
      groupId: serializer.fromJson<String?>(json['groupId']),
      deviceId: serializer.fromJson<String?>(json['deviceId']),
      deleted: serializer.fromJson<bool>(json['deleted']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'groupId': serializer.toJson<String?>(groupId),
      'deviceId': serializer.toJson<String?>(deviceId),
      'deleted': serializer.toJson<bool>(deleted),
    };
  }

  GroupMember copyWith({
    String? id,
    Value<String?> groupId = const Value.absent(),
    Value<String?> deviceId = const Value.absent(),
    bool? deleted,
  }) => GroupMember(
    id: id ?? this.id,
    groupId: groupId.present ? groupId.value : this.groupId,
    deviceId: deviceId.present ? deviceId.value : this.deviceId,
    deleted: deleted ?? this.deleted,
  );
  GroupMember copyWithCompanion(GroupMembersCompanion data) {
    return GroupMember(
      id: data.id.present ? data.id.value : this.id,
      groupId: data.groupId.present ? data.groupId.value : this.groupId,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GroupMember(')
          ..write('id: $id, ')
          ..write('groupId: $groupId, ')
          ..write('deviceId: $deviceId, ')
          ..write('deleted: $deleted')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, groupId, deviceId, deleted);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GroupMember &&
          other.id == this.id &&
          other.groupId == this.groupId &&
          other.deviceId == this.deviceId &&
          other.deleted == this.deleted);
}

class GroupMembersCompanion extends UpdateCompanion<GroupMember> {
  final Value<String> id;
  final Value<String?> groupId;
  final Value<String?> deviceId;
  final Value<bool> deleted;
  final Value<int> rowid;
  const GroupMembersCompanion({
    this.id = const Value.absent(),
    this.groupId = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.deleted = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  GroupMembersCompanion.insert({
    required String id,
    this.groupId = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.deleted = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id);
  static Insertable<GroupMember> custom({
    Expression<String>? id,
    Expression<String>? groupId,
    Expression<String>? deviceId,
    Expression<bool>? deleted,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (groupId != null) 'group_id': groupId,
      if (deviceId != null) 'device_id': deviceId,
      if (deleted != null) 'deleted': deleted,
      if (rowid != null) 'rowid': rowid,
    });
  }

  GroupMembersCompanion copyWith({
    Value<String>? id,
    Value<String?>? groupId,
    Value<String?>? deviceId,
    Value<bool>? deleted,
    Value<int>? rowid,
  }) {
    return GroupMembersCompanion(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      deviceId: deviceId ?? this.deviceId,
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
    if (groupId.present) {
      map['group_id'] = Variable<String>(groupId.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
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
    return (StringBuffer('GroupMembersCompanion(')
          ..write('id: $id, ')
          ..write('groupId: $groupId, ')
          ..write('deviceId: $deviceId, ')
          ..write('deleted: $deleted, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $SyncGroupsTable syncGroups = $SyncGroupsTable(this);
  late final $TodoListsTable todoLists = $TodoListsTable(this);
  late final $DevicesTable devices = $DevicesTable(this);
  late final $TodosTable todos = $TodosTable(this);
  late final $TodoAlarmsTable todoAlarms = $TodoAlarmsTable(this);
  late final $SyncLogTable syncLog = $SyncLogTable(this);
  late final $AlarmDismissalsTable alarmDismissals = $AlarmDismissalsTable(
    this,
  );
  late final $FieldClocksTable fieldClocks = $FieldClocksTable(this);
  late final $GroupMembersTable groupMembers = $GroupMembersTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    syncGroups,
    todoLists,
    devices,
    todos,
    todoAlarms,
    syncLog,
    alarmDismissals,
    fieldClocks,
    groupMembers,
  ];
}

typedef $$SyncGroupsTableCreateCompanionBuilder =
    SyncGroupsCompanion Function({
      required String id,
      required String name,
      Value<String> backendKind,
      Value<String?> localAccountRef,
      Value<bool> deleted,
      Value<int> rowid,
    });
typedef $$SyncGroupsTableUpdateCompanionBuilder =
    SyncGroupsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> backendKind,
      Value<String?> localAccountRef,
      Value<bool> deleted,
      Value<int> rowid,
    });

final class $$SyncGroupsTableReferences
    extends BaseReferences<_$AppDatabase, $SyncGroupsTable, SyncGroup> {
  $$SyncGroupsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$TodoListsTable, List<TodoList>>
  _todoListsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.todoLists,
    aliasName: 'sync_groups__id__todo_lists__group_id',
  );

  $$TodoListsTableProcessedTableManager get todoListsRefs {
    final manager = $$TodoListsTableTableManager(
      $_db,
      $_db.todoLists,
    ).filter((f) => f.groupId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_todoListsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$GroupMembersTable, List<GroupMember>>
  _groupMembersRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.groupMembers,
    aliasName: 'sync_groups__id__group_members__group_id',
  );

  $$GroupMembersTableProcessedTableManager get groupMembersRefs {
    final manager = $$GroupMembersTableTableManager(
      $_db,
      $_db.groupMembers,
    ).filter((f) => f.groupId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_groupMembersRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$SyncGroupsTableFilterComposer
    extends Composer<_$AppDatabase, $SyncGroupsTable> {
  $$SyncGroupsTableFilterComposer({
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

  ColumnFilters<String> get backendKind => $composableBuilder(
    column: $table.backendKind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localAccountRef => $composableBuilder(
    column: $table.localAccountRef,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> todoListsRefs(
    Expression<bool> Function($$TodoListsTableFilterComposer f) f,
  ) {
    final $$TodoListsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.todoLists,
      getReferencedColumn: (t) => t.groupId,
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
    return f(composer);
  }

  Expression<bool> groupMembersRefs(
    Expression<bool> Function($$GroupMembersTableFilterComposer f) f,
  ) {
    final $$GroupMembersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.groupMembers,
      getReferencedColumn: (t) => t.groupId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GroupMembersTableFilterComposer(
            $db: $db,
            $table: $db.groupMembers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SyncGroupsTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncGroupsTable> {
  $$SyncGroupsTableOrderingComposer({
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

  ColumnOrderings<String> get backendKind => $composableBuilder(
    column: $table.backendKind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localAccountRef => $composableBuilder(
    column: $table.localAccountRef,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncGroupsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncGroupsTable> {
  $$SyncGroupsTableAnnotationComposer({
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

  GeneratedColumn<String> get backendKind => $composableBuilder(
    column: $table.backendKind,
    builder: (column) => column,
  );

  GeneratedColumn<String> get localAccountRef => $composableBuilder(
    column: $table.localAccountRef,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);

  Expression<T> todoListsRefs<T extends Object>(
    Expression<T> Function($$TodoListsTableAnnotationComposer a) f,
  ) {
    final $$TodoListsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.todoLists,
      getReferencedColumn: (t) => t.groupId,
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
    return f(composer);
  }

  Expression<T> groupMembersRefs<T extends Object>(
    Expression<T> Function($$GroupMembersTableAnnotationComposer a) f,
  ) {
    final $$GroupMembersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.groupMembers,
      getReferencedColumn: (t) => t.groupId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GroupMembersTableAnnotationComposer(
            $db: $db,
            $table: $db.groupMembers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SyncGroupsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncGroupsTable,
          SyncGroup,
          $$SyncGroupsTableFilterComposer,
          $$SyncGroupsTableOrderingComposer,
          $$SyncGroupsTableAnnotationComposer,
          $$SyncGroupsTableCreateCompanionBuilder,
          $$SyncGroupsTableUpdateCompanionBuilder,
          (SyncGroup, $$SyncGroupsTableReferences),
          SyncGroup,
          PrefetchHooks Function({bool todoListsRefs, bool groupMembersRefs})
        > {
  $$SyncGroupsTableTableManager(_$AppDatabase db, $SyncGroupsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncGroupsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncGroupsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncGroupsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> backendKind = const Value.absent(),
                Value<String?> localAccountRef = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncGroupsCompanion(
                id: id,
                name: name,
                backendKind: backendKind,
                localAccountRef: localAccountRef,
                deleted: deleted,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<String> backendKind = const Value.absent(),
                Value<String?> localAccountRef = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncGroupsCompanion.insert(
                id: id,
                name: name,
                backendKind: backendKind,
                localAccountRef: localAccountRef,
                deleted: deleted,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$SyncGroupsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({todoListsRefs = false, groupMembersRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (todoListsRefs) db.todoLists,
                    if (groupMembersRefs) db.groupMembers,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (todoListsRefs)
                        await $_getPrefetchedData<
                          SyncGroup,
                          $SyncGroupsTable,
                          TodoList
                        >(
                          currentTable: table,
                          referencedTable: $$SyncGroupsTableReferences
                              ._todoListsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$SyncGroupsTableReferences(
                                db,
                                table,
                                p0,
                              ).todoListsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.groupId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (groupMembersRefs)
                        await $_getPrefetchedData<
                          SyncGroup,
                          $SyncGroupsTable,
                          GroupMember
                        >(
                          currentTable: table,
                          referencedTable: $$SyncGroupsTableReferences
                              ._groupMembersRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$SyncGroupsTableReferences(
                                db,
                                table,
                                p0,
                              ).groupMembersRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.groupId == item.id,
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

typedef $$SyncGroupsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncGroupsTable,
      SyncGroup,
      $$SyncGroupsTableFilterComposer,
      $$SyncGroupsTableOrderingComposer,
      $$SyncGroupsTableAnnotationComposer,
      $$SyncGroupsTableCreateCompanionBuilder,
      $$SyncGroupsTableUpdateCompanionBuilder,
      (SyncGroup, $$SyncGroupsTableReferences),
      SyncGroup,
      PrefetchHooks Function({bool todoListsRefs, bool groupMembersRefs})
    >;
typedef $$TodoListsTableCreateCompanionBuilder =
    TodoListsCompanion Function({
      required String id,
      required String name,
      Value<int?> color,
      Value<int> sortOrder,
      Value<String?> groupId,
      Value<bool> deleted,
      Value<int> rowid,
    });
typedef $$TodoListsTableUpdateCompanionBuilder =
    TodoListsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<int?> color,
      Value<int> sortOrder,
      Value<String?> groupId,
      Value<bool> deleted,
      Value<int> rowid,
    });

final class $$TodoListsTableReferences
    extends BaseReferences<_$AppDatabase, $TodoListsTable, TodoList> {
  $$TodoListsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $SyncGroupsTable _groupIdTable(_$AppDatabase db) =>
      db.syncGroups.createAlias('todo_lists__group_id__sync_groups__id');

  $$SyncGroupsTableProcessedTableManager? get groupId {
    final $_column = $_itemColumn<String>('group_id');
    if ($_column == null) return null;
    final manager = $$SyncGroupsTableTableManager(
      $_db,
      $_db.syncGroups,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_groupIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

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

  $$SyncGroupsTableFilterComposer get groupId {
    final $$SyncGroupsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.groupId,
      referencedTable: $db.syncGroups,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SyncGroupsTableFilterComposer(
            $db: $db,
            $table: $db.syncGroups,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

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

  $$SyncGroupsTableOrderingComposer get groupId {
    final $$SyncGroupsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.groupId,
      referencedTable: $db.syncGroups,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SyncGroupsTableOrderingComposer(
            $db: $db,
            $table: $db.syncGroups,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
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

  $$SyncGroupsTableAnnotationComposer get groupId {
    final $$SyncGroupsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.groupId,
      referencedTable: $db.syncGroups,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SyncGroupsTableAnnotationComposer(
            $db: $db,
            $table: $db.syncGroups,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

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
          PrefetchHooks Function({bool groupId, bool todosRefs})
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
                Value<String?> groupId = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TodoListsCompanion(
                id: id,
                name: name,
                color: color,
                sortOrder: sortOrder,
                groupId: groupId,
                deleted: deleted,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<int?> color = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<String?> groupId = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TodoListsCompanion.insert(
                id: id,
                name: name,
                color: color,
                sortOrder: sortOrder,
                groupId: groupId,
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
          prefetchHooksCallback: ({groupId = false, todosRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (todosRefs) db.todos],
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
                    if (groupId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.groupId,
                                referencedTable: $$TodoListsTableReferences
                                    ._groupIdTable(db),
                                referencedColumn: $$TodoListsTableReferences
                                    ._groupIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
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
      PrefetchHooks Function({bool groupId, bool todosRefs})
    >;
typedef $$DevicesTableCreateCompanionBuilder =
    DevicesCompanion Function({
      required String id,
      required String name,
      required String platform,
      required String publicKey,
      Value<int?> lastSeenAtMs,
      Value<bool> deleted,
      Value<int> rowid,
    });
typedef $$DevicesTableUpdateCompanionBuilder =
    DevicesCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> platform,
      Value<String> publicKey,
      Value<int?> lastSeenAtMs,
      Value<bool> deleted,
      Value<int> rowid,
    });

final class $$DevicesTableReferences
    extends BaseReferences<_$AppDatabase, $DevicesTable, Device> {
  $$DevicesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$TodosTable, List<Todo>> _todosRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.todos,
    aliasName: 'devices__id__todos__assignee_device_id',
  );

  $$TodosTableProcessedTableManager get todosRefs {
    final manager = $$TodosTableTableManager($_db, $_db.todos).filter(
      (f) => f.assigneeDeviceId.id.sqlEquals($_itemColumn<String>('id')!),
    );

    final cache = $_typedResult.readTableOrNull(_todosRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$GroupMembersTable, List<GroupMember>>
  _groupMembersRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.groupMembers,
    aliasName: 'devices__id__group_members__device_id',
  );

  $$GroupMembersTableProcessedTableManager get groupMembersRefs {
    final manager = $$GroupMembersTableTableManager(
      $_db,
      $_db.groupMembers,
    ).filter((f) => f.deviceId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_groupMembersRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

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
      getReferencedColumn: (t) => t.assigneeDeviceId,
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

  Expression<bool> groupMembersRefs(
    Expression<bool> Function($$GroupMembersTableFilterComposer f) f,
  ) {
    final $$GroupMembersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.groupMembers,
      getReferencedColumn: (t) => t.deviceId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GroupMembersTableFilterComposer(
            $db: $db,
            $table: $db.groupMembers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
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

  ColumnOrderings<bool> get deleted => $composableBuilder(
    column: $table.deleted,
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

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);

  Expression<T> todosRefs<T extends Object>(
    Expression<T> Function($$TodosTableAnnotationComposer a) f,
  ) {
    final $$TodosTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.todos,
      getReferencedColumn: (t) => t.assigneeDeviceId,
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

  Expression<T> groupMembersRefs<T extends Object>(
    Expression<T> Function($$GroupMembersTableAnnotationComposer a) f,
  ) {
    final $$GroupMembersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.groupMembers,
      getReferencedColumn: (t) => t.deviceId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GroupMembersTableAnnotationComposer(
            $db: $db,
            $table: $db.groupMembers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
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
          (Device, $$DevicesTableReferences),
          Device,
          PrefetchHooks Function({bool todosRefs, bool groupMembersRefs})
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
                Value<bool> deleted = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DevicesCompanion(
                id: id,
                name: name,
                platform: platform,
                publicKey: publicKey,
                lastSeenAtMs: lastSeenAtMs,
                deleted: deleted,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String platform,
                required String publicKey,
                Value<int?> lastSeenAtMs = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DevicesCompanion.insert(
                id: id,
                name: name,
                platform: platform,
                publicKey: publicKey,
                lastSeenAtMs: lastSeenAtMs,
                deleted: deleted,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$DevicesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({todosRefs = false, groupMembersRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (todosRefs) db.todos,
                    if (groupMembersRefs) db.groupMembers,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (todosRefs)
                        await $_getPrefetchedData<Device, $DevicesTable, Todo>(
                          currentTable: table,
                          referencedTable: $$DevicesTableReferences
                              ._todosRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$DevicesTableReferences(db, table, p0).todosRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.assigneeDeviceId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (groupMembersRefs)
                        await $_getPrefetchedData<
                          Device,
                          $DevicesTable,
                          GroupMember
                        >(
                          currentTable: table,
                          referencedTable: $$DevicesTableReferences
                              ._groupMembersRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$DevicesTableReferences(
                                db,
                                table,
                                p0,
                              ).groupMembersRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.deviceId == item.id,
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
      (Device, $$DevicesTableReferences),
      Device,
      PrefetchHooks Function({bool todosRefs, bool groupMembersRefs})
    >;
typedef $$TodosTableCreateCompanionBuilder =
    TodosCompanion Function({
      required String id,
      Value<String?> listId,
      Value<String?> parentId,
      required String title,
      Value<String> notes,
      Value<int?> dueAtMs,
      Value<String?> recurrenceRule,
      Value<int?> completedAtMs,
      Value<int> priority,
      Value<String> tagsJson,
      Value<String?> section,
      Value<String> sortKey,
      Value<String> alarmOffsetsJson,
      Value<int?> lastDismissedMs,
      Value<int?> snoozeUntilMs,
      Value<bool> pinned,
      Value<int?> estimateMinutes,
      Value<int?> energy,
      Value<int?> nagIntervalMinutes,
      Value<String?> assigneeDeviceId,
      Value<int> currentStreak,
      Value<bool> deleted,
      Value<int> rowid,
    });
typedef $$TodosTableUpdateCompanionBuilder =
    TodosCompanion Function({
      Value<String> id,
      Value<String?> listId,
      Value<String?> parentId,
      Value<String> title,
      Value<String> notes,
      Value<int?> dueAtMs,
      Value<String?> recurrenceRule,
      Value<int?> completedAtMs,
      Value<int> priority,
      Value<String> tagsJson,
      Value<String?> section,
      Value<String> sortKey,
      Value<String> alarmOffsetsJson,
      Value<int?> lastDismissedMs,
      Value<int?> snoozeUntilMs,
      Value<bool> pinned,
      Value<int?> estimateMinutes,
      Value<int?> energy,
      Value<int?> nagIntervalMinutes,
      Value<String?> assigneeDeviceId,
      Value<int> currentStreak,
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

  static $TodosTable _parentIdTable(_$AppDatabase db) =>
      db.todos.createAlias('todos__parent_id__todos__id');

  $$TodosTableProcessedTableManager? get parentId {
    final $_column = $_itemColumn<String>('parent_id');
    if ($_column == null) return null;
    final manager = $$TodosTableTableManager(
      $_db,
      $_db.todos,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_parentIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $DevicesTable _assigneeDeviceIdTable(_$AppDatabase db) =>
      db.devices.createAlias('todos__assignee_device_id__devices__id');

  $$DevicesTableProcessedTableManager? get assigneeDeviceId {
    final $_column = $_itemColumn<String>('assignee_device_id');
    if ($_column == null) return null;
    final manager = $$DevicesTableTableManager(
      $_db,
      $_db.devices,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_assigneeDeviceIdTable($_db));
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

  ColumnFilters<String> get section => $composableBuilder(
    column: $table.section,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sortKey => $composableBuilder(
    column: $table.sortKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get alarmOffsetsJson => $composableBuilder(
    column: $table.alarmOffsetsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastDismissedMs => $composableBuilder(
    column: $table.lastDismissedMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get snoozeUntilMs => $composableBuilder(
    column: $table.snoozeUntilMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get pinned => $composableBuilder(
    column: $table.pinned,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get estimateMinutes => $composableBuilder(
    column: $table.estimateMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get energy => $composableBuilder(
    column: $table.energy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get nagIntervalMinutes => $composableBuilder(
    column: $table.nagIntervalMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get currentStreak => $composableBuilder(
    column: $table.currentStreak,
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

  $$TodosTableFilterComposer get parentId {
    final $$TodosTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.parentId,
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

  $$DevicesTableFilterComposer get assigneeDeviceId {
    final $$DevicesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.assigneeDeviceId,
      referencedTable: $db.devices,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DevicesTableFilterComposer(
            $db: $db,
            $table: $db.devices,
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

  ColumnOrderings<String> get section => $composableBuilder(
    column: $table.section,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sortKey => $composableBuilder(
    column: $table.sortKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get alarmOffsetsJson => $composableBuilder(
    column: $table.alarmOffsetsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastDismissedMs => $composableBuilder(
    column: $table.lastDismissedMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get snoozeUntilMs => $composableBuilder(
    column: $table.snoozeUntilMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get pinned => $composableBuilder(
    column: $table.pinned,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get estimateMinutes => $composableBuilder(
    column: $table.estimateMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get energy => $composableBuilder(
    column: $table.energy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get nagIntervalMinutes => $composableBuilder(
    column: $table.nagIntervalMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get currentStreak => $composableBuilder(
    column: $table.currentStreak,
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

  $$TodosTableOrderingComposer get parentId {
    final $$TodosTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.parentId,
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

  $$DevicesTableOrderingComposer get assigneeDeviceId {
    final $$DevicesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.assigneeDeviceId,
      referencedTable: $db.devices,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DevicesTableOrderingComposer(
            $db: $db,
            $table: $db.devices,
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

  GeneratedColumn<String> get section =>
      $composableBuilder(column: $table.section, builder: (column) => column);

  GeneratedColumn<String> get sortKey =>
      $composableBuilder(column: $table.sortKey, builder: (column) => column);

  GeneratedColumn<String> get alarmOffsetsJson => $composableBuilder(
    column: $table.alarmOffsetsJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastDismissedMs => $composableBuilder(
    column: $table.lastDismissedMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get snoozeUntilMs => $composableBuilder(
    column: $table.snoozeUntilMs,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get pinned =>
      $composableBuilder(column: $table.pinned, builder: (column) => column);

  GeneratedColumn<int> get estimateMinutes => $composableBuilder(
    column: $table.estimateMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<int> get energy =>
      $composableBuilder(column: $table.energy, builder: (column) => column);

  GeneratedColumn<int> get nagIntervalMinutes => $composableBuilder(
    column: $table.nagIntervalMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<int> get currentStreak => $composableBuilder(
    column: $table.currentStreak,
    builder: (column) => column,
  );

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

  $$TodosTableAnnotationComposer get parentId {
    final $$TodosTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.parentId,
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

  $$DevicesTableAnnotationComposer get assigneeDeviceId {
    final $$DevicesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.assigneeDeviceId,
      referencedTable: $db.devices,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DevicesTableAnnotationComposer(
            $db: $db,
            $table: $db.devices,
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
          PrefetchHooks Function({
            bool listId,
            bool parentId,
            bool assigneeDeviceId,
            bool todoAlarmsRefs,
          })
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
                Value<String?> parentId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> notes = const Value.absent(),
                Value<int?> dueAtMs = const Value.absent(),
                Value<String?> recurrenceRule = const Value.absent(),
                Value<int?> completedAtMs = const Value.absent(),
                Value<int> priority = const Value.absent(),
                Value<String> tagsJson = const Value.absent(),
                Value<String?> section = const Value.absent(),
                Value<String> sortKey = const Value.absent(),
                Value<String> alarmOffsetsJson = const Value.absent(),
                Value<int?> lastDismissedMs = const Value.absent(),
                Value<int?> snoozeUntilMs = const Value.absent(),
                Value<bool> pinned = const Value.absent(),
                Value<int?> estimateMinutes = const Value.absent(),
                Value<int?> energy = const Value.absent(),
                Value<int?> nagIntervalMinutes = const Value.absent(),
                Value<String?> assigneeDeviceId = const Value.absent(),
                Value<int> currentStreak = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TodosCompanion(
                id: id,
                listId: listId,
                parentId: parentId,
                title: title,
                notes: notes,
                dueAtMs: dueAtMs,
                recurrenceRule: recurrenceRule,
                completedAtMs: completedAtMs,
                priority: priority,
                tagsJson: tagsJson,
                section: section,
                sortKey: sortKey,
                alarmOffsetsJson: alarmOffsetsJson,
                lastDismissedMs: lastDismissedMs,
                snoozeUntilMs: snoozeUntilMs,
                pinned: pinned,
                estimateMinutes: estimateMinutes,
                energy: energy,
                nagIntervalMinutes: nagIntervalMinutes,
                assigneeDeviceId: assigneeDeviceId,
                currentStreak: currentStreak,
                deleted: deleted,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> listId = const Value.absent(),
                Value<String?> parentId = const Value.absent(),
                required String title,
                Value<String> notes = const Value.absent(),
                Value<int?> dueAtMs = const Value.absent(),
                Value<String?> recurrenceRule = const Value.absent(),
                Value<int?> completedAtMs = const Value.absent(),
                Value<int> priority = const Value.absent(),
                Value<String> tagsJson = const Value.absent(),
                Value<String?> section = const Value.absent(),
                Value<String> sortKey = const Value.absent(),
                Value<String> alarmOffsetsJson = const Value.absent(),
                Value<int?> lastDismissedMs = const Value.absent(),
                Value<int?> snoozeUntilMs = const Value.absent(),
                Value<bool> pinned = const Value.absent(),
                Value<int?> estimateMinutes = const Value.absent(),
                Value<int?> energy = const Value.absent(),
                Value<int?> nagIntervalMinutes = const Value.absent(),
                Value<String?> assigneeDeviceId = const Value.absent(),
                Value<int> currentStreak = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TodosCompanion.insert(
                id: id,
                listId: listId,
                parentId: parentId,
                title: title,
                notes: notes,
                dueAtMs: dueAtMs,
                recurrenceRule: recurrenceRule,
                completedAtMs: completedAtMs,
                priority: priority,
                tagsJson: tagsJson,
                section: section,
                sortKey: sortKey,
                alarmOffsetsJson: alarmOffsetsJson,
                lastDismissedMs: lastDismissedMs,
                snoozeUntilMs: snoozeUntilMs,
                pinned: pinned,
                estimateMinutes: estimateMinutes,
                energy: energy,
                nagIntervalMinutes: nagIntervalMinutes,
                assigneeDeviceId: assigneeDeviceId,
                currentStreak: currentStreak,
                deleted: deleted,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$TodosTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                listId = false,
                parentId = false,
                assigneeDeviceId = false,
                todoAlarmsRefs = false,
              }) {
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
                        if (parentId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.parentId,
                                    referencedTable: $$TodosTableReferences
                                        ._parentIdTable(db),
                                    referencedColumn: $$TodosTableReferences
                                        ._parentIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }
                        if (assigneeDeviceId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.assigneeDeviceId,
                                    referencedTable: $$TodosTableReferences
                                        ._assigneeDeviceIdTable(db),
                                    referencedColumn: $$TodosTableReferences
                                        ._assigneeDeviceIdTable(db)
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
                              $$TodosTableReferences(
                                db,
                                table,
                                p0,
                              ).todoAlarmsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.todoId == item.id,
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
      PrefetchHooks Function({
        bool listId,
        bool parentId,
        bool assigneeDeviceId,
        bool todoAlarmsRefs,
      })
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
typedef $$SyncLogTableCreateCompanionBuilder =
    SyncLogCompanion Function({
      required String peerId,
      Value<String> lastAppliedHlc,
      Value<int?> lastSyncedAtMs,
      Value<int> rowid,
    });
typedef $$SyncLogTableUpdateCompanionBuilder =
    SyncLogCompanion Function({
      Value<String> peerId,
      Value<String> lastAppliedHlc,
      Value<int?> lastSyncedAtMs,
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

  ColumnFilters<int> get lastSyncedAtMs => $composableBuilder(
    column: $table.lastSyncedAtMs,
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

  ColumnOrderings<int> get lastSyncedAtMs => $composableBuilder(
    column: $table.lastSyncedAtMs,
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

  GeneratedColumn<int> get lastSyncedAtMs => $composableBuilder(
    column: $table.lastSyncedAtMs,
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
                Value<int?> lastSyncedAtMs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncLogCompanion(
                peerId: peerId,
                lastAppliedHlc: lastAppliedHlc,
                lastSyncedAtMs: lastSyncedAtMs,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String peerId,
                Value<String> lastAppliedHlc = const Value.absent(),
                Value<int?> lastSyncedAtMs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncLogCompanion.insert(
                peerId: peerId,
                lastAppliedHlc: lastAppliedHlc,
                lastSyncedAtMs: lastSyncedAtMs,
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
typedef $$GroupMembersTableCreateCompanionBuilder =
    GroupMembersCompanion Function({
      required String id,
      Value<String?> groupId,
      Value<String?> deviceId,
      Value<bool> deleted,
      Value<int> rowid,
    });
typedef $$GroupMembersTableUpdateCompanionBuilder =
    GroupMembersCompanion Function({
      Value<String> id,
      Value<String?> groupId,
      Value<String?> deviceId,
      Value<bool> deleted,
      Value<int> rowid,
    });

final class $$GroupMembersTableReferences
    extends BaseReferences<_$AppDatabase, $GroupMembersTable, GroupMember> {
  $$GroupMembersTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $SyncGroupsTable _groupIdTable(_$AppDatabase db) =>
      db.syncGroups.createAlias('group_members__group_id__sync_groups__id');

  $$SyncGroupsTableProcessedTableManager? get groupId {
    final $_column = $_itemColumn<String>('group_id');
    if ($_column == null) return null;
    final manager = $$SyncGroupsTableTableManager(
      $_db,
      $_db.syncGroups,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_groupIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $DevicesTable _deviceIdTable(_$AppDatabase db) =>
      db.devices.createAlias('group_members__device_id__devices__id');

  $$DevicesTableProcessedTableManager? get deviceId {
    final $_column = $_itemColumn<String>('device_id');
    if ($_column == null) return null;
    final manager = $$DevicesTableTableManager(
      $_db,
      $_db.devices,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_deviceIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$GroupMembersTableFilterComposer
    extends Composer<_$AppDatabase, $GroupMembersTable> {
  $$GroupMembersTableFilterComposer({
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

  ColumnFilters<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnFilters(column),
  );

  $$SyncGroupsTableFilterComposer get groupId {
    final $$SyncGroupsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.groupId,
      referencedTable: $db.syncGroups,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SyncGroupsTableFilterComposer(
            $db: $db,
            $table: $db.syncGroups,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$DevicesTableFilterComposer get deviceId {
    final $$DevicesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.deviceId,
      referencedTable: $db.devices,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DevicesTableFilterComposer(
            $db: $db,
            $table: $db.devices,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$GroupMembersTableOrderingComposer
    extends Composer<_$AppDatabase, $GroupMembersTable> {
  $$GroupMembersTableOrderingComposer({
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

  ColumnOrderings<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnOrderings(column),
  );

  $$SyncGroupsTableOrderingComposer get groupId {
    final $$SyncGroupsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.groupId,
      referencedTable: $db.syncGroups,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SyncGroupsTableOrderingComposer(
            $db: $db,
            $table: $db.syncGroups,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$DevicesTableOrderingComposer get deviceId {
    final $$DevicesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.deviceId,
      referencedTable: $db.devices,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DevicesTableOrderingComposer(
            $db: $db,
            $table: $db.devices,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$GroupMembersTableAnnotationComposer
    extends Composer<_$AppDatabase, $GroupMembersTable> {
  $$GroupMembersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);

  $$SyncGroupsTableAnnotationComposer get groupId {
    final $$SyncGroupsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.groupId,
      referencedTable: $db.syncGroups,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SyncGroupsTableAnnotationComposer(
            $db: $db,
            $table: $db.syncGroups,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$DevicesTableAnnotationComposer get deviceId {
    final $$DevicesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.deviceId,
      referencedTable: $db.devices,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DevicesTableAnnotationComposer(
            $db: $db,
            $table: $db.devices,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$GroupMembersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $GroupMembersTable,
          GroupMember,
          $$GroupMembersTableFilterComposer,
          $$GroupMembersTableOrderingComposer,
          $$GroupMembersTableAnnotationComposer,
          $$GroupMembersTableCreateCompanionBuilder,
          $$GroupMembersTableUpdateCompanionBuilder,
          (GroupMember, $$GroupMembersTableReferences),
          GroupMember,
          PrefetchHooks Function({bool groupId, bool deviceId})
        > {
  $$GroupMembersTableTableManager(_$AppDatabase db, $GroupMembersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GroupMembersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GroupMembersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$GroupMembersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> groupId = const Value.absent(),
                Value<String?> deviceId = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => GroupMembersCompanion(
                id: id,
                groupId: groupId,
                deviceId: deviceId,
                deleted: deleted,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> groupId = const Value.absent(),
                Value<String?> deviceId = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => GroupMembersCompanion.insert(
                id: id,
                groupId: groupId,
                deviceId: deviceId,
                deleted: deleted,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$GroupMembersTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({groupId = false, deviceId = false}) {
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
                    if (groupId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.groupId,
                                referencedTable: $$GroupMembersTableReferences
                                    ._groupIdTable(db),
                                referencedColumn: $$GroupMembersTableReferences
                                    ._groupIdTable(db)
                                    .id,
                              )
                              as T;
                    }
                    if (deviceId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.deviceId,
                                referencedTable: $$GroupMembersTableReferences
                                    ._deviceIdTable(db),
                                referencedColumn: $$GroupMembersTableReferences
                                    ._deviceIdTable(db)
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

typedef $$GroupMembersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $GroupMembersTable,
      GroupMember,
      $$GroupMembersTableFilterComposer,
      $$GroupMembersTableOrderingComposer,
      $$GroupMembersTableAnnotationComposer,
      $$GroupMembersTableCreateCompanionBuilder,
      $$GroupMembersTableUpdateCompanionBuilder,
      (GroupMember, $$GroupMembersTableReferences),
      GroupMember,
      PrefetchHooks Function({bool groupId, bool deviceId})
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$SyncGroupsTableTableManager get syncGroups =>
      $$SyncGroupsTableTableManager(_db, _db.syncGroups);
  $$TodoListsTableTableManager get todoLists =>
      $$TodoListsTableTableManager(_db, _db.todoLists);
  $$DevicesTableTableManager get devices =>
      $$DevicesTableTableManager(_db, _db.devices);
  $$TodosTableTableManager get todos =>
      $$TodosTableTableManager(_db, _db.todos);
  $$TodoAlarmsTableTableManager get todoAlarms =>
      $$TodoAlarmsTableTableManager(_db, _db.todoAlarms);
  $$SyncLogTableTableManager get syncLog =>
      $$SyncLogTableTableManager(_db, _db.syncLog);
  $$AlarmDismissalsTableTableManager get alarmDismissals =>
      $$AlarmDismissalsTableTableManager(_db, _db.alarmDismissals);
  $$FieldClocksTableTableManager get fieldClocks =>
      $$FieldClocksTableTableManager(_db, _db.fieldClocks);
  $$GroupMembersTableTableManager get groupMembers =>
      $$GroupMembersTableTableManager(_db, _db.groupMembers);
}
