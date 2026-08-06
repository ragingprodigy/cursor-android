// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
mixin _$AgentsDaoMixin on DatabaseAccessor<AppDatabase> {
  $AgentsTable get agents => attachedDatabase.agents;
  AgentsDaoManager get managers => AgentsDaoManager(this);
}

class AgentsDaoManager {
  final _$AgentsDaoMixin _db;
  AgentsDaoManager(this._db);
  $$AgentsTableTableManager get agents =>
      $$AgentsTableTableManager(_db.attachedDatabase, _db.agents);
}

mixin _$ThreadSnapshotsDaoMixin on DatabaseAccessor<AppDatabase> {
  $ThreadSnapshotsTable get threadSnapshots => attachedDatabase.threadSnapshots;
  ThreadSnapshotsDaoManager get managers => ThreadSnapshotsDaoManager(this);
}

class ThreadSnapshotsDaoManager {
  final _$ThreadSnapshotsDaoMixin _db;
  ThreadSnapshotsDaoManager(this._db);
  $$ThreadSnapshotsTableTableManager get threadSnapshots =>
      $$ThreadSnapshotsTableTableManager(
        _db.attachedDatabase,
        _db.threadSnapshots,
      );
}

mixin _$DraftsDaoMixin on DatabaseAccessor<AppDatabase> {
  $DraftsTable get drafts => attachedDatabase.drafts;
  DraftsDaoManager get managers => DraftsDaoManager(this);
}

class DraftsDaoManager {
  final _$DraftsDaoMixin _db;
  DraftsDaoManager(this._db);
  $$DraftsTableTableManager get drafts =>
      $$DraftsTableTableManager(_db.attachedDatabase, _db.drafts);
}

mixin _$RunPromptsDaoMixin on DatabaseAccessor<AppDatabase> {
  $RunPromptsTable get runPrompts => attachedDatabase.runPrompts;
  RunPromptsDaoManager get managers => RunPromptsDaoManager(this);
}

class RunPromptsDaoManager {
  final _$RunPromptsDaoMixin _db;
  RunPromptsDaoManager(this._db);
  $$RunPromptsTableTableManager get runPrompts =>
      $$RunPromptsTableTableManager(_db.attachedDatabase, _db.runPrompts);
}

mixin _$RunResultsDaoMixin on DatabaseAccessor<AppDatabase> {
  $RunResultsTable get runResults => attachedDatabase.runResults;
  RunResultsDaoManager get managers => RunResultsDaoManager(this);
}

class RunResultsDaoManager {
  final _$RunResultsDaoMixin _db;
  RunResultsDaoManager(this._db);
  $$RunResultsTableTableManager get runResults =>
      $$RunResultsTableTableManager(_db.attachedDatabase, _db.runResults);
}

class $AgentsTable extends Agents with TableInfo<$AgentsTable, AgentCacheRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AgentsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _urlMeta = const VerificationMeta('url');
  @override
  late final GeneratedColumn<String> url = GeneratedColumn<String>(
    'url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _latestRunIdMeta = const VerificationMeta(
    'latestRunId',
  );
  @override
  late final GeneratedColumn<String> latestRunId = GeneratedColumn<String>(
    'latest_run_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _jsonMeta = const VerificationMeta('json');
  @override
  late final GeneratedColumn<String> json = GeneratedColumn<String>(
    'json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cachedAtMeta = const VerificationMeta(
    'cachedAt',
  );
  @override
  late final GeneratedColumn<DateTime> cachedAt = GeneratedColumn<DateTime>(
    'cached_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    status,
    url,
    latestRunId,
    createdAt,
    updatedAt,
    json,
    cachedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'agents';
  @override
  VerificationContext validateIntegrity(
    Insertable<AgentCacheRow> instance, {
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
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('url')) {
      context.handle(
        _urlMeta,
        url.isAcceptableOrUnknown(data['url']!, _urlMeta),
      );
    }
    if (data.containsKey('latest_run_id')) {
      context.handle(
        _latestRunIdMeta,
        latestRunId.isAcceptableOrUnknown(
          data['latest_run_id']!,
          _latestRunIdMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('json')) {
      context.handle(
        _jsonMeta,
        json.isAcceptableOrUnknown(data['json']!, _jsonMeta),
      );
    } else if (isInserting) {
      context.missing(_jsonMeta);
    }
    if (data.containsKey('cached_at')) {
      context.handle(
        _cachedAtMeta,
        cachedAt.isAcceptableOrUnknown(data['cached_at']!, _cachedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_cachedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AgentCacheRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AgentCacheRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      url: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}url'],
      ),
      latestRunId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}latest_run_id'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      json: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}json'],
      )!,
      cachedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}cached_at'],
      )!,
    );
  }

  @override
  $AgentsTable createAlias(String alias) {
    return $AgentsTable(attachedDatabase, alias);
  }
}

