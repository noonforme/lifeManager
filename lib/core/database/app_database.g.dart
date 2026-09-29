// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $CoreMetadataTable extends CoreMetadata
    with TableInfo<$CoreMetadataTable, CoreMetadataData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CoreMetadataTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _applicationVersionMeta =
      const VerificationMeta('applicationVersion');
  @override
  late final GeneratedColumn<String> applicationVersion =
      GeneratedColumn<String>(
        'application_version',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _snapshotSchemaVersionMeta =
      const VerificationMeta('snapshotSchemaVersion');
  @override
  late final GeneratedColumn<int> snapshotSchemaVersion = GeneratedColumn<int>(
    'snapshot_schema_version',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _snapshotCreatedAtUtcMeta =
      const VerificationMeta('snapshotCreatedAtUtc');
  @override
  late final GeneratedColumn<String> snapshotCreatedAtUtc =
      GeneratedColumn<String>(
        'snapshot_created_at_utc',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    applicationVersion,
    snapshotSchemaVersion,
    snapshotCreatedAtUtc,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'core_metadata';
  @override
  VerificationContext validateIntegrity(
    Insertable<CoreMetadataData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('application_version')) {
      context.handle(
        _applicationVersionMeta,
        applicationVersion.isAcceptableOrUnknown(
          data['application_version']!,
          _applicationVersionMeta,
        ),
      );
    }
    if (data.containsKey('snapshot_schema_version')) {
      context.handle(
        _snapshotSchemaVersionMeta,
        snapshotSchemaVersion.isAcceptableOrUnknown(
          data['snapshot_schema_version']!,
          _snapshotSchemaVersionMeta,
        ),
      );
    }
    if (data.containsKey('snapshot_created_at_utc')) {
      context.handle(
        _snapshotCreatedAtUtcMeta,
        snapshotCreatedAtUtc.isAcceptableOrUnknown(
          data['snapshot_created_at_utc']!,
          _snapshotCreatedAtUtcMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CoreMetadataData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CoreMetadataData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      applicationVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}application_version'],
      ),
      snapshotSchemaVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}snapshot_schema_version'],
      ),
      snapshotCreatedAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}snapshot_created_at_utc'],
      ),
    );
  }

  @override
  $CoreMetadataTable createAlias(String alias) {
    return $CoreMetadataTable(attachedDatabase, alias);
  }
}

class CoreMetadataData extends DataClass
    implements Insertable<CoreMetadataData> {
  final int id;
  final String? applicationVersion;
  final int? snapshotSchemaVersion;
  final String? snapshotCreatedAtUtc;
  const CoreMetadataData({
    required this.id,
    this.applicationVersion,
    this.snapshotSchemaVersion,
    this.snapshotCreatedAtUtc,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || applicationVersion != null) {
      map['application_version'] = Variable<String>(applicationVersion);
    }
    if (!nullToAbsent || snapshotSchemaVersion != null) {
      map['snapshot_schema_version'] = Variable<int>(snapshotSchemaVersion);
    }
    if (!nullToAbsent || snapshotCreatedAtUtc != null) {
      map['snapshot_created_at_utc'] = Variable<String>(snapshotCreatedAtUtc);
    }
    return map;
  }

  CoreMetadataCompanion toCompanion(bool nullToAbsent) {
    return CoreMetadataCompanion(
      id: Value(id),
      applicationVersion: applicationVersion == null && nullToAbsent
          ? const Value.absent()
          : Value(applicationVersion),
      snapshotSchemaVersion: snapshotSchemaVersion == null && nullToAbsent
          ? const Value.absent()
          : Value(snapshotSchemaVersion),
      snapshotCreatedAtUtc: snapshotCreatedAtUtc == null && nullToAbsent
          ? const Value.absent()
          : Value(snapshotCreatedAtUtc),
    );
  }

  factory CoreMetadataData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CoreMetadataData(
      id: serializer.fromJson<int>(json['id']),
      applicationVersion: serializer.fromJson<String?>(
        json['applicationVersion'],
      ),
      snapshotSchemaVersion: serializer.fromJson<int?>(
        json['snapshotSchemaVersion'],
      ),
      snapshotCreatedAtUtc: serializer.fromJson<String?>(
        json['snapshotCreatedAtUtc'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'applicationVersion': serializer.toJson<String?>(applicationVersion),
      'snapshotSchemaVersion': serializer.toJson<int?>(snapshotSchemaVersion),
      'snapshotCreatedAtUtc': serializer.toJson<String?>(snapshotCreatedAtUtc),
    };
  }

  CoreMetadataData copyWith({
    int? id,
    Value<String?> applicationVersion = const Value.absent(),
    Value<int?> snapshotSchemaVersion = const Value.absent(),
    Value<String?> snapshotCreatedAtUtc = const Value.absent(),
  }) => CoreMetadataData(
    id: id ?? this.id,
    applicationVersion: applicationVersion.present
        ? applicationVersion.value
        : this.applicationVersion,
    snapshotSchemaVersion: snapshotSchemaVersion.present
        ? snapshotSchemaVersion.value
        : this.snapshotSchemaVersion,
    snapshotCreatedAtUtc: snapshotCreatedAtUtc.present
        ? snapshotCreatedAtUtc.value
        : this.snapshotCreatedAtUtc,
  );
  CoreMetadataData copyWithCompanion(CoreMetadataCompanion data) {
    return CoreMetadataData(
      id: data.id.present ? data.id.value : this.id,
      applicationVersion: data.applicationVersion.present
          ? data.applicationVersion.value
          : this.applicationVersion,
      snapshotSchemaVersion: data.snapshotSchemaVersion.present
          ? data.snapshotSchemaVersion.value
          : this.snapshotSchemaVersion,
      snapshotCreatedAtUtc: data.snapshotCreatedAtUtc.present
          ? data.snapshotCreatedAtUtc.value
          : this.snapshotCreatedAtUtc,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CoreMetadataData(')
          ..write('id: $id, ')
          ..write('applicationVersion: $applicationVersion, ')
          ..write('snapshotSchemaVersion: $snapshotSchemaVersion, ')
          ..write('snapshotCreatedAtUtc: $snapshotCreatedAtUtc')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    applicationVersion,
    snapshotSchemaVersion,
    snapshotCreatedAtUtc,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CoreMetadataData &&
          other.id == this.id &&
          other.applicationVersion == this.applicationVersion &&
          other.snapshotSchemaVersion == this.snapshotSchemaVersion &&
          other.snapshotCreatedAtUtc == this.snapshotCreatedAtUtc);
}

class CoreMetadataCompanion extends UpdateCompanion<CoreMetadataData> {
  final Value<int> id;
  final Value<String?> applicationVersion;
  final Value<int?> snapshotSchemaVersion;
  final Value<String?> snapshotCreatedAtUtc;
  const CoreMetadataCompanion({
    this.id = const Value.absent(),
    this.applicationVersion = const Value.absent(),
    this.snapshotSchemaVersion = const Value.absent(),
    this.snapshotCreatedAtUtc = const Value.absent(),
  });
  CoreMetadataCompanion.insert({
    this.id = const Value.absent(),
    this.applicationVersion = const Value.absent(),
    this.snapshotSchemaVersion = const Value.absent(),
    this.snapshotCreatedAtUtc = const Value.absent(),
  });
  static Insertable<CoreMetadataData> custom({
    Expression<int>? id,
    Expression<String>? applicationVersion,
    Expression<int>? snapshotSchemaVersion,
    Expression<String>? snapshotCreatedAtUtc,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (applicationVersion != null) 'application_version': applicationVersion,
      if (snapshotSchemaVersion != null)
        'snapshot_schema_version': snapshotSchemaVersion,
      if (snapshotCreatedAtUtc != null)
        'snapshot_created_at_utc': snapshotCreatedAtUtc,
    });
  }

  CoreMetadataCompanion copyWith({
    Value<int>? id,
    Value<String?>? applicationVersion,
    Value<int?>? snapshotSchemaVersion,
    Value<String?>? snapshotCreatedAtUtc,
  }) {
    return CoreMetadataCompanion(
      id: id ?? this.id,
      applicationVersion: applicationVersion ?? this.applicationVersion,
      snapshotSchemaVersion:
          snapshotSchemaVersion ?? this.snapshotSchemaVersion,
      snapshotCreatedAtUtc: snapshotCreatedAtUtc ?? this.snapshotCreatedAtUtc,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (applicationVersion.present) {
      map['application_version'] = Variable<String>(applicationVersion.value);
    }
    if (snapshotSchemaVersion.present) {
      map['snapshot_schema_version'] = Variable<int>(
        snapshotSchemaVersion.value,
      );
    }
    if (snapshotCreatedAtUtc.present) {
      map['snapshot_created_at_utc'] = Variable<String>(
        snapshotCreatedAtUtc.value,
      );
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CoreMetadataCompanion(')
          ..write('id: $id, ')
          ..write('applicationVersion: $applicationVersion, ')
          ..write('snapshotSchemaVersion: $snapshotSchemaVersion, ')
          ..write('snapshotCreatedAtUtc: $snapshotCreatedAtUtc')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $CoreMetadataTable coreMetadata = $CoreMetadataTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [coreMetadata];
}

typedef $$CoreMetadataTableCreateCompanionBuilder =
    CoreMetadataCompanion Function({
      Value<int> id,
      Value<String?> applicationVersion,
      Value<int?> snapshotSchemaVersion,
      Value<String?> snapshotCreatedAtUtc,
    });
typedef $$CoreMetadataTableUpdateCompanionBuilder =
    CoreMetadataCompanion Function({
      Value<int> id,
      Value<String?> applicationVersion,
      Value<int?> snapshotSchemaVersion,
      Value<String?> snapshotCreatedAtUtc,
    });

class $$CoreMetadataTableFilterComposer
    extends Composer<_$AppDatabase, $CoreMetadataTable> {
  $$CoreMetadataTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get applicationVersion => $composableBuilder(
    column: $table.applicationVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get snapshotSchemaVersion => $composableBuilder(
    column: $table.snapshotSchemaVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get snapshotCreatedAtUtc => $composableBuilder(
    column: $table.snapshotCreatedAtUtc,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CoreMetadataTableOrderingComposer
    extends Composer<_$AppDatabase, $CoreMetadataTable> {
  $$CoreMetadataTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get applicationVersion => $composableBuilder(
    column: $table.applicationVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get snapshotSchemaVersion => $composableBuilder(
    column: $table.snapshotSchemaVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get snapshotCreatedAtUtc => $composableBuilder(
    column: $table.snapshotCreatedAtUtc,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CoreMetadataTableAnnotationComposer
    extends Composer<_$AppDatabase, $CoreMetadataTable> {
  $$CoreMetadataTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get applicationVersion => $composableBuilder(
    column: $table.applicationVersion,
    builder: (column) => column,
  );

  GeneratedColumn<int> get snapshotSchemaVersion => $composableBuilder(
    column: $table.snapshotSchemaVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get snapshotCreatedAtUtc => $composableBuilder(
    column: $table.snapshotCreatedAtUtc,
    builder: (column) => column,
  );
}

class $$CoreMetadataTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CoreMetadataTable,
          CoreMetadataData,
          $$CoreMetadataTableFilterComposer,
          $$CoreMetadataTableOrderingComposer,
          $$CoreMetadataTableAnnotationComposer,
          $$CoreMetadataTableCreateCompanionBuilder,
          $$CoreMetadataTableUpdateCompanionBuilder,
          (
            CoreMetadataData,
            BaseReferences<_$AppDatabase, $CoreMetadataTable, CoreMetadataData>,
          ),
          CoreMetadataData,
          PrefetchHooks Function()
        > {
  $$CoreMetadataTableTableManager(_$AppDatabase db, $CoreMetadataTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CoreMetadataTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CoreMetadataTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CoreMetadataTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> applicationVersion = const Value.absent(),
                Value<int?> snapshotSchemaVersion = const Value.absent(),
                Value<String?> snapshotCreatedAtUtc = const Value.absent(),
              }) => CoreMetadataCompanion(
                id: id,
                applicationVersion: applicationVersion,
                snapshotSchemaVersion: snapshotSchemaVersion,
                snapshotCreatedAtUtc: snapshotCreatedAtUtc,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> applicationVersion = const Value.absent(),
                Value<int?> snapshotSchemaVersion = const Value.absent(),
                Value<String?> snapshotCreatedAtUtc = const Value.absent(),
              }) => CoreMetadataCompanion.insert(
                id: id,
                applicationVersion: applicationVersion,
                snapshotSchemaVersion: snapshotSchemaVersion,
                snapshotCreatedAtUtc: snapshotCreatedAtUtc,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CoreMetadataTable, CoreMetadataData>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $CoreMetadataTable,
                    CoreMetadataData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CoreMetadataTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CoreMetadataTable,
      CoreMetadataData,
      $$CoreMetadataTableFilterComposer,
      $$CoreMetadataTableOrderingComposer,
      $$CoreMetadataTableAnnotationComposer,
      $$CoreMetadataTableCreateCompanionBuilder,
      $$CoreMetadataTableUpdateCompanionBuilder,
      (
        CoreMetadataData,
        BaseReferences<_$AppDatabase, $CoreMetadataTable, CoreMetadataData>,
      ),
      CoreMetadataData,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$CoreMetadataTableTableManager get coreMetadata =>
      $$CoreMetadataTableTableManager(_db, _db.coreMetadata);
}