class AgentCacheRow extends DataClass implements Insertable<AgentCacheRow> {
  final String id;
  final String name;
  final String status;
  final String? url;
  final String? latestRunId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String json;
  final DateTime cachedAt;
  const AgentCacheRow({
    required this.id,
    required this.name,
    required this.status,
    this.url,
    this.latestRunId,
    required this.createdAt,
    required this.updatedAt,
    required this.json,
    required this.cachedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || url != null) {
      map['url'] = Variable<String>(url);
    }
    if (!nullToAbsent || latestRunId != null) {
      map['latest_run_id'] = Variable<String>(latestRunId);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['json'] = Variable<String>(json);
    map['cached_at'] = Variable<DateTime>(cachedAt);
    return map;
  }

  AgentsCompanion toCompanion(bool nullToAbsent) {
    return AgentsCompanion(
      id: Value(id),
      name: Value(name),
      status: Value(status),
      url: url == null && nullToAbsent ? const Value.absent() : Value(url),
      latestRunId: latestRunId == null && nullToAbsent
          ? const Value.absent()
          : Value(latestRunId),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      json: Value(json),
      cachedAt: Value(cachedAt),
    );
  }

  factory AgentCacheRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AgentCacheRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      status: serializer.fromJson<String>(json['status']),
      url: serializer.fromJson<String?>(json['url']),
      latestRunId: serializer.fromJson<String?>(json['latestRunId']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      json: serializer.fromJson<String>(json['json']),
      cachedAt: serializer.fromJson<DateTime>(json['cachedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'status': serializer.toJson<String>(status),
      'url': serializer.toJson<String?>(url),
      'latestRunId': serializer.toJson<String?>(latestRunId),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'json': serializer.toJson<String>(json),
      'cachedAt': serializer.toJson<DateTime>(cachedAt),
    };
  }

  AgentCacheRow copyWith({
    String? id,
    String? name,
    String? status,
    Value<String?> url = const Value.absent(),
    Value<String?> latestRunId = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
    String? json,
    DateTime? cachedAt,
  }) => AgentCacheRow(
    id: id ?? this.id,
    name: name ?? this.name,
    status: status ?? this.status,
    url: url.present ? url.value : this.url,
    latestRunId: latestRunId.present ? latestRunId.value : this.latestRunId,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    json: json ?? this.json,
    cachedAt: cachedAt ?? this.cachedAt,
  );
  AgentCacheRow copyWithCompanion(AgentsCompanion data) {
    return AgentCacheRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      status: data.status.present ? data.status.value : this.status,
      url: data.url.present ? data.url.value : this.url,
      latestRunId: data.latestRunId.present
          ? data.latestRunId.value
          : this.latestRunId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      json: data.json.present ? data.json.value : this.json,
      cachedAt: data.cachedAt.present ? data.cachedAt.value : this.cachedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AgentCacheRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('status: $status, ')
          ..write('url: $url, ')
          ..write('latestRunId: $latestRunId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('json: $json, ')
          ..write('cachedAt: $cachedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    status,
    url,
    latestRunId,
    createdAt,
    updatedAt,
    json,
    cachedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AgentCacheRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.status == this.status &&
          other.url == this.url &&
          other.latestRunId == this.latestRunId &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.json == this.json &&
          other.cachedAt == this.cachedAt);
}

class AgentsCompanion extends UpdateCompanion<AgentCacheRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> status;
  final Value<String?> url;
  final Value<String?> latestRunId;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<String> json;
  final Value<DateTime> cachedAt;
  final Value<int> rowid;
  const AgentsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.status = const Value.absent(),
    this.url = const Value.absent(),
    this.latestRunId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.json = const Value.absent(),
    this.cachedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AgentsCompanion.insert({
    required String id,
    required String name,
    required String status,
    this.url = const Value.absent(),
    this.latestRunId = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    required String json,
    required DateTime cachedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       status = Value(status),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt),
       json = Value(json),
       cachedAt = Value(cachedAt);
  static Insertable<AgentCacheRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? status,
    Expression<String>? url,
    Expression<String>? latestRunId,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<String>? json,
    Expression<DateTime>? cachedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (status != null) 'status': status,
      if (url != null) 'url': url,
      if (latestRunId != null) 'latest_run_id': latestRunId,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (json != null) 'json': json,
      if (cachedAt != null) 'cached_at': cachedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AgentsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? status,
    Value<String?>? url,
    Value<String?>? latestRunId,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<String>? json,
    Value<DateTime>? cachedAt,
    Value<int>? rowid,
  }) {
    return AgentsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      status: status ?? this.status,
      url: url ?? this.url,
      latestRunId: latestRunId ?? this.latestRunId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      json: json ?? this.json,
      cachedAt: cachedAt ?? this.cachedAt,
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
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (url.present) {
      map['url'] = Variable<String>(url.value);
    }
    if (latestRunId.present) {
      map['latest_run_id'] = Variable<String>(latestRunId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (json.present) {
      map['json'] = Variable<String>(json.value);
    }
    if (cachedAt.present) {
      map['cached_at'] = Variable<DateTime>(cachedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AgentsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('status: $status, ')
          ..write('url: $url, ')
          ..write('latestRunId: $latestRunId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('json: $json, ')
          ..write('cachedAt: $cachedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ThreadSnapshotsTable extends ThreadSnapshots
    with TableInfo<$ThreadSnapshotsTable, ThreadSnapshotRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ThreadSnapshotsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _agentIdMeta = const VerificationMeta(
    'agentId',
  );
  @override
  late final GeneratedColumn<String> agentId = GeneratedColumn<String>(
    'agent_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _jsonMeta = const VerificationMeta('json');
  @override
  late final GeneratedColumn<String> json = GeneratedColumn<String>(
    'json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cachedAtMeta = const VerificationMeta(
    'cachedAt',
  );
  @override
  late final GeneratedColumn<DateTime> cachedAt = GeneratedColumn<DateTime>(
    'cached_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [agentId, json, cachedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'thread_snapshots';
  @override
  VerificationContext validateIntegrity(
    Insertable<ThreadSnapshotRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('agent_id')) {
      context.handle(
        _agentIdMeta,
        agentId.isAcceptableOrUnknown(data['agent_id']!, _agentIdMeta),
      );
    } else if (isInserting) {
      context.missing(_agentIdMeta);
    }
    if (data.containsKey('json')) {
      context.handle(
        _jsonMeta,
        json.isAcceptableOrUnknown(data['json']!, _jsonMeta),
      );
    } else if (isInserting) {
      context.missing(_jsonMeta);
    }
    if (data.containsKey('cached_at')) {
      context.handle(
        _cachedAtMeta,
        cachedAt.isAcceptableOrUnknown(data['cached_at']!, _cachedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_cachedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {agentId};
  @override
  ThreadSnapshotRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ThreadSnapshotRow(
      agentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}agent_id'],
      )!,
      json: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}json'],
      )!,
      cachedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}cached_at'],
      )!,
    );
  }

  @override
  $ThreadSnapshotsTable createAlias(String alias) {
    return $ThreadSnapshotsTable(attachedDatabase, alias);
  }
}

class ThreadSnapshotRow extends DataClass
    implements Insertable<ThreadSnapshotRow> {
  final String agentId;
  final String json;
  final DateTime cachedAt;
  const ThreadSnapshotRow({
    required this.agentId,
    required this.json,
    required this.cachedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['agent_id'] = Variable<String>(agentId);
    map['json'] = Variable<String>(json);
    map['cached_at'] = Variable<DateTime>(cachedAt);
    return map;
  }

  ThreadSnapshotsCompanion toCompanion(bool nullToAbsent) {
    return ThreadSnapshotsCompanion(
      agentId: Value(agentId),
      json: Value(json),
      cachedAt: Value(cachedAt),
    );
  }

  factory ThreadSnapshotRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ThreadSnapshotRow(
      agentId: serializer.fromJson<String>(json['agentId']),
      json: serializer.fromJson<String>(json['json']),
      cachedAt: serializer.fromJson<DateTime>(json['cachedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'agentId': serializer.toJson<String>(agentId),
      'json': serializer.toJson<String>(json),
      'cachedAt': serializer.toJson<DateTime>(cachedAt),
    };
  }

  ThreadSnapshotRow copyWith({
    String? agentId,
    String? json,
    DateTime? cachedAt,
  }) => ThreadSnapshotRow(
    agentId: agentId ?? this.agentId,
    json: json ?? this.json,
    cachedAt: cachedAt ?? this.cachedAt,
  );
  ThreadSnapshotRow copyWithCompanion(ThreadSnapshotsCompanion data) {
    return ThreadSnapshotRow(
      agentId: data.agentId.present ? data.agentId.value : this.agentId,
      json: data.json.present ? data.json.value : this.json,
      cachedAt: data.cachedAt.present ? data.cachedAt.value : this.cachedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ThreadSnapshotRow(')
          ..write('agentId: $agentId, ')
          ..write('json: $json, ')
          ..write('cachedAt: $cachedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(agentId, json, cachedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ThreadSnapshotRow &&
          other.agentId == this.agentId &&
          other.json == this.json &&
          other.cachedAt == this.cachedAt);
}

class ThreadSnapshotsCompanion extends UpdateCompanion<ThreadSnapshotRow> {
  final Value<String> agentId;
  final Value<String> json;
  final Value<DateTime> cachedAt;
  final Value<int> rowid;
  const ThreadSnapshotsCompanion({
    this.agentId = const Value.absent(),
    this.json = const Value.absent(),
    this.cachedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ThreadSnapshotsCompanion.insert({
    required String agentId,
    required String json,
    required DateTime cachedAt,
    this.rowid = const Value.absent(),
  }) : agentId = Value(agentId),
       json = Value(json),
       cachedAt = Value(cachedAt);
  static Insertable<ThreadSnapshotRow> custom({
    Expression<String>? agentId,
    Expression<String>? json,
    Expression<DateTime>? cachedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (agentId != null) 'agent_id': agentId,
      if (json != null) 'json': json,
      if (cachedAt != null) 'cached_at': cachedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ThreadSnapshotsCompanion copyWith({
    Value<String>? agentId,
    Value<String>? json,
    Value<DateTime>? cachedAt,
    Value<int>? rowid,
  }) {
    return ThreadSnapshotsCompanion(
      agentId: agentId ?? this.agentId,
      json: json ?? this.json,
      cachedAt: cachedAt ?? this.cachedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (agentId.present) {
      map['agent_id'] = Variable<String>(agentId.value);
    }
    if (json.present) {
      map['json'] = Variable<String>(json.value);
    }
    if (cachedAt.present) {
      map['cached_at'] = Variable<DateTime>(cachedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ThreadSnapshotsCompanion(')
          ..write('agentId: $agentId, ')
          ..write('json: $json, ')
          ..write('cachedAt: $cachedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DraftsTable extends Drafts with TableInfo<$DraftsTable, DraftRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DraftsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'text',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _repoUrlMeta = const VerificationMeta(
    'repoUrl',
  );
  @override
  late final GeneratedColumn<String> repoUrl = GeneratedColumn<String>(
    'repo_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _startingRefMeta = const VerificationMeta(
    'startingRef',
  );
  @override
  late final GeneratedColumn<String> startingRef = GeneratedColumn<String>(
    'starting_ref',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _modelIdMeta = const VerificationMeta(
    'modelId',
  );
  @override
  late final GeneratedColumn<String> modelId = GeneratedColumn<String>(
    'model_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    content,
    repoUrl,
    startingRef,
    modelId,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'drafts';
  @override
  VerificationContext validateIntegrity(
    Insertable<DraftRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('text')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['text']!, _contentMeta),
      );
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    if (data.containsKey('repo_url')) {
      context.handle(
        _repoUrlMeta,
        repoUrl.isAcceptableOrUnknown(data['repo_url']!, _repoUrlMeta),
      );
    }
    if (data.containsKey('starting_ref')) {
      context.handle(
        _startingRefMeta,
        startingRef.isAcceptableOrUnknown(
          data['starting_ref']!,
          _startingRefMeta,
        ),
      );
    }
    if (data.containsKey('model_id')) {
      context.handle(
        _modelIdMeta,
        modelId.isAcceptableOrUnknown(data['model_id']!, _modelIdMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DraftRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DraftRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}text'],
      )!,
      repoUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}repo_url'],
      ),
      startingRef: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}starting_ref'],
      ),
      modelId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}model_id'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $DraftsTable createAlias(String alias) {
    return $DraftsTable(attachedDatabase, alias);
  }
}

class DraftRow extends DataClass implements Insertable<DraftRow> {
  final String id;
  final String content;
  final String? repoUrl;
  final String? startingRef;
  final String? modelId;
  final DateTime updatedAt;
  const DraftRow({
    required this.id,
    required this.content,
    this.repoUrl,
    this.startingRef,
    this.modelId,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['text'] = Variable<String>(content);
    if (!nullToAbsent || repoUrl != null) {
      map['repo_url'] = Variable<String>(repoUrl);
    }
    if (!nullToAbsent || startingRef != null) {
      map['starting_ref'] = Variable<String>(startingRef);
    }
    if (!nullToAbsent || modelId != null) {
      map['model_id'] = Variable<String>(modelId);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  DraftsCompanion toCompanion(bool nullToAbsent) {
    return DraftsCompanion(
      id: Value(id),
      content: Value(content),
      repoUrl: repoUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(repoUrl),
      startingRef: startingRef == null && nullToAbsent
          ? const Value.absent()
          : Value(startingRef),
      modelId: modelId == null && nullToAbsent
          ? const Value.absent()
          : Value(modelId),
      updatedAt: Value(updatedAt),
    );
  }

  factory DraftRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DraftRow(
      id: serializer.fromJson<String>(json['id']),
      content: serializer.fromJson<String>(json['content']),
      repoUrl: serializer.fromJson<String?>(json['repoUrl']),
      startingRef: serializer.fromJson<String?>(json['startingRef']),
      modelId: serializer.fromJson<String?>(json['modelId']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'content': serializer.toJson<String>(content),
      'repoUrl': serializer.toJson<String?>(repoUrl),
      'startingRef': serializer.toJson<String?>(startingRef),
      'modelId': serializer.toJson<String?>(modelId),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  DraftRow copyWith({
    String? id,
    String? content,
    Value<String?> repoUrl = const Value.absent(),
    Value<String?> startingRef = const Value.absent(),
    Value<String?> modelId = const Value.absent(),
    DateTime? updatedAt,
  }) => DraftRow(
    id: id ?? this.id,
    content: content ?? this.content,
    repoUrl: repoUrl.present ? repoUrl.value : this.repoUrl,
    startingRef: startingRef.present ? startingRef.value : this.startingRef,
    modelId: modelId.present ? modelId.value : this.modelId,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  DraftRow copyWithCompanion(DraftsCompanion data) {
    return DraftRow(
      id: data.id.present ? data.id.value : this.id,
      content: data.content.present ? data.content.value : this.content,
      repoUrl: data.repoUrl.present ? data.repoUrl.value : this.repoUrl,
      startingRef: data.startingRef.present
          ? data.startingRef.value
          : this.startingRef,
      modelId: data.modelId.present ? data.modelId.value : this.modelId,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DraftRow(')
          ..write('id: $id, ')
          ..write('content: $content, ')
          ..write('repoUrl: $repoUrl, ')
          ..write('startingRef: $startingRef, ')
          ..write('modelId: $modelId, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, content, repoUrl, startingRef, modelId, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DraftRow &&
          other.id == this.id &&
          other.content == this.content &&
          other.repoUrl == this.repoUrl &&
          other.startingRef == this.startingRef &&
          other.modelId == this.modelId &&
          other.updatedAt == this.updatedAt);
}

class DraftsCompanion extends UpdateCompanion<DraftRow> {
  final Value<String> id;
  final Value<String> content;
  final Value<String?> repoUrl;
  final Value<String?> startingRef;
  final Value<String?> modelId;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const DraftsCompanion({
    this.id = const Value.absent(),
    this.content = const Value.absent(),
    this.repoUrl = const Value.absent(),
    this.startingRef = const Value.absent(),
    this.modelId = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DraftsCompanion.insert({
    required String id,
    required String content,
    this.repoUrl = const Value.absent(),
    this.startingRef = const Value.absent(),
    this.modelId = const Value.absent(),
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       content = Value(content),
       updatedAt = Value(updatedAt);
  static Insertable<DraftRow> custom({
    Expression<String>? id,
    Expression<String>? content,
    Expression<String>? repoUrl,
    Expression<String>? startingRef,
    Expression<String>? modelId,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (content != null) 'text': content,
      if (repoUrl != null) 'repo_url': repoUrl,
      if (startingRef != null) 'starting_ref': startingRef,
      if (modelId != null) 'model_id': modelId,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DraftsCompanion copyWith({
    Value<String>? id,
    Value<String>? content,
    Value<String?>? repoUrl,
    Value<String?>? startingRef,
    Value<String?>? modelId,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return DraftsCompanion(
      id: id ?? this.id,
      content: content ?? this.content,
      repoUrl: repoUrl ?? this.repoUrl,
      startingRef: startingRef ?? this.startingRef,
      modelId: modelId ?? this.modelId,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (content.present) {
      map['text'] = Variable<String>(content.value);
    }
    if (repoUrl.present) {
      map['repo_url'] = Variable<String>(repoUrl.value);
    }
    if (startingRef.present) {
      map['starting_ref'] = Variable<String>(startingRef.value);
    }
    if (modelId.present) {
      map['model_id'] = Variable<String>(modelId.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DraftsCompanion(')
          ..write('id: $id, ')
          ..write('content: $content, ')
          ..write('repoUrl: $repoUrl, ')
          ..write('startingRef: $startingRef, ')
          ..write('modelId: $modelId, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RunPromptsTable extends RunPrompts
    with TableInfo<$RunPromptsTable, RunPromptRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RunPromptsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _agentIdMeta = const VerificationMeta(
    'agentId',
  );
  @override
  late final GeneratedColumn<String> agentId = GeneratedColumn<String>(
    'agent_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _runIdMeta = const VerificationMeta('runId');
  @override
  late final GeneratedColumn<String> runId = GeneratedColumn<String>(
    'run_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'text',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [agentId, runId, content, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'run_prompts';
  @override
  VerificationContext validateIntegrity(
    Insertable<RunPromptRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('agent_id')) {
      context.handle(
        _agentIdMeta,
        agentId.isAcceptableOrUnknown(data['agent_id']!, _agentIdMeta),
      );
    } else if (isInserting) {
      context.missing(_agentIdMeta);
    }
    if (data.containsKey('run_id')) {
      context.handle(
        _runIdMeta,
        runId.isAcceptableOrUnknown(data['run_id']!, _runIdMeta),
      );
    } else if (isInserting) {
      context.missing(_runIdMeta);
    }
    if (data.containsKey('text')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['text']!, _contentMeta),
      );
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {agentId, runId};
  @override
  RunPromptRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RunPromptRow(
      agentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}agent_id'],
      )!,
      runId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}run_id'],
      )!,
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}text'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $RunPromptsTable createAlias(String alias) {
    return $RunPromptsTable(attachedDatabase, alias);
  }
}

class RunPromptRow extends DataClass implements Insertable<RunPromptRow> {
  final String agentId;
  final String runId;
  final String content;
  final DateTime createdAt;
  const RunPromptRow({
    required this.agentId,
    required this.runId,
    required this.content,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['agent_id'] = Variable<String>(agentId);
    map['run_id'] = Variable<String>(runId);
    map['text'] = Variable<String>(content);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  RunPromptsCompanion toCompanion(bool nullToAbsent) {
    return RunPromptsCompanion(
      agentId: Value(agentId),
      runId: Value(runId),
      content: Value(content),
      createdAt: Value(createdAt),
    );
  }

  factory RunPromptRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RunPromptRow(
      agentId: serializer.fromJson<String>(json['agentId']),
      runId: serializer.fromJson<String>(json['runId']),
      content: serializer.fromJson<String>(json['content']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'agentId': serializer.toJson<String>(agentId),
      'runId': serializer.toJson<String>(runId),
      'content': serializer.toJson<String>(content),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  RunPromptRow copyWith({
    String? agentId,
    String? runId,
    String? content,
    DateTime? createdAt,
  }) => RunPromptRow(
    agentId: agentId ?? this.agentId,
    runId: runId ?? this.runId,
    content: content ?? this.content,
    createdAt: createdAt ?? this.createdAt,
  );
  RunPromptRow copyWithCompanion(RunPromptsCompanion data) {
    return RunPromptRow(
      agentId: data.agentId.present ? data.agentId.value : this.agentId,
      runId: data.runId.present ? data.runId.value : this.runId,
      content: data.content.present ? data.content.value : this.content,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RunPromptRow(')
          ..write('agentId: $agentId, ')
          ..write('runId: $runId, ')
          ..write('content: $content, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(agentId, runId, content, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RunPromptRow &&
          other.agentId == this.agentId &&
          other.runId == this.runId &&
          other.content == this.content &&
          other.createdAt == this.createdAt);
}

class RunPromptsCompanion extends UpdateCompanion<RunPromptRow> {
  final Value<String> agentId;
  final Value<String> runId;
  final Value<String> content;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const RunPromptsCompanion({
    this.agentId = const Value.absent(),
    this.runId = const Value.absent(),
    this.content = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RunPromptsCompanion.insert({
    required String agentId,
    required String runId,
    required String content,
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : agentId = Value(agentId),
       runId = Value(runId),
       content = Value(content),
       createdAt = Value(createdAt);
  static Insertable<RunPromptRow> custom({
    Expression<String>? agentId,
    Expression<String>? runId,
    Expression<String>? content,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (agentId != null) 'agent_id': agentId,
      if (runId != null) 'run_id': runId,
      if (content != null) 'text': content,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RunPromptsCompanion copyWith({
    Value<String>? agentId,
    Value<String>? runId,
    Value<String>? content,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return RunPromptsCompanion(
      agentId: agentId ?? this.agentId,
      runId: runId ?? this.runId,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (agentId.present) {
      map['agent_id'] = Variable<String>(agentId.value);
    }
    if (runId.present) {
      map['run_id'] = Variable<String>(runId.value);
    }
    if (content.present) {
      map['text'] = Variable<String>(content.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RunPromptsCompanion(')
          ..write('agentId: $agentId, ')
          ..write('runId: $runId, ')
          ..write('content: $content, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RunResultsTable extends RunResults
    with TableInfo<$RunResultsTable, RunResultRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RunResultsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _agentIdMeta = const VerificationMeta(
    'agentId',
  );
  @override
  late final GeneratedColumn<String> agentId = GeneratedColumn<String>(
    'agent_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _runIdMeta = const VerificationMeta('runId');
  @override
  late final GeneratedColumn<String> runId = GeneratedColumn<String>(
    'run_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'text',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [agentId, runId, content, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'run_results';
  @override
  VerificationContext validateIntegrity(
    Insertable<RunResultRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('agent_id')) {
      context.handle(
        _agentIdMeta,
        agentId.isAcceptableOrUnknown(data['agent_id']!, _agentIdMeta),
      );
    } else if (isInserting) {
      context.missing(_agentIdMeta);
    }
    if (data.containsKey('run_id')) {
      context.handle(
        _runIdMeta,
        runId.isAcceptableOrUnknown(data['run_id']!, _runIdMeta),
      );
    } else if (isInserting) {
      context.missing(_runIdMeta);
    }
    if (data.containsKey('text')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['text']!, _contentMeta),
      );
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {agentId, runId};
  @override
  RunResultRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RunResultRow(
      agentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}agent_id'],
      )!,
      runId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}run_id'],
      )!,
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}text'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $RunResultsTable createAlias(String alias) {
    return $RunResultsTable(attachedDatabase, alias);
  }
}

class RunResultRow extends DataClass implements Insertable<RunResultRow> {
  final String agentId;
  final String runId;
  final String content;
  final DateTime createdAt;
  const RunResultRow({
    required this.agentId,
    required this.runId,
    required this.content,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['agent_id'] = Variable<String>(agentId);
    map['run_id'] = Variable<String>(runId);
    map['text'] = Variable<String>(content);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  RunResultsCompanion toCompanion(bool nullToAbsent) {
    return RunResultsCompanion(
      agentId: Value(agentId),
      runId: Value(runId),
      content: Value(content),
      createdAt: Value(createdAt),
    );
  }

  factory RunResultRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RunResultRow(
      agentId: serializer.fromJson<String>(json['agentId']),
      runId: serializer.fromJson<String>(json['runId']),
      content: serializer.fromJson<String>(json['content']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'agentId': serializer.toJson<String>(agentId),
      'runId': serializer.toJson<String>(runId),
      'content': serializer.toJson<String>(content),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  RunResultRow copyWith({
    String? agentId,
    String? runId,
    String? content,
    DateTime? createdAt,
  }) => RunResultRow(
    agentId: agentId ?? this.agentId,
    runId: runId ?? this.runId,
    content: content ?? this.content,
    createdAt: createdAt ?? this.createdAt,
  );
  RunResultRow copyWithCompanion(RunResultsCompanion data) {
    return RunResultRow(
      agentId: data.agentId.present ? data.agentId.value : this.agentId,
      runId: data.runId.present ? data.runId.value : this.runId,
      content: data.content.present ? data.content.value : this.content,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RunResultRow(')
          ..write('agentId: $agentId, ')
          ..write('runId: $runId, ')
          ..write('content: $content, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(agentId, runId, content, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RunResultRow &&
          other.agentId == this.agentId &&
          other.runId == this.runId &&
          other.content == this.content &&
          other.createdAt == this.createdAt);
}

class RunResultsCompanion extends UpdateCompanion<RunResultRow> {
  final Value<String> agentId;
  final Value<String> runId;
  final Value<String> content;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const RunResultsCompanion({
    this.agentId = const Value.absent(),
    this.runId = const Value.absent(),
    this.content = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RunResultsCompanion.insert({
    required String agentId,
    required String runId,
    required String content,
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : agentId = Value(agentId),
       runId = Value(runId),
       content = Value(content),
       createdAt = Value(createdAt);
  static Insertable<RunResultRow> custom({
    Expression<String>? agentId,
    Expression<String>? runId,
    Expression<String>? content,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (agentId != null) 'agent_id': agentId,
      if (runId != null) 'run_id': runId,
      if (content != null) 'text': content,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RunResultsCompanion copyWith({
    Value<String>? agentId,
    Value<String>? runId,
    Value<String>? content,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return RunResultsCompanion(
      agentId: agentId ?? this.agentId,
      runId: runId ?? this.runId,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (agentId.present) {
      map['agent_id'] = Variable<String>(agentId.value);
    }
    if (runId.present) {
      map['run_id'] = Variable<String>(runId.value);
    }
    if (content.present) {
      map['text'] = Variable<String>(content.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RunResultsCompanion(')
          ..write('agentId: $agentId, ')
          ..write('runId: $runId, ')
          ..write('content: $content, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $AgentsTable agents = $AgentsTable(this);
  late final $ThreadSnapshotsTable threadSnapshots = $ThreadSnapshotsTable(
    this,
  );
  late final $DraftsTable drafts = $DraftsTable(this);
  late final $RunPromptsTable runPrompts = $RunPromptsTable(this);
  late final $RunResultsTable runResults = $RunResultsTable(this);
  late final AgentsDao agentsDao = AgentsDao(this as AppDatabase);
  late final ThreadSnapshotsDao threadSnapshotsDao = ThreadSnapshotsDao(
    this as AppDatabase,
  );
  late final DraftsDao draftsDao = DraftsDao(this as AppDatabase);
  late final RunPromptsDao runPromptsDao = RunPromptsDao(this as AppDatabase);
  late final RunResultsDao runResultsDao = RunResultsDao(this as AppDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    agents,
    threadSnapshots,
    drafts,
    runPrompts,
    runResults,
  ];
}

typedef $$AgentsTableCreateCompanionBuilder =
    AgentsCompanion Function({
      required String id,
      required String name,
      required String status,
      Value<String?> url,
      Value<String?> latestRunId,
      required DateTime createdAt,
      required DateTime updatedAt,
      required String json,
      required DateTime cachedAt,
      Value<int> rowid,
    });
typedef $$AgentsTableUpdateCompanionBuilder =
    AgentsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> status,
      Value<String?> url,
      Value<String?> latestRunId,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<String> json,
      Value<DateTime> cachedAt,
      Value<int> rowid,
    });

class $$AgentsTableFilterComposer
    extends Composer<_$AppDatabase, $AgentsTable> {
  $$AgentsTableFilterComposer({
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

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get latestRunId => $composableBuilder(
    column: $table.latestRunId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get json => $composableBuilder(
    column: $table.json,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AgentsTableOrderingComposer
    extends Composer<_$AppDatabase, $AgentsTable> {
  $$AgentsTableOrderingComposer({
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

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get latestRunId => $composableBuilder(
    column: $table.latestRunId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get json => $composableBuilder(
    column: $table.json,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AgentsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AgentsTable> {
  $$AgentsTableAnnotationComposer({
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

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get url =>
      $composableBuilder(column: $table.url, builder: (column) => column);

  GeneratedColumn<String> get latestRunId => $composableBuilder(
    column: $table.latestRunId,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get json =>
      $composableBuilder(column: $table.json, builder: (column) => column);

  GeneratedColumn<DateTime> get cachedAt =>
      $composableBuilder(column: $table.cachedAt, builder: (column) => column);
}

class $$AgentsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AgentsTable,
          AgentCacheRow,
          $$AgentsTableFilterComposer,
          $$AgentsTableOrderingComposer,
          $$AgentsTableAnnotationComposer,
          $$AgentsTableCreateCompanionBuilder,
          $$AgentsTableUpdateCompanionBuilder,
          (
            AgentCacheRow,
            BaseReferences<_$AppDatabase, $AgentsTable, AgentCacheRow>,
          ),
          AgentCacheRow,
          PrefetchHooks Function()
        > {
  $$AgentsTableTableManager(_$AppDatabase db, $AgentsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AgentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AgentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AgentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> url = const Value.absent(),
                Value<String?> latestRunId = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<String> json = const Value.absent(),
                Value<DateTime> cachedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AgentsCompanion(
                id: id,
                name: name,
                status: status,
                url: url,
                latestRunId: latestRunId,
                createdAt: createdAt,
                updatedAt: updatedAt,
                json: json,
                cachedAt: cachedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String status,
                Value<String?> url = const Value.absent(),
                Value<String?> latestRunId = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                required String json,
                required DateTime cachedAt,
                Value<int> rowid = const Value.absent(),
              }) => AgentsCompanion.insert(
                id: id,
                name: name,
                status: status,
                url: url,
                latestRunId: latestRunId,
                createdAt: createdAt,
                updatedAt: updatedAt,
                json: json,
                cachedAt: cachedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AgentsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AgentsTable,
      AgentCacheRow,
      $$AgentsTableFilterComposer,
      $$AgentsTableOrderingComposer,
      $$AgentsTableAnnotationComposer,
      $$AgentsTableCreateCompanionBuilder,
      $$AgentsTableUpdateCompanionBuilder,
      (
        AgentCacheRow,
        BaseReferences<_$AppDatabase, $AgentsTable, AgentCacheRow>,
      ),
      AgentCacheRow,
      PrefetchHooks Function()
    >;
typedef $$ThreadSnapshotsTableCreateCompanionBuilder =
    ThreadSnapshotsCompanion Function({
      required String agentId,
      required String json,
      required DateTime cachedAt,
      Value<int> rowid,
    });
typedef $$ThreadSnapshotsTableUpdateCompanionBuilder =
    ThreadSnapshotsCompanion Function({
      Value<String> agentId,
      Value<String> json,
      Value<DateTime> cachedAt,
      Value<int> rowid,
    });

class $$ThreadSnapshotsTableFilterComposer
    extends Composer<_$AppDatabase, $ThreadSnapshotsTable> {
  $$ThreadSnapshotsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get agentId => $composableBuilder(
    column: $table.agentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get json => $composableBuilder(
    column: $table.json,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ThreadSnapshotsTableOrderingComposer
    extends Composer<_$AppDatabase, $ThreadSnapshotsTable> {
  $$ThreadSnapshotsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get agentId => $composableBuilder(
    column: $table.agentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get json => $composableBuilder(
    column: $table.json,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ThreadSnapshotsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ThreadSnapshotsTable> {
  $$ThreadSnapshotsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get agentId =>
      $composableBuilder(column: $table.agentId, builder: (column) => column);

  GeneratedColumn<String> get json =>
      $composableBuilder(column: $table.json, builder: (column) => column);

  GeneratedColumn<DateTime> get cachedAt =>
      $composableBuilder(column: $table.cachedAt, builder: (column) => column);
}

class $$ThreadSnapshotsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ThreadSnapshotsTable,
          ThreadSnapshotRow,
          $$ThreadSnapshotsTableFilterComposer,
          $$ThreadSnapshotsTableOrderingComposer,
          $$ThreadSnapshotsTableAnnotationComposer,
          $$ThreadSnapshotsTableCreateCompanionBuilder,
          $$ThreadSnapshotsTableUpdateCompanionBuilder,
          (
            ThreadSnapshotRow,
            BaseReferences<
              _$AppDatabase,
              $ThreadSnapshotsTable,
              ThreadSnapshotRow
            >,
          ),
          ThreadSnapshotRow,
          PrefetchHooks Function()
        > {
  $$ThreadSnapshotsTableTableManager(
    _$AppDatabase db,
    $ThreadSnapshotsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ThreadSnapshotsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ThreadSnapshotsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ThreadSnapshotsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> agentId = const Value.absent(),
                Value<String> json = const Value.absent(),
                Value<DateTime> cachedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ThreadSnapshotsCompanion(
                agentId: agentId,
                json: json,
                cachedAt: cachedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String agentId,
                required String json,
                required DateTime cachedAt,
                Value<int> rowid = const Value.absent(),
              }) => ThreadSnapshotsCompanion.insert(
                agentId: agentId,
                json: json,
                cachedAt: cachedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ThreadSnapshotsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ThreadSnapshotsTable,
      ThreadSnapshotRow,
      $$ThreadSnapshotsTableFilterComposer,
      $$ThreadSnapshotsTableOrderingComposer,
      $$ThreadSnapshotsTableAnnotationComposer,
      $$ThreadSnapshotsTableCreateCompanionBuilder,
      $$ThreadSnapshotsTableUpdateCompanionBuilder,
      (
        ThreadSnapshotRow,
        BaseReferences<_$AppDatabase, $ThreadSnapshotsTable, ThreadSnapshotRow>,
      ),
      ThreadSnapshotRow,
      PrefetchHooks Function()
    >;
typedef $$DraftsTableCreateCompanionBuilder =
    DraftsCompanion Function({
      required String id,
      required String content,
      Value<String?> repoUrl,
      Value<String?> startingRef,
      Value<String?> modelId,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$DraftsTableUpdateCompanionBuilder =
    DraftsCompanion Function({
      Value<String> id,
      Value<String> content,
      Value<String?> repoUrl,
      Value<String?> startingRef,
      Value<String?> modelId,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$DraftsTableFilterComposer
    extends Composer<_$AppDatabase, $DraftsTable> {
  $$DraftsTableFilterComposer({
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

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get repoUrl => $composableBuilder(
    column: $table.repoUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get startingRef => $composableBuilder(
    column: $table.startingRef,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get modelId => $composableBuilder(
    column: $table.modelId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DraftsTableOrderingComposer
    extends Composer<_$AppDatabase, $DraftsTable> {
  $$DraftsTableOrderingComposer({
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

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get repoUrl => $composableBuilder(
    column: $table.repoUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get startingRef => $composableBuilder(
    column: $table.startingRef,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get modelId => $composableBuilder(
    column: $table.modelId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DraftsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DraftsTable> {
  $$DraftsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<String> get repoUrl =>
      $composableBuilder(column: $table.repoUrl, builder: (column) => column);

  GeneratedColumn<String> get startingRef => $composableBuilder(
    column: $table.startingRef,
    builder: (column) => column,
  );

  GeneratedColumn<String> get modelId =>
      $composableBuilder(column: $table.modelId, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$DraftsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DraftsTable,
          DraftRow,
          $$DraftsTableFilterComposer,
          $$DraftsTableOrderingComposer,
          $$DraftsTableAnnotationComposer,
          $$DraftsTableCreateCompanionBuilder,
          $$DraftsTableUpdateCompanionBuilder,
          (DraftRow, BaseReferences<_$AppDatabase, $DraftsTable, DraftRow>),
          DraftRow,
          PrefetchHooks Function()
        > {
  $$DraftsTableTableManager(_$AppDatabase db, $DraftsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DraftsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DraftsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DraftsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> content = const Value.absent(),
                Value<String?> repoUrl = const Value.absent(),
                Value<String?> startingRef = const Value.absent(),
                Value<String?> modelId = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DraftsCompanion(
                id: id,
                content: content,
                repoUrl: repoUrl,
                startingRef: startingRef,
                modelId: modelId,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String content,
                Value<String?> repoUrl = const Value.absent(),
                Value<String?> startingRef = const Value.absent(),
                Value<String?> modelId = const Value.absent(),
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => DraftsCompanion.insert(
                id: id,
                content: content,
                repoUrl: repoUrl,
                startingRef: startingRef,
                modelId: modelId,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DraftsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DraftsTable,
      DraftRow,
      $$DraftsTableFilterComposer,
      $$DraftsTableOrderingComposer,
      $$DraftsTableAnnotationComposer,
      $$DraftsTableCreateCompanionBuilder,
      $$DraftsTableUpdateCompanionBuilder,
      (DraftRow, BaseReferences<_$AppDatabase, $DraftsTable, DraftRow>),
      DraftRow,
      PrefetchHooks Function()
    >;
typedef $$RunPromptsTableCreateCompanionBuilder =
    RunPromptsCompanion Function({
      required String agentId,
      required String runId,
      required String content,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$RunPromptsTableUpdateCompanionBuilder =
    RunPromptsCompanion Function({
      Value<String> agentId,
      Value<String> runId,
      Value<String> content,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $$RunPromptsTableFilterComposer
    extends Composer<_$AppDatabase, $RunPromptsTable> {
  $$RunPromptsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get agentId => $composableBuilder(
    column: $table.agentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get runId => $composableBuilder(
    column: $table.runId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RunPromptsTableOrderingComposer
    extends Composer<_$AppDatabase, $RunPromptsTable> {
  $$RunPromptsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get agentId => $composableBuilder(
    column: $table.agentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get runId => $composableBuilder(
    column: $table.runId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RunPromptsTableAnnotationComposer
    extends Composer<_$AppDatabase, $RunPromptsTable> {
  $$RunPromptsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get agentId =>
      $composableBuilder(column: $table.agentId, builder: (column) => column);

  GeneratedColumn<String> get runId =>
      $composableBuilder(column: $table.runId, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$RunPromptsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RunPromptsTable,
          RunPromptRow,
          $$RunPromptsTableFilterComposer,
          $$RunPromptsTableOrderingComposer,
          $$RunPromptsTableAnnotationComposer,
          $$RunPromptsTableCreateCompanionBuilder,
          $$RunPromptsTableUpdateCompanionBuilder,
          (
            RunPromptRow,
            BaseReferences<_$AppDatabase, $RunPromptsTable, RunPromptRow>,
          ),
          RunPromptRow,
          PrefetchHooks Function()
        > {
  $$RunPromptsTableTableManager(_$AppDatabase db, $RunPromptsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RunPromptsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RunPromptsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RunPromptsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> agentId = const Value.absent(),
                Value<String> runId = const Value.absent(),
                Value<String> content = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RunPromptsCompanion(
                agentId: agentId,
                runId: runId,
                content: content,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String agentId,
                required String runId,
                required String content,
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => RunPromptsCompanion.insert(
                agentId: agentId,
                runId: runId,
                content: content,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RunPromptsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RunPromptsTable,
      RunPromptRow,
      $$RunPromptsTableFilterComposer,
      $$RunPromptsTableOrderingComposer,
      $$RunPromptsTableAnnotationComposer,
      $$RunPromptsTableCreateCompanionBuilder,
      $$RunPromptsTableUpdateCompanionBuilder,
      (
        RunPromptRow,
        BaseReferences<_$AppDatabase, $RunPromptsTable, RunPromptRow>,
      ),
      RunPromptRow,
      PrefetchHooks Function()
    >;
typedef $$RunResultsTableCreateCompanionBuilder =
    RunResultsCompanion Function({
      required String agentId,
      required String runId,
      required String content,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$RunResultsTableUpdateCompanionBuilder =
    RunResultsCompanion Function({
      Value<String> agentId,
      Value<String> runId,
      Value<String> content,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $$RunResultsTableFilterComposer
    extends Composer<_$AppDatabase, $RunResultsTable> {
  $$RunResultsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get agentId => $composableBuilder(
    column: $table.agentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get runId => $composableBuilder(
    column: $table.runId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RunResultsTableOrderingComposer
    extends Composer<_$AppDatabase, $RunResultsTable> {
  $$RunResultsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get agentId => $composableBuilder(
    column: $table.agentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get runId => $composableBuilder(
    column: $table.runId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RunResultsTableAnnotationComposer
    extends Composer<_$AppDatabase, $RunResultsTable> {
  $$RunResultsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get agentId =>
      $composableBuilder(column: $table.agentId, builder: (column) => column);

  GeneratedColumn<String> get runId =>
      $composableBuilder(column: $table.runId, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$RunResultsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RunResultsTable,
          RunResultRow,
          $$RunResultsTableFilterComposer,
          $$RunResultsTableOrderingComposer,
          $$RunResultsTableAnnotationComposer,
          $$RunResultsTableCreateCompanionBuilder,
          $$RunResultsTableUpdateCompanionBuilder,
          (
            RunResultRow,
            BaseReferences<_$AppDatabase, $RunResultsTable, RunResultRow>,
          ),
          RunResultRow,
          PrefetchHooks Function()
        > {
  $$RunResultsTableTableManager(_$AppDatabase db, $RunResultsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RunResultsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RunResultsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RunResultsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> agentId = const Value.absent(),
                Value<String> runId = const Value.absent(),
                Value<String> content = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RunResultsCompanion(
                agentId: agentId,
                runId: runId,
                content: content,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String agentId,
                required String runId,
                required String content,
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => RunResultsCompanion.insert(
                agentId: agentId,
                runId: runId,
                content: content,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RunResultsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RunResultsTable,
      RunResultRow,
      $$RunResultsTableFilterComposer,
      $$RunResultsTableOrderingComposer,
      $$RunResultsTableAnnotationComposer,
      $$RunResultsTableCreateCompanionBuilder,
      $$RunResultsTableUpdateCompanionBuilder,
      (
        RunResultRow,
        BaseReferences<_$AppDatabase, $RunResultsTable, RunResultRow>,
      ),
      RunResultRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$AgentsTableTableManager get agents =>
      $$AgentsTableTableManager(_db, _db.agents);
  $$ThreadSnapshotsTableTableManager get threadSnapshots =>
      $$ThreadSnapshotsTableTableManager(_db, _db.threadSnapshots);
  $$DraftsTableTableManager get drafts =>
      $$DraftsTableTableManager(_db, _db.drafts);
  $$RunPromptsTableTableManager get runPrompts =>
      $$RunPromptsTableTableManager(_db, _db.runPrompts);
  $$RunResultsTableTableManager get runResults =>
      $$RunResultsTableTableManager(_db, _db.runResults);
}
