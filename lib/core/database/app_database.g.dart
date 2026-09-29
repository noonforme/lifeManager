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

class $EmploymentsTable extends Employments
    with TableInfo<$EmploymentsTable, Employment> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EmploymentsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _legalLabelMeta = const VerificationMeta(
    'legalLabel',
  );
  @override
  late final GeneratedColumn<String> legalLabel = GeneratedColumn<String>(
    'legal_label',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
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
  static const VerificationMeta _createdAtUtcMicrosMeta =
      const VerificationMeta('createdAtUtcMicros');
  @override
  late final GeneratedColumn<int> createdAtUtcMicros = GeneratedColumn<int>(
    'created_at_utc_micros',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtUtcMicrosMeta =
      const VerificationMeta('updatedAtUtcMicros');
  @override
  late final GeneratedColumn<int> updatedAtUtcMicros = GeneratedColumn<int>(
    'updated_at_utc_micros',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _revisionMeta = const VerificationMeta(
    'revision',
  );
  @override
  late final GeneratedColumn<int> revision = GeneratedColumn<int>(
    'revision',
    aliasedName,
    false,
    check: () => const CustomExpression<bool>('revision >= 0'),
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    legalLabel,
    status,
    createdAtUtcMicros,
    updatedAtUtcMicros,
    revision,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'employments';
  @override
  VerificationContext validateIntegrity(
    Insertable<Employment> instance, {
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
    if (data.containsKey('legal_label')) {
      context.handle(
        _legalLabelMeta,
        legalLabel.isAcceptableOrUnknown(data['legal_label']!, _legalLabelMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('created_at_utc_micros')) {
      context.handle(
        _createdAtUtcMicrosMeta,
        createdAtUtcMicros.isAcceptableOrUnknown(
          data['created_at_utc_micros']!,
          _createdAtUtcMicrosMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtUtcMicrosMeta);
    }
    if (data.containsKey('updated_at_utc_micros')) {
      context.handle(
        _updatedAtUtcMicrosMeta,
        updatedAtUtcMicros.isAcceptableOrUnknown(
          data['updated_at_utc_micros']!,
          _updatedAtUtcMicrosMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_updatedAtUtcMicrosMeta);
    }
    if (data.containsKey('revision')) {
      context.handle(
        _revisionMeta,
        revision.isAcceptableOrUnknown(data['revision']!, _revisionMeta),
      );
    } else if (isInserting) {
      context.missing(_revisionMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Employment map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Employment(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      legalLabel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}legal_label'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      createdAtUtcMicros: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at_utc_micros'],
      )!,
      updatedAtUtcMicros: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at_utc_micros'],
      )!,
      revision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}revision'],
      )!,
    );
  }

  @override
  $EmploymentsTable createAlias(String alias) {
    return $EmploymentsTable(attachedDatabase, alias);
  }
}

class Employment extends DataClass implements Insertable<Employment> {
  final String id;
  final String name;
  final String? legalLabel;
  final String status;
  final int createdAtUtcMicros;
  final int updatedAtUtcMicros;
  final int revision;
  const Employment({
    required this.id,
    required this.name,
    this.legalLabel,
    required this.status,
    required this.createdAtUtcMicros,
    required this.updatedAtUtcMicros,
    required this.revision,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || legalLabel != null) {
      map['legal_label'] = Variable<String>(legalLabel);
    }
    map['status'] = Variable<String>(status);
    map['created_at_utc_micros'] = Variable<int>(createdAtUtcMicros);
    map['updated_at_utc_micros'] = Variable<int>(updatedAtUtcMicros);
    map['revision'] = Variable<int>(revision);
    return map;
  }

  EmploymentsCompanion toCompanion(bool nullToAbsent) {
    return EmploymentsCompanion(
      id: Value(id),
      name: Value(name),
      legalLabel: legalLabel == null && nullToAbsent
          ? const Value.absent()
          : Value(legalLabel),
      status: Value(status),
      createdAtUtcMicros: Value(createdAtUtcMicros),
      updatedAtUtcMicros: Value(updatedAtUtcMicros),
      revision: Value(revision),
    );
  }

  factory Employment.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Employment(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      legalLabel: serializer.fromJson<String?>(json['legalLabel']),
      status: serializer.fromJson<String>(json['status']),
      createdAtUtcMicros: serializer.fromJson<int>(json['createdAtUtcMicros']),
      updatedAtUtcMicros: serializer.fromJson<int>(json['updatedAtUtcMicros']),
      revision: serializer.fromJson<int>(json['revision']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'legalLabel': serializer.toJson<String?>(legalLabel),
      'status': serializer.toJson<String>(status),
      'createdAtUtcMicros': serializer.toJson<int>(createdAtUtcMicros),
      'updatedAtUtcMicros': serializer.toJson<int>(updatedAtUtcMicros),
      'revision': serializer.toJson<int>(revision),
    };
  }

  Employment copyWith({
    String? id,
    String? name,
    Value<String?> legalLabel = const Value.absent(),
    String? status,
    int? createdAtUtcMicros,
    int? updatedAtUtcMicros,
    int? revision,
  }) => Employment(
    id: id ?? this.id,
    name: name ?? this.name,
    legalLabel: legalLabel.present ? legalLabel.value : this.legalLabel,
    status: status ?? this.status,
    createdAtUtcMicros: createdAtUtcMicros ?? this.createdAtUtcMicros,
    updatedAtUtcMicros: updatedAtUtcMicros ?? this.updatedAtUtcMicros,
    revision: revision ?? this.revision,
  );
  Employment copyWithCompanion(EmploymentsCompanion data) {
    return Employment(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      legalLabel: data.legalLabel.present
          ? data.legalLabel.value
          : this.legalLabel,
      status: data.status.present ? data.status.value : this.status,
      createdAtUtcMicros: data.createdAtUtcMicros.present
          ? data.createdAtUtcMicros.value
          : this.createdAtUtcMicros,
      updatedAtUtcMicros: data.updatedAtUtcMicros.present
          ? data.updatedAtUtcMicros.value
          : this.updatedAtUtcMicros,
      revision: data.revision.present ? data.revision.value : this.revision,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Employment(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('legalLabel: $legalLabel, ')
          ..write('status: $status, ')
          ..write('createdAtUtcMicros: $createdAtUtcMicros, ')
          ..write('updatedAtUtcMicros: $updatedAtUtcMicros, ')
          ..write('revision: $revision')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    legalLabel,
    status,
    createdAtUtcMicros,
    updatedAtUtcMicros,
    revision,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Employment &&
          other.id == this.id &&
          other.name == this.name &&
          other.legalLabel == this.legalLabel &&
          other.status == this.status &&
          other.createdAtUtcMicros == this.createdAtUtcMicros &&
          other.updatedAtUtcMicros == this.updatedAtUtcMicros &&
          other.revision == this.revision);
}

class EmploymentsCompanion extends UpdateCompanion<Employment> {
  final Value<String> id;
  final Value<String> name;
  final Value<String?> legalLabel;
  final Value<String> status;
  final Value<int> createdAtUtcMicros;
  final Value<int> updatedAtUtcMicros;
  final Value<int> revision;
  final Value<int> rowid;
  const EmploymentsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.legalLabel = const Value.absent(),
    this.status = const Value.absent(),
    this.createdAtUtcMicros = const Value.absent(),
    this.updatedAtUtcMicros = const Value.absent(),
    this.revision = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  EmploymentsCompanion.insert({
    required String id,
    required String name,
    this.legalLabel = const Value.absent(),
    required String status,
    required int createdAtUtcMicros,
    required int updatedAtUtcMicros,
    required int revision,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       status = Value(status),
       createdAtUtcMicros = Value(createdAtUtcMicros),
       updatedAtUtcMicros = Value(updatedAtUtcMicros),
       revision = Value(revision);
  static Insertable<Employment> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? legalLabel,
    Expression<String>? status,
    Expression<int>? createdAtUtcMicros,
    Expression<int>? updatedAtUtcMicros,
    Expression<int>? revision,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (legalLabel != null) 'legal_label': legalLabel,
      if (status != null) 'status': status,
      if (createdAtUtcMicros != null)
        'created_at_utc_micros': createdAtUtcMicros,
      if (updatedAtUtcMicros != null)
        'updated_at_utc_micros': updatedAtUtcMicros,
      if (revision != null) 'revision': revision,
      if (rowid != null) 'rowid': rowid,
    });
  }

  EmploymentsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String?>? legalLabel,
    Value<String>? status,
    Value<int>? createdAtUtcMicros,
    Value<int>? updatedAtUtcMicros,
    Value<int>? revision,
    Value<int>? rowid,
  }) {
    return EmploymentsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      legalLabel: legalLabel ?? this.legalLabel,
      status: status ?? this.status,
      createdAtUtcMicros: createdAtUtcMicros ?? this.createdAtUtcMicros,
      updatedAtUtcMicros: updatedAtUtcMicros ?? this.updatedAtUtcMicros,
      revision: revision ?? this.revision,
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
    if (legalLabel.present) {
      map['legal_label'] = Variable<String>(legalLabel.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (createdAtUtcMicros.present) {
      map['created_at_utc_micros'] = Variable<int>(createdAtUtcMicros.value);
    }
    if (updatedAtUtcMicros.present) {
      map['updated_at_utc_micros'] = Variable<int>(updatedAtUtcMicros.value);
    }
    if (revision.present) {
      map['revision'] = Variable<int>(revision.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EmploymentsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('legalLabel: $legalLabel, ')
          ..write('status: $status, ')
          ..write('createdAtUtcMicros: $createdAtUtcMicros, ')
          ..write('updatedAtUtcMicros: $updatedAtUtcMicros, ')
          ..write('revision: $revision, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PayAgreementsTable extends PayAgreements
    with TableInfo<$PayAgreementsTable, PayAgreement> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PayAgreementsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _employmentIdMeta = const VerificationMeta(
    'employmentId',
  );
  @override
  late final GeneratedColumn<String> employmentId = GeneratedColumn<String>(
    'employment_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES employments (id) ON DELETE RESTRICT',
    ),
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    check: () => const CustomExpression<bool>('version > 0'),
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _effectiveStartMeta = const VerificationMeta(
    'effectiveStart',
  );
  @override
  late final GeneratedColumn<String> effectiveStart = GeneratedColumn<String>(
    'effective_start',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _effectiveEndMeta = const VerificationMeta(
    'effectiveEnd',
  );
  @override
  late final GeneratedColumn<String> effectiveEnd = GeneratedColumn<String>(
    'effective_end',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _hourlyRateMicroEurMeta =
      const VerificationMeta('hourlyRateMicroEur');
  @override
  late final GeneratedColumn<int> hourlyRateMicroEur = GeneratedColumn<int>(
    'hourly_rate_micro_eur',
    aliasedName,
    false,
    check: () => const CustomExpression<bool>('hourly_rate_micro_eur > 0'),
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _basisMeta = const VerificationMeta('basis');
  @override
  late final GeneratedColumn<String> basis = GeneratedColumn<String>(
    'basis',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _overtimeThresholdMinutesMeta =
      const VerificationMeta('overtimeThresholdMinutes');
  @override
  late final GeneratedColumn<int> overtimeThresholdMinutes =
      GeneratedColumn<int>(
        'overtime_threshold_minutes',
        aliasedName,
        false,
        check: () =>
            const CustomExpression<bool>('overtime_threshold_minutes > 0'),
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _overtimeMultiplierNumeratorMeta =
      const VerificationMeta('overtimeMultiplierNumerator');
  @override
  late final GeneratedColumn<int> overtimeMultiplierNumerator =
      GeneratedColumn<int>(
        'overtime_multiplier_numerator',
        aliasedName,
        false,
        check: () =>
            const CustomExpression<bool>('overtime_multiplier_numerator > 0'),
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _overtimeMultiplierDenominatorMeta =
      const VerificationMeta('overtimeMultiplierDenominator');
  @override
  late final GeneratedColumn<int> overtimeMultiplierDenominator =
      GeneratedColumn<int>(
        'overtime_multiplier_denominator',
        aliasedName,
        false,
        check: () =>
            const CustomExpression<bool>('overtime_multiplier_denominator > 0'),
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _labelMeta = const VerificationMeta('label');
  @override
  late final GeneratedColumn<String> label = GeneratedColumn<String>(
    'label',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtUtcMicrosMeta =
      const VerificationMeta('createdAtUtcMicros');
  @override
  late final GeneratedColumn<int> createdAtUtcMicros = GeneratedColumn<int>(
    'created_at_utc_micros',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _revisionMeta = const VerificationMeta(
    'revision',
  );
  @override
  late final GeneratedColumn<int> revision = GeneratedColumn<int>(
    'revision',
    aliasedName,
    false,
    check: () => const CustomExpression<bool>('revision >= 0'),
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    employmentId,
    version,
    effectiveStart,
    effectiveEnd,
    hourlyRateMicroEur,
    basis,
    overtimeThresholdMinutes,
    overtimeMultiplierNumerator,
    overtimeMultiplierDenominator,
    label,
    note,
    createdAtUtcMicros,
    revision,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pay_agreements';
  @override
  VerificationContext validateIntegrity(
    Insertable<PayAgreement> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('employment_id')) {
      context.handle(
        _employmentIdMeta,
        employmentId.isAcceptableOrUnknown(
          data['employment_id']!,
          _employmentIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_employmentIdMeta);
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    } else if (isInserting) {
      context.missing(_versionMeta);
    }
    if (data.containsKey('effective_start')) {
      context.handle(
        _effectiveStartMeta,
        effectiveStart.isAcceptableOrUnknown(
          data['effective_start']!,
          _effectiveStartMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_effectiveStartMeta);
    }
    if (data.containsKey('effective_end')) {
      context.handle(
        _effectiveEndMeta,
        effectiveEnd.isAcceptableOrUnknown(
          data['effective_end']!,
          _effectiveEndMeta,
        ),
      );
    }
    if (data.containsKey('hourly_rate_micro_eur')) {
      context.handle(
        _hourlyRateMicroEurMeta,
        hourlyRateMicroEur.isAcceptableOrUnknown(
          data['hourly_rate_micro_eur']!,
          _hourlyRateMicroEurMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_hourlyRateMicroEurMeta);
    }
    if (data.containsKey('basis')) {
      context.handle(
        _basisMeta,
        basis.isAcceptableOrUnknown(data['basis']!, _basisMeta),
      );
    } else if (isInserting) {
      context.missing(_basisMeta);
    }
    if (data.containsKey('overtime_threshold_minutes')) {
      context.handle(
        _overtimeThresholdMinutesMeta,
        overtimeThresholdMinutes.isAcceptableOrUnknown(
          data['overtime_threshold_minutes']!,
          _overtimeThresholdMinutesMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_overtimeThresholdMinutesMeta);
    }
    if (data.containsKey('overtime_multiplier_numerator')) {
      context.handle(
        _overtimeMultiplierNumeratorMeta,
        overtimeMultiplierNumerator.isAcceptableOrUnknown(
          data['overtime_multiplier_numerator']!,
          _overtimeMultiplierNumeratorMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_overtimeMultiplierNumeratorMeta);
    }
    if (data.containsKey('overtime_multiplier_denominator')) {
      context.handle(
        _overtimeMultiplierDenominatorMeta,
        overtimeMultiplierDenominator.isAcceptableOrUnknown(
          data['overtime_multiplier_denominator']!,
          _overtimeMultiplierDenominatorMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_overtimeMultiplierDenominatorMeta);
    }
    if (data.containsKey('label')) {
      context.handle(
        _labelMeta,
        label.isAcceptableOrUnknown(data['label']!, _labelMeta),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('created_at_utc_micros')) {
      context.handle(
        _createdAtUtcMicrosMeta,
        createdAtUtcMicros.isAcceptableOrUnknown(
          data['created_at_utc_micros']!,
          _createdAtUtcMicrosMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtUtcMicrosMeta);
    }
    if (data.containsKey('revision')) {
      context.handle(
        _revisionMeta,
        revision.isAcceptableOrUnknown(data['revision']!, _revisionMeta),
      );
    } else if (isInserting) {
      context.missing(_revisionMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PayAgreement map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PayAgreement(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      employmentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}employment_id'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
      effectiveStart: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}effective_start'],
      )!,
      effectiveEnd: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}effective_end'],
      ),
      hourlyRateMicroEur: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}hourly_rate_micro_eur'],
      )!,
      basis: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}basis'],
      )!,
      overtimeThresholdMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}overtime_threshold_minutes'],
      )!,
      overtimeMultiplierNumerator: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}overtime_multiplier_numerator'],
      )!,
      overtimeMultiplierDenominator: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}overtime_multiplier_denominator'],
      )!,
      label: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}label'],
      ),
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      createdAtUtcMicros: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at_utc_micros'],
      )!,
      revision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}revision'],
      )!,
    );
  }

  @override
  $PayAgreementsTable createAlias(String alias) {
    return $PayAgreementsTable(attachedDatabase, alias);
  }
}

class PayAgreement extends DataClass implements Insertable<PayAgreement> {
  final String id;
  final String employmentId;
  final int version;
  final String effectiveStart;
  final String? effectiveEnd;
  final int hourlyRateMicroEur;
  final String basis;
  final int overtimeThresholdMinutes;
  final int overtimeMultiplierNumerator;
  final int overtimeMultiplierDenominator;
  final String? label;
  final String? note;
  final int createdAtUtcMicros;
  final int revision;
  const PayAgreement({
    required this.id,
    required this.employmentId,
    required this.version,
    required this.effectiveStart,
    this.effectiveEnd,
    required this.hourlyRateMicroEur,
    required this.basis,
    required this.overtimeThresholdMinutes,
    required this.overtimeMultiplierNumerator,
    required this.overtimeMultiplierDenominator,
    this.label,
    this.note,
    required this.createdAtUtcMicros,
    required this.revision,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['employment_id'] = Variable<String>(employmentId);
    map['version'] = Variable<int>(version);
    map['effective_start'] = Variable<String>(effectiveStart);
    if (!nullToAbsent || effectiveEnd != null) {
      map['effective_end'] = Variable<String>(effectiveEnd);
    }
    map['hourly_rate_micro_eur'] = Variable<int>(hourlyRateMicroEur);
    map['basis'] = Variable<String>(basis);
    map['overtime_threshold_minutes'] = Variable<int>(overtimeThresholdMinutes);
    map['overtime_multiplier_numerator'] = Variable<int>(
      overtimeMultiplierNumerator,
    );
    map['overtime_multiplier_denominator'] = Variable<int>(
      overtimeMultiplierDenominator,
    );
    if (!nullToAbsent || label != null) {
      map['label'] = Variable<String>(label);
    }
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    map['created_at_utc_micros'] = Variable<int>(createdAtUtcMicros);
    map['revision'] = Variable<int>(revision);
    return map;
  }

  PayAgreementsCompanion toCompanion(bool nullToAbsent) {
    return PayAgreementsCompanion(
      id: Value(id),
      employmentId: Value(employmentId),
      version: Value(version),
      effectiveStart: Value(effectiveStart),
      effectiveEnd: effectiveEnd == null && nullToAbsent
          ? const Value.absent()
          : Value(effectiveEnd),
      hourlyRateMicroEur: Value(hourlyRateMicroEur),
      basis: Value(basis),
      overtimeThresholdMinutes: Value(overtimeThresholdMinutes),
      overtimeMultiplierNumerator: Value(overtimeMultiplierNumerator),
      overtimeMultiplierDenominator: Value(overtimeMultiplierDenominator),
      label: label == null && nullToAbsent
          ? const Value.absent()
          : Value(label),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      createdAtUtcMicros: Value(createdAtUtcMicros),
      revision: Value(revision),
    );
  }

  factory PayAgreement.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PayAgreement(
      id: serializer.fromJson<String>(json['id']),
      employmentId: serializer.fromJson<String>(json['employmentId']),
      version: serializer.fromJson<int>(json['version']),
      effectiveStart: serializer.fromJson<String>(json['effectiveStart']),
      effectiveEnd: serializer.fromJson<String?>(json['effectiveEnd']),
      hourlyRateMicroEur: serializer.fromJson<int>(json['hourlyRateMicroEur']),
      basis: serializer.fromJson<String>(json['basis']),
      overtimeThresholdMinutes: serializer.fromJson<int>(
        json['overtimeThresholdMinutes'],
      ),
      overtimeMultiplierNumerator: serializer.fromJson<int>(
        json['overtimeMultiplierNumerator'],
      ),
      overtimeMultiplierDenominator: serializer.fromJson<int>(
        json['overtimeMultiplierDenominator'],
      ),
      label: serializer.fromJson<String?>(json['label']),
      note: serializer.fromJson<String?>(json['note']),
      createdAtUtcMicros: serializer.fromJson<int>(json['createdAtUtcMicros']),
      revision: serializer.fromJson<int>(json['revision']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'employmentId': serializer.toJson<String>(employmentId),
      'version': serializer.toJson<int>(version),
      'effectiveStart': serializer.toJson<String>(effectiveStart),
      'effectiveEnd': serializer.toJson<String?>(effectiveEnd),
      'hourlyRateMicroEur': serializer.toJson<int>(hourlyRateMicroEur),
      'basis': serializer.toJson<String>(basis),
      'overtimeThresholdMinutes': serializer.toJson<int>(
        overtimeThresholdMinutes,
      ),
      'overtimeMultiplierNumerator': serializer.toJson<int>(
        overtimeMultiplierNumerator,
      ),
      'overtimeMultiplierDenominator': serializer.toJson<int>(
        overtimeMultiplierDenominator,
      ),
      'label': serializer.toJson<String?>(label),
      'note': serializer.toJson<String?>(note),
      'createdAtUtcMicros': serializer.toJson<int>(createdAtUtcMicros),
      'revision': serializer.toJson<int>(revision),
    };
  }

  PayAgreement copyWith({
    String? id,
    String? employmentId,
    int? version,
    String? effectiveStart,
    Value<String?> effectiveEnd = const Value.absent(),
    int? hourlyRateMicroEur,
    String? basis,
    int? overtimeThresholdMinutes,
    int? overtimeMultiplierNumerator,
    int? overtimeMultiplierDenominator,
    Value<String?> label = const Value.absent(),
    Value<String?> note = const Value.absent(),
    int? createdAtUtcMicros,
    int? revision,
  }) => PayAgreement(
    id: id ?? this.id,
    employmentId: employmentId ?? this.employmentId,
    version: version ?? this.version,
    effectiveStart: effectiveStart ?? this.effectiveStart,
    effectiveEnd: effectiveEnd.present ? effectiveEnd.value : this.effectiveEnd,
    hourlyRateMicroEur: hourlyRateMicroEur ?? this.hourlyRateMicroEur,
    basis: basis ?? this.basis,
    overtimeThresholdMinutes:
        overtimeThresholdMinutes ?? this.overtimeThresholdMinutes,
    overtimeMultiplierNumerator:
        overtimeMultiplierNumerator ?? this.overtimeMultiplierNumerator,
    overtimeMultiplierDenominator:
        overtimeMultiplierDenominator ?? this.overtimeMultiplierDenominator,
    label: label.present ? label.value : this.label,
    note: note.present ? note.value : this.note,
    createdAtUtcMicros: createdAtUtcMicros ?? this.createdAtUtcMicros,
    revision: revision ?? this.revision,
  );
  PayAgreement copyWithCompanion(PayAgreementsCompanion data) {
    return PayAgreement(
      id: data.id.present ? data.id.value : this.id,
      employmentId: data.employmentId.present
          ? data.employmentId.value
          : this.employmentId,
      version: data.version.present ? data.version.value : this.version,
      effectiveStart: data.effectiveStart.present
          ? data.effectiveStart.value
          : this.effectiveStart,
      effectiveEnd: data.effectiveEnd.present
          ? data.effectiveEnd.value
          : this.effectiveEnd,
      hourlyRateMicroEur: data.hourlyRateMicroEur.present
          ? data.hourlyRateMicroEur.value
          : this.hourlyRateMicroEur,
      basis: data.basis.present ? data.basis.value : this.basis,
      overtimeThresholdMinutes: data.overtimeThresholdMinutes.present
          ? data.overtimeThresholdMinutes.value
          : this.overtimeThresholdMinutes,
      overtimeMultiplierNumerator: data.overtimeMultiplierNumerator.present
          ? data.overtimeMultiplierNumerator.value
          : this.overtimeMultiplierNumerator,
      overtimeMultiplierDenominator: data.overtimeMultiplierDenominator.present
          ? data.overtimeMultiplierDenominator.value
          : this.overtimeMultiplierDenominator,
      label: data.label.present ? data.label.value : this.label,
      note: data.note.present ? data.note.value : this.note,
      createdAtUtcMicros: data.createdAtUtcMicros.present
          ? data.createdAtUtcMicros.value
          : this.createdAtUtcMicros,
      revision: data.revision.present ? data.revision.value : this.revision,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PayAgreement(')
          ..write('id: $id, ')
          ..write('employmentId: $employmentId, ')
          ..write('version: $version, ')
          ..write('effectiveStart: $effectiveStart, ')
          ..write('effectiveEnd: $effectiveEnd, ')
          ..write('hourlyRateMicroEur: $hourlyRateMicroEur, ')
          ..write('basis: $basis, ')
          ..write('overtimeThresholdMinutes: $overtimeThresholdMinutes, ')
          ..write('overtimeMultiplierNumerator: $overtimeMultiplierNumerator, ')
          ..write(
            'overtimeMultiplierDenominator: $overtimeMultiplierDenominator, ',
          )
          ..write('label: $label, ')
          ..write('note: $note, ')
          ..write('createdAtUtcMicros: $createdAtUtcMicros, ')
          ..write('revision: $revision')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    employmentId,
    version,
    effectiveStart,
    effectiveEnd,
    hourlyRateMicroEur,
    basis,
    overtimeThresholdMinutes,
    overtimeMultiplierNumerator,
    overtimeMultiplierDenominator,
    label,
    note,
    createdAtUtcMicros,
    revision,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PayAgreement &&
          other.id == this.id &&
          other.employmentId == this.employmentId &&
          other.version == this.version &&
          other.effectiveStart == this.effectiveStart &&
          other.effectiveEnd == this.effectiveEnd &&
          other.hourlyRateMicroEur == this.hourlyRateMicroEur &&
          other.basis == this.basis &&
          other.overtimeThresholdMinutes == this.overtimeThresholdMinutes &&
          other.overtimeMultiplierNumerator ==
              this.overtimeMultiplierNumerator &&
          other.overtimeMultiplierDenominator ==
              this.overtimeMultiplierDenominator &&
          other.label == this.label &&
          other.note == this.note &&
          other.createdAtUtcMicros == this.createdAtUtcMicros &&
          other.revision == this.revision);
}

class PayAgreementsCompanion extends UpdateCompanion<PayAgreement> {
  final Value<String> id;
  final Value<String> employmentId;
  final Value<int> version;
  final Value<String> effectiveStart;
  final Value<String?> effectiveEnd;
  final Value<int> hourlyRateMicroEur;
  final Value<String> basis;
  final Value<int> overtimeThresholdMinutes;
  final Value<int> overtimeMultiplierNumerator;
  final Value<int> overtimeMultiplierDenominator;
  final Value<String?> label;
  final Value<String?> note;
  final Value<int> createdAtUtcMicros;
  final Value<int> revision;
  final Value<int> rowid;
  const PayAgreementsCompanion({
    this.id = const Value.absent(),
    this.employmentId = const Value.absent(),
    this.version = const Value.absent(),
    this.effectiveStart = const Value.absent(),
    this.effectiveEnd = const Value.absent(),
    this.hourlyRateMicroEur = const Value.absent(),
    this.basis = const Value.absent(),
    this.overtimeThresholdMinutes = const Value.absent(),
    this.overtimeMultiplierNumerator = const Value.absent(),
    this.overtimeMultiplierDenominator = const Value.absent(),
    this.label = const Value.absent(),
    this.note = const Value.absent(),
    this.createdAtUtcMicros = const Value.absent(),
    this.revision = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PayAgreementsCompanion.insert({
    required String id,
    required String employmentId,
    required int version,
    required String effectiveStart,
    this.effectiveEnd = const Value.absent(),
    required int hourlyRateMicroEur,
    required String basis,
    required int overtimeThresholdMinutes,
    required int overtimeMultiplierNumerator,
    required int overtimeMultiplierDenominator,
    this.label = const Value.absent(),
    this.note = const Value.absent(),
    required int createdAtUtcMicros,
    required int revision,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       employmentId = Value(employmentId),
       version = Value(version),
       effectiveStart = Value(effectiveStart),
       hourlyRateMicroEur = Value(hourlyRateMicroEur),
       basis = Value(basis),
       overtimeThresholdMinutes = Value(overtimeThresholdMinutes),
       overtimeMultiplierNumerator = Value(overtimeMultiplierNumerator),
       overtimeMultiplierDenominator = Value(overtimeMultiplierDenominator),
       createdAtUtcMicros = Value(createdAtUtcMicros),
       revision = Value(revision);
  static Insertable<PayAgreement> custom({
    Expression<String>? id,
    Expression<String>? employmentId,
    Expression<int>? version,
    Expression<String>? effectiveStart,
    Expression<String>? effectiveEnd,
    Expression<int>? hourlyRateMicroEur,
    Expression<String>? basis,
    Expression<int>? overtimeThresholdMinutes,
    Expression<int>? overtimeMultiplierNumerator,
    Expression<int>? overtimeMultiplierDenominator,
    Expression<String>? label,
    Expression<String>? note,
    Expression<int>? createdAtUtcMicros,
    Expression<int>? revision,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (employmentId != null) 'employment_id': employmentId,
      if (version != null) 'version': version,
      if (effectiveStart != null) 'effective_start': effectiveStart,
      if (effectiveEnd != null) 'effective_end': effectiveEnd,
      if (hourlyRateMicroEur != null)
        'hourly_rate_micro_eur': hourlyRateMicroEur,
      if (basis != null) 'basis': basis,
      if (overtimeThresholdMinutes != null)
        'overtime_threshold_minutes': overtimeThresholdMinutes,
      if (overtimeMultiplierNumerator != null)
        'overtime_multiplier_numerator': overtimeMultiplierNumerator,
      if (overtimeMultiplierDenominator != null)
        'overtime_multiplier_denominator': overtimeMultiplierDenominator,
      if (label != null) 'label': label,
      if (note != null) 'note': note,
      if (createdAtUtcMicros != null)
        'created_at_utc_micros': createdAtUtcMicros,
      if (revision != null) 'revision': revision,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PayAgreementsCompanion copyWith({
    Value<String>? id,
    Value<String>? employmentId,
    Value<int>? version,
    Value<String>? effectiveStart,
    Value<String?>? effectiveEnd,
    Value<int>? hourlyRateMicroEur,
    Value<String>? basis,
    Value<int>? overtimeThresholdMinutes,
    Value<int>? overtimeMultiplierNumerator,
    Value<int>? overtimeMultiplierDenominator,
    Value<String?>? label,
    Value<String?>? note,
    Value<int>? createdAtUtcMicros,
    Value<int>? revision,
    Value<int>? rowid,
  }) {
    return PayAgreementsCompanion(
      id: id ?? this.id,
      employmentId: employmentId ?? this.employmentId,
      version: version ?? this.version,
      effectiveStart: effectiveStart ?? this.effectiveStart,
      effectiveEnd: effectiveEnd ?? this.effectiveEnd,
      hourlyRateMicroEur: hourlyRateMicroEur ?? this.hourlyRateMicroEur,
      basis: basis ?? this.basis,
      overtimeThresholdMinutes:
          overtimeThresholdMinutes ?? this.overtimeThresholdMinutes,
      overtimeMultiplierNumerator:
          overtimeMultiplierNumerator ?? this.overtimeMultiplierNumerator,
      overtimeMultiplierDenominator:
          overtimeMultiplierDenominator ?? this.overtimeMultiplierDenominator,
      label: label ?? this.label,
      note: note ?? this.note,
      createdAtUtcMicros: createdAtUtcMicros ?? this.createdAtUtcMicros,
      revision: revision ?? this.revision,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (employmentId.present) {
      map['employment_id'] = Variable<String>(employmentId.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (effectiveStart.present) {
      map['effective_start'] = Variable<String>(effectiveStart.value);
    }
    if (effectiveEnd.present) {
      map['effective_end'] = Variable<String>(effectiveEnd.value);
    }
    if (hourlyRateMicroEur.present) {
      map['hourly_rate_micro_eur'] = Variable<int>(hourlyRateMicroEur.value);
    }
    if (basis.present) {
      map['basis'] = Variable<String>(basis.value);
    }
    if (overtimeThresholdMinutes.present) {
      map['overtime_threshold_minutes'] = Variable<int>(
        overtimeThresholdMinutes.value,
      );
    }
    if (overtimeMultiplierNumerator.present) {
      map['overtime_multiplier_numerator'] = Variable<int>(
        overtimeMultiplierNumerator.value,
      );
    }
    if (overtimeMultiplierDenominator.present) {
      map['overtime_multiplier_denominator'] = Variable<int>(
        overtimeMultiplierDenominator.value,
      );
    }
    if (label.present) {
      map['label'] = Variable<String>(label.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (createdAtUtcMicros.present) {
      map['created_at_utc_micros'] = Variable<int>(createdAtUtcMicros.value);
    }
    if (revision.present) {
      map['revision'] = Variable<int>(revision.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PayAgreementsCompanion(')
          ..write('id: $id, ')
          ..write('employmentId: $employmentId, ')
          ..write('version: $version, ')
          ..write('effectiveStart: $effectiveStart, ')
          ..write('effectiveEnd: $effectiveEnd, ')
          ..write('hourlyRateMicroEur: $hourlyRateMicroEur, ')
          ..write('basis: $basis, ')
          ..write('overtimeThresholdMinutes: $overtimeThresholdMinutes, ')
          ..write('overtimeMultiplierNumerator: $overtimeMultiplierNumerator, ')
          ..write(
            'overtimeMultiplierDenominator: $overtimeMultiplierDenominator, ',
          )
          ..write('label: $label, ')
          ..write('note: $note, ')
          ..write('createdAtUtcMicros: $createdAtUtcMicros, ')
          ..write('revision: $revision, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $WorkShiftsTable extends WorkShifts
    with TableInfo<$WorkShiftsTable, WorkShift> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WorkShiftsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _employmentIdMeta = const VerificationMeta(
    'employmentId',
  );
  @override
  late final GeneratedColumn<String> employmentId = GeneratedColumn<String>(
    'employment_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES employments (id) ON DELETE RESTRICT',
    ),
  );
  static const VerificationMeta _agreementIdMeta = const VerificationMeta(
    'agreementId',
  );
  @override
  late final GeneratedColumn<String> agreementId = GeneratedColumn<String>(
    'agreement_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES pay_agreements (id) ON DELETE RESTRICT',
    ),
  );
  static const VerificationMeta _stateMeta = const VerificationMeta('state');
  @override
  late final GeneratedColumn<String> state = GeneratedColumn<String>(
    'state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startUtcMicrosMeta = const VerificationMeta(
    'startUtcMicros',
  );
  @override
  late final GeneratedColumn<int> startUtcMicros = GeneratedColumn<int>(
    'start_utc_micros',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endUtcMicrosMeta = const VerificationMeta(
    'endUtcMicros',
  );
  @override
  late final GeneratedColumn<int> endUtcMicros = GeneratedColumn<int>(
    'end_utc_micros',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _timezoneIdMeta = const VerificationMeta(
    'timezoneId',
  );
  @override
  late final GeneratedColumn<String> timezoneId = GeneratedColumn<String>(
    'timezone_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _localStartDateMeta = const VerificationMeta(
    'localStartDate',
  );
  @override
  late final GeneratedColumn<String> localStartDate = GeneratedColumn<String>(
    'local_start_date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _overtimeMinutesMeta = const VerificationMeta(
    'overtimeMinutes',
  );
  @override
  late final GeneratedColumn<int> overtimeMinutes = GeneratedColumn<int>(
    'overtime_minutes',
    aliasedName,
    false,
    check: () => const CustomExpression<bool>('overtime_minutes >= 0'),
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _voidReasonMeta = const VerificationMeta(
    'voidReason',
  );
  @override
  late final GeneratedColumn<String> voidReason = GeneratedColumn<String>(
    'void_reason',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _replacementShiftIdMeta =
      const VerificationMeta('replacementShiftId');
  @override
  late final GeneratedColumn<String> replacementShiftId =
      GeneratedColumn<String>(
        'replacement_shift_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES work_shifts (id) ON DELETE RESTRICT',
        ),
      );
  static const VerificationMeta _replacedShiftIdMeta = const VerificationMeta(
    'replacedShiftId',
  );
  @override
  late final GeneratedColumn<String> replacedShiftId = GeneratedColumn<String>(
    'replaced_shift_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES work_shifts (id) ON DELETE RESTRICT',
    ),
  );
  static const VerificationMeta _createdAtUtcMicrosMeta =
      const VerificationMeta('createdAtUtcMicros');
  @override
  late final GeneratedColumn<int> createdAtUtcMicros = GeneratedColumn<int>(
    'created_at_utc_micros',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtUtcMicrosMeta =
      const VerificationMeta('updatedAtUtcMicros');
  @override
  late final GeneratedColumn<int> updatedAtUtcMicros = GeneratedColumn<int>(
    'updated_at_utc_micros',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _revisionMeta = const VerificationMeta(
    'revision',
  );
  @override
  late final GeneratedColumn<int> revision = GeneratedColumn<int>(
    'revision',
    aliasedName,
    false,
    check: () => const CustomExpression<bool>('revision >= 0'),
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    employmentId,
    agreementId,
    state,
    startUtcMicros,
    endUtcMicros,
    timezoneId,
    localStartDate,
    overtimeMinutes,
    note,
    voidReason,
    replacementShiftId,
    replacedShiftId,
    createdAtUtcMicros,
    updatedAtUtcMicros,
    revision,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'work_shifts';
  @override
  VerificationContext validateIntegrity(
    Insertable<WorkShift> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('employment_id')) {
      context.handle(
        _employmentIdMeta,
        employmentId.isAcceptableOrUnknown(
          data['employment_id']!,
          _employmentIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_employmentIdMeta);
    }
    if (data.containsKey('agreement_id')) {
      context.handle(
        _agreementIdMeta,
        agreementId.isAcceptableOrUnknown(
          data['agreement_id']!,
          _agreementIdMeta,
        ),
      );
    }
    if (data.containsKey('state')) {
      context.handle(
        _stateMeta,
        state.isAcceptableOrUnknown(data['state']!, _stateMeta),
      );
    } else if (isInserting) {
      context.missing(_stateMeta);
    }
    if (data.containsKey('start_utc_micros')) {
      context.handle(
        _startUtcMicrosMeta,
        startUtcMicros.isAcceptableOrUnknown(
          data['start_utc_micros']!,
          _startUtcMicrosMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_startUtcMicrosMeta);
    }
    if (data.containsKey('end_utc_micros')) {
      context.handle(
        _endUtcMicrosMeta,
        endUtcMicros.isAcceptableOrUnknown(
          data['end_utc_micros']!,
          _endUtcMicrosMeta,
        ),
      );
    }
    if (data.containsKey('timezone_id')) {
      context.handle(
        _timezoneIdMeta,
        timezoneId.isAcceptableOrUnknown(data['timezone_id']!, _timezoneIdMeta),
      );
    } else if (isInserting) {
      context.missing(_timezoneIdMeta);
    }
    if (data.containsKey('local_start_date')) {
      context.handle(
        _localStartDateMeta,
        localStartDate.isAcceptableOrUnknown(
          data['local_start_date']!,
          _localStartDateMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_localStartDateMeta);
    }
    if (data.containsKey('overtime_minutes')) {
      context.handle(
        _overtimeMinutesMeta,
        overtimeMinutes.isAcceptableOrUnknown(
          data['overtime_minutes']!,
          _overtimeMinutesMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_overtimeMinutesMeta);
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('void_reason')) {
      context.handle(
        _voidReasonMeta,
        voidReason.isAcceptableOrUnknown(data['void_reason']!, _voidReasonMeta),
      );
    }
    if (data.containsKey('replacement_shift_id')) {
      context.handle(
        _replacementShiftIdMeta,
        replacementShiftId.isAcceptableOrUnknown(
          data['replacement_shift_id']!,
          _replacementShiftIdMeta,
        ),
      );
    }
    if (data.containsKey('replaced_shift_id')) {
      context.handle(
        _replacedShiftIdMeta,
        replacedShiftId.isAcceptableOrUnknown(
          data['replaced_shift_id']!,
          _replacedShiftIdMeta,
        ),
      );
    }
    if (data.containsKey('created_at_utc_micros')) {
      context.handle(
        _createdAtUtcMicrosMeta,
        createdAtUtcMicros.isAcceptableOrUnknown(
          data['created_at_utc_micros']!,
          _createdAtUtcMicrosMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtUtcMicrosMeta);
    }
    if (data.containsKey('updated_at_utc_micros')) {
      context.handle(
        _updatedAtUtcMicrosMeta,
        updatedAtUtcMicros.isAcceptableOrUnknown(
          data['updated_at_utc_micros']!,
          _updatedAtUtcMicrosMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_updatedAtUtcMicrosMeta);
    }
    if (data.containsKey('revision')) {
      context.handle(
        _revisionMeta,
        revision.isAcceptableOrUnknown(data['revision']!, _revisionMeta),
      );
    } else if (isInserting) {
      context.missing(_revisionMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  WorkShift map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WorkShift(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      employmentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}employment_id'],
      )!,
      agreementId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}agreement_id'],
      ),
      state: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}state'],
      )!,
      startUtcMicros: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}start_utc_micros'],
      )!,
      endUtcMicros: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}end_utc_micros'],
      ),
      timezoneId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}timezone_id'],
      )!,
      localStartDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_start_date'],
      )!,
      overtimeMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}overtime_minutes'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      voidReason: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}void_reason'],
      ),
      replacementShiftId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}replacement_shift_id'],
      ),
      replacedShiftId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}replaced_shift_id'],
      ),
      createdAtUtcMicros: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at_utc_micros'],
      )!,
      updatedAtUtcMicros: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at_utc_micros'],
      )!,
      revision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}revision'],
      )!,
    );
  }

  @override
  $WorkShiftsTable createAlias(String alias) {
    return $WorkShiftsTable(attachedDatabase, alias);
  }
}

class WorkShift extends DataClass implements Insertable<WorkShift> {
  final String id;
  final String employmentId;
  final String? agreementId;
  final String state;
  final int startUtcMicros;
  final int? endUtcMicros;
  final String timezoneId;
  final String localStartDate;
  final int overtimeMinutes;
  final String? note;
  final String? voidReason;
  final String? replacementShiftId;
  final String? replacedShiftId;
  final int createdAtUtcMicros;
  final int updatedAtUtcMicros;
  final int revision;
  const WorkShift({
    required this.id,
    required this.employmentId,
    this.agreementId,
    required this.state,
    required this.startUtcMicros,
    this.endUtcMicros,
    required this.timezoneId,
    required this.localStartDate,
    required this.overtimeMinutes,
    this.note,
    this.voidReason,
    this.replacementShiftId,
    this.replacedShiftId,
    required this.createdAtUtcMicros,
    required this.updatedAtUtcMicros,
    required this.revision,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['employment_id'] = Variable<String>(employmentId);
    if (!nullToAbsent || agreementId != null) {
      map['agreement_id'] = Variable<String>(agreementId);
    }
    map['state'] = Variable<String>(state);
    map['start_utc_micros'] = Variable<int>(startUtcMicros);
    if (!nullToAbsent || endUtcMicros != null) {
      map['end_utc_micros'] = Variable<int>(endUtcMicros);
    }
    map['timezone_id'] = Variable<String>(timezoneId);
    map['local_start_date'] = Variable<String>(localStartDate);
    map['overtime_minutes'] = Variable<int>(overtimeMinutes);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    if (!nullToAbsent || voidReason != null) {
      map['void_reason'] = Variable<String>(voidReason);
    }
    if (!nullToAbsent || replacementShiftId != null) {
      map['replacement_shift_id'] = Variable<String>(replacementShiftId);
    }
    if (!nullToAbsent || replacedShiftId != null) {
      map['replaced_shift_id'] = Variable<String>(replacedShiftId);
    }
    map['created_at_utc_micros'] = Variable<int>(createdAtUtcMicros);
    map['updated_at_utc_micros'] = Variable<int>(updatedAtUtcMicros);
    map['revision'] = Variable<int>(revision);
    return map;
  }

  WorkShiftsCompanion toCompanion(bool nullToAbsent) {
    return WorkShiftsCompanion(
      id: Value(id),
      employmentId: Value(employmentId),
      agreementId: agreementId == null && nullToAbsent
          ? const Value.absent()
          : Value(agreementId),
      state: Value(state),
      startUtcMicros: Value(startUtcMicros),
      endUtcMicros: endUtcMicros == null && nullToAbsent
          ? const Value.absent()
          : Value(endUtcMicros),
      timezoneId: Value(timezoneId),
      localStartDate: Value(localStartDate),
      overtimeMinutes: Value(overtimeMinutes),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      voidReason: voidReason == null && nullToAbsent
          ? const Value.absent()
          : Value(voidReason),
      replacementShiftId: replacementShiftId == null && nullToAbsent
          ? const Value.absent()
          : Value(replacementShiftId),
      replacedShiftId: replacedShiftId == null && nullToAbsent
          ? const Value.absent()
          : Value(replacedShiftId),
      createdAtUtcMicros: Value(createdAtUtcMicros),
      updatedAtUtcMicros: Value(updatedAtUtcMicros),
      revision: Value(revision),
    );
  }

  factory WorkShift.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WorkShift(
      id: serializer.fromJson<String>(json['id']),
      employmentId: serializer.fromJson<String>(json['employmentId']),
      agreementId: serializer.fromJson<String?>(json['agreementId']),
      state: serializer.fromJson<String>(json['state']),
      startUtcMicros: serializer.fromJson<int>(json['startUtcMicros']),
      endUtcMicros: serializer.fromJson<int?>(json['endUtcMicros']),
      timezoneId: serializer.fromJson<String>(json['timezoneId']),
      localStartDate: serializer.fromJson<String>(json['localStartDate']),
      overtimeMinutes: serializer.fromJson<int>(json['overtimeMinutes']),
      note: serializer.fromJson<String?>(json['note']),
      voidReason: serializer.fromJson<String?>(json['voidReason']),
      replacementShiftId: serializer.fromJson<String?>(
        json['replacementShiftId'],
      ),
      replacedShiftId: serializer.fromJson<String?>(json['replacedShiftId']),
      createdAtUtcMicros: serializer.fromJson<int>(json['createdAtUtcMicros']),
      updatedAtUtcMicros: serializer.fromJson<int>(json['updatedAtUtcMicros']),
      revision: serializer.fromJson<int>(json['revision']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'employmentId': serializer.toJson<String>(employmentId),
      'agreementId': serializer.toJson<String?>(agreementId),
      'state': serializer.toJson<String>(state),
      'startUtcMicros': serializer.toJson<int>(startUtcMicros),
      'endUtcMicros': serializer.toJson<int?>(endUtcMicros),
      'timezoneId': serializer.toJson<String>(timezoneId),
      'localStartDate': serializer.toJson<String>(localStartDate),
      'overtimeMinutes': serializer.toJson<int>(overtimeMinutes),
      'note': serializer.toJson<String?>(note),
      'voidReason': serializer.toJson<String?>(voidReason),
      'replacementShiftId': serializer.toJson<String?>(replacementShiftId),
      'replacedShiftId': serializer.toJson<String?>(replacedShiftId),
      'createdAtUtcMicros': serializer.toJson<int>(createdAtUtcMicros),
      'updatedAtUtcMicros': serializer.toJson<int>(updatedAtUtcMicros),
      'revision': serializer.toJson<int>(revision),
    };
  }

  WorkShift copyWith({
    String? id,
    String? employmentId,
    Value<String?> agreementId = const Value.absent(),
    String? state,
    int? startUtcMicros,
    Value<int?> endUtcMicros = const Value.absent(),
    String? timezoneId,
    String? localStartDate,
    int? overtimeMinutes,
    Value<String?> note = const Value.absent(),
    Value<String?> voidReason = const Value.absent(),
    Value<String?> replacementShiftId = const Value.absent(),
    Value<String?> replacedShiftId = const Value.absent(),
    int? createdAtUtcMicros,
    int? updatedAtUtcMicros,
    int? revision,
  }) => WorkShift(
    id: id ?? this.id,
    employmentId: employmentId ?? this.employmentId,
    agreementId: agreementId.present ? agreementId.value : this.agreementId,
    state: state ?? this.state,
    startUtcMicros: startUtcMicros ?? this.startUtcMicros,
    endUtcMicros: endUtcMicros.present ? endUtcMicros.value : this.endUtcMicros,
    timezoneId: timezoneId ?? this.timezoneId,
    localStartDate: localStartDate ?? this.localStartDate,
    overtimeMinutes: overtimeMinutes ?? this.overtimeMinutes,
    note: note.present ? note.value : this.note,
    voidReason: voidReason.present ? voidReason.value : this.voidReason,
    replacementShiftId: replacementShiftId.present
        ? replacementShiftId.value
        : this.replacementShiftId,
    replacedShiftId: replacedShiftId.present
        ? replacedShiftId.value
        : this.replacedShiftId,
    createdAtUtcMicros: createdAtUtcMicros ?? this.createdAtUtcMicros,
    updatedAtUtcMicros: updatedAtUtcMicros ?? this.updatedAtUtcMicros,
    revision: revision ?? this.revision,
  );
  WorkShift copyWithCompanion(WorkShiftsCompanion data) {
    return WorkShift(
      id: data.id.present ? data.id.value : this.id,
      employmentId: data.employmentId.present
          ? data.employmentId.value
          : this.employmentId,
      agreementId: data.agreementId.present
          ? data.agreementId.value
          : this.agreementId,
      state: data.state.present ? data.state.value : this.state,
      startUtcMicros: data.startUtcMicros.present
          ? data.startUtcMicros.value
          : this.startUtcMicros,
      endUtcMicros: data.endUtcMicros.present
          ? data.endUtcMicros.value
          : this.endUtcMicros,
      timezoneId: data.timezoneId.present
          ? data.timezoneId.value
          : this.timezoneId,
      localStartDate: data.localStartDate.present
          ? data.localStartDate.value
          : this.localStartDate,
      overtimeMinutes: data.overtimeMinutes.present
          ? data.overtimeMinutes.value
          : this.overtimeMinutes,
      note: data.note.present ? data.note.value : this.note,
      voidReason: data.voidReason.present
          ? data.voidReason.value
          : this.voidReason,
      replacementShiftId: data.replacementShiftId.present
          ? data.replacementShiftId.value
          : this.replacementShiftId,
      replacedShiftId: data.replacedShiftId.present
          ? data.replacedShiftId.value
          : this.replacedShiftId,
      createdAtUtcMicros: data.createdAtUtcMicros.present
          ? data.createdAtUtcMicros.value
          : this.createdAtUtcMicros,
      updatedAtUtcMicros: data.updatedAtUtcMicros.present
          ? data.updatedAtUtcMicros.value
          : this.updatedAtUtcMicros,
      revision: data.revision.present ? data.revision.value : this.revision,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WorkShift(')
          ..write('id: $id, ')
          ..write('employmentId: $employmentId, ')
          ..write('agreementId: $agreementId, ')
          ..write('state: $state, ')
          ..write('startUtcMicros: $startUtcMicros, ')
          ..write('endUtcMicros: $endUtcMicros, ')
          ..write('timezoneId: $timezoneId, ')
          ..write('localStartDate: $localStartDate, ')
          ..write('overtimeMinutes: $overtimeMinutes, ')
          ..write('note: $note, ')
          ..write('voidReason: $voidReason, ')
          ..write('replacementShiftId: $replacementShiftId, ')
          ..write('replacedShiftId: $replacedShiftId, ')
          ..write('createdAtUtcMicros: $createdAtUtcMicros, ')
          ..write('updatedAtUtcMicros: $updatedAtUtcMicros, ')
          ..write('revision: $revision')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    employmentId,
    agreementId,
    state,
    startUtcMicros,
    endUtcMicros,
    timezoneId,
    localStartDate,
    overtimeMinutes,
    note,
    voidReason,
    replacementShiftId,
    replacedShiftId,
    createdAtUtcMicros,
    updatedAtUtcMicros,
    revision,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WorkShift &&
          other.id == this.id &&
          other.employmentId == this.employmentId &&
          other.agreementId == this.agreementId &&
          other.state == this.state &&
          other.startUtcMicros == this.startUtcMicros &&
          other.endUtcMicros == this.endUtcMicros &&
          other.timezoneId == this.timezoneId &&
          other.localStartDate == this.localStartDate &&
          other.overtimeMinutes == this.overtimeMinutes &&
          other.note == this.note &&
          other.voidReason == this.voidReason &&
          other.replacementShiftId == this.replacementShiftId &&
          other.replacedShiftId == this.replacedShiftId &&
          other.createdAtUtcMicros == this.createdAtUtcMicros &&
          other.updatedAtUtcMicros == this.updatedAtUtcMicros &&
          other.revision == this.revision);
}

class WorkShiftsCompanion extends UpdateCompanion<WorkShift> {
  final Value<String> id;
  final Value<String> employmentId;
  final Value<String?> agreementId;
  final Value<String> state;
  final Value<int> startUtcMicros;
  final Value<int?> endUtcMicros;
  final Value<String> timezoneId;
  final Value<String> localStartDate;
  final Value<int> overtimeMinutes;
  final Value<String?> note;
  final Value<String?> voidReason;
  final Value<String?> replacementShiftId;
  final Value<String?> replacedShiftId;
  final Value<int> createdAtUtcMicros;
  final Value<int> updatedAtUtcMicros;
  final Value<int> revision;
  final Value<int> rowid;
  const WorkShiftsCompanion({
    this.id = const Value.absent(),
    this.employmentId = const Value.absent(),
    this.agreementId = const Value.absent(),
    this.state = const Value.absent(),
    this.startUtcMicros = const Value.absent(),
    this.endUtcMicros = const Value.absent(),
    this.timezoneId = const Value.absent(),
    this.localStartDate = const Value.absent(),
    this.overtimeMinutes = const Value.absent(),
    this.note = const Value.absent(),
    this.voidReason = const Value.absent(),
    this.replacementShiftId = const Value.absent(),
    this.replacedShiftId = const Value.absent(),
    this.createdAtUtcMicros = const Value.absent(),
    this.updatedAtUtcMicros = const Value.absent(),
    this.revision = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WorkShiftsCompanion.insert({
    required String id,
    required String employmentId,
    this.agreementId = const Value.absent(),
    required String state,
    required int startUtcMicros,
    this.endUtcMicros = const Value.absent(),
    required String timezoneId,
    required String localStartDate,
    required int overtimeMinutes,
    this.note = const Value.absent(),
    this.voidReason = const Value.absent(),
    this.replacementShiftId = const Value.absent(),
    this.replacedShiftId = const Value.absent(),
    required int createdAtUtcMicros,
    required int updatedAtUtcMicros,
    required int revision,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       employmentId = Value(employmentId),
       state = Value(state),
       startUtcMicros = Value(startUtcMicros),
       timezoneId = Value(timezoneId),
       localStartDate = Value(localStartDate),
       overtimeMinutes = Value(overtimeMinutes),
       createdAtUtcMicros = Value(createdAtUtcMicros),
       updatedAtUtcMicros = Value(updatedAtUtcMicros),
       revision = Value(revision);
  static Insertable<WorkShift> custom({
    Expression<String>? id,
    Expression<String>? employmentId,
    Expression<String>? agreementId,
    Expression<String>? state,
    Expression<int>? startUtcMicros,
    Expression<int>? endUtcMicros,
    Expression<String>? timezoneId,
    Expression<String>? localStartDate,
    Expression<int>? overtimeMinutes,
    Expression<String>? note,
    Expression<String>? voidReason,
    Expression<String>? replacementShiftId,
    Expression<String>? replacedShiftId,
    Expression<int>? createdAtUtcMicros,
    Expression<int>? updatedAtUtcMicros,
    Expression<int>? revision,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (employmentId != null) 'employment_id': employmentId,
      if (agreementId != null) 'agreement_id': agreementId,
      if (state != null) 'state': state,
      if (startUtcMicros != null) 'start_utc_micros': startUtcMicros,
      if (endUtcMicros != null) 'end_utc_micros': endUtcMicros,
      if (timezoneId != null) 'timezone_id': timezoneId,
      if (localStartDate != null) 'local_start_date': localStartDate,
      if (overtimeMinutes != null) 'overtime_minutes': overtimeMinutes,
      if (note != null) 'note': note,
      if (voidReason != null) 'void_reason': voidReason,
      if (replacementShiftId != null)
        'replacement_shift_id': replacementShiftId,
      if (replacedShiftId != null) 'replaced_shift_id': replacedShiftId,
      if (createdAtUtcMicros != null)
        'created_at_utc_micros': createdAtUtcMicros,
      if (updatedAtUtcMicros != null)
        'updated_at_utc_micros': updatedAtUtcMicros,
      if (revision != null) 'revision': revision,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WorkShiftsCompanion copyWith({
    Value<String>? id,
    Value<String>? employmentId,
    Value<String?>? agreementId,
    Value<String>? state,
    Value<int>? startUtcMicros,
    Value<int?>? endUtcMicros,
    Value<String>? timezoneId,
    Value<String>? localStartDate,
    Value<int>? overtimeMinutes,
    Value<String?>? note,
    Value<String?>? voidReason,
    Value<String?>? replacementShiftId,
    Value<String?>? replacedShiftId,
    Value<int>? createdAtUtcMicros,
    Value<int>? updatedAtUtcMicros,
    Value<int>? revision,
    Value<int>? rowid,
  }) {
    return WorkShiftsCompanion(
      id: id ?? this.id,
      employmentId: employmentId ?? this.employmentId,
      agreementId: agreementId ?? this.agreementId,
      state: state ?? this.state,
      startUtcMicros: startUtcMicros ?? this.startUtcMicros,
      endUtcMicros: endUtcMicros ?? this.endUtcMicros,
      timezoneId: timezoneId ?? this.timezoneId,
      localStartDate: localStartDate ?? this.localStartDate,
      overtimeMinutes: overtimeMinutes ?? this.overtimeMinutes,
      note: note ?? this.note,
      voidReason: voidReason ?? this.voidReason,
      replacementShiftId: replacementShiftId ?? this.replacementShiftId,
      replacedShiftId: replacedShiftId ?? this.replacedShiftId,
      createdAtUtcMicros: createdAtUtcMicros ?? this.createdAtUtcMicros,
      updatedAtUtcMicros: updatedAtUtcMicros ?? this.updatedAtUtcMicros,
      revision: revision ?? this.revision,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (employmentId.present) {
      map['employment_id'] = Variable<String>(employmentId.value);
    }
    if (agreementId.present) {
      map['agreement_id'] = Variable<String>(agreementId.value);
    }
    if (state.present) {
      map['state'] = Variable<String>(state.value);
    }
    if (startUtcMicros.present) {
      map['start_utc_micros'] = Variable<int>(startUtcMicros.value);
    }
    if (endUtcMicros.present) {
      map['end_utc_micros'] = Variable<int>(endUtcMicros.value);
    }
    if (timezoneId.present) {
      map['timezone_id'] = Variable<String>(timezoneId.value);
    }
    if (localStartDate.present) {
      map['local_start_date'] = Variable<String>(localStartDate.value);
    }
    if (overtimeMinutes.present) {
      map['overtime_minutes'] = Variable<int>(overtimeMinutes.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (voidReason.present) {
      map['void_reason'] = Variable<String>(voidReason.value);
    }
    if (replacementShiftId.present) {
      map['replacement_shift_id'] = Variable<String>(replacementShiftId.value);
    }
    if (replacedShiftId.present) {
      map['replaced_shift_id'] = Variable<String>(replacedShiftId.value);
    }
    if (createdAtUtcMicros.present) {
      map['created_at_utc_micros'] = Variable<int>(createdAtUtcMicros.value);
    }
    if (updatedAtUtcMicros.present) {
      map['updated_at_utc_micros'] = Variable<int>(updatedAtUtcMicros.value);
    }
    if (revision.present) {
      map['revision'] = Variable<int>(revision.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WorkShiftsCompanion(')
          ..write('id: $id, ')
          ..write('employmentId: $employmentId, ')
          ..write('agreementId: $agreementId, ')
          ..write('state: $state, ')
          ..write('startUtcMicros: $startUtcMicros, ')
          ..write('endUtcMicros: $endUtcMicros, ')
          ..write('timezoneId: $timezoneId, ')
          ..write('localStartDate: $localStartDate, ')
          ..write('overtimeMinutes: $overtimeMinutes, ')
          ..write('note: $note, ')
          ..write('voidReason: $voidReason, ')
          ..write('replacementShiftId: $replacementShiftId, ')
          ..write('replacedShiftId: $replacedShiftId, ')
          ..write('createdAtUtcMicros: $createdAtUtcMicros, ')
          ..write('updatedAtUtcMicros: $updatedAtUtcMicros, ')
          ..write('revision: $revision, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ShiftBreaksTable extends ShiftBreaks
    with TableInfo<$ShiftBreaksTable, ShiftBreak> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ShiftBreaksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _shiftIdMeta = const VerificationMeta(
    'shiftId',
  );
  @override
  late final GeneratedColumn<String> shiftId = GeneratedColumn<String>(
    'shift_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES work_shifts (id) ON DELETE RESTRICT',
    ),
  );
  static const VerificationMeta _startUtcMicrosMeta = const VerificationMeta(
    'startUtcMicros',
  );
  @override
  late final GeneratedColumn<int> startUtcMicros = GeneratedColumn<int>(
    'start_utc_micros',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endUtcMicrosMeta = const VerificationMeta(
    'endUtcMicros',
  );
  @override
  late final GeneratedColumn<int> endUtcMicros = GeneratedColumn<int>(
    'end_utc_micros',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtUtcMicrosMeta =
      const VerificationMeta('createdAtUtcMicros');
  @override
  late final GeneratedColumn<int> createdAtUtcMicros = GeneratedColumn<int>(
    'created_at_utc_micros',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtUtcMicrosMeta =
      const VerificationMeta('updatedAtUtcMicros');
  @override
  late final GeneratedColumn<int> updatedAtUtcMicros = GeneratedColumn<int>(
    'updated_at_utc_micros',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _revisionMeta = const VerificationMeta(
    'revision',
  );
  @override
  late final GeneratedColumn<int> revision = GeneratedColumn<int>(
    'revision',
    aliasedName,
    false,
    check: () => const CustomExpression<bool>('revision >= 0'),
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    shiftId,
    startUtcMicros,
    endUtcMicros,
    createdAtUtcMicros,
    updatedAtUtcMicros,
    revision,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'shift_breaks';
  @override
  VerificationContext validateIntegrity(
    Insertable<ShiftBreak> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('shift_id')) {
      context.handle(
        _shiftIdMeta,
        shiftId.isAcceptableOrUnknown(data['shift_id']!, _shiftIdMeta),
      );
    } else if (isInserting) {
      context.missing(_shiftIdMeta);
    }
    if (data.containsKey('start_utc_micros')) {
      context.handle(
        _startUtcMicrosMeta,
        startUtcMicros.isAcceptableOrUnknown(
          data['start_utc_micros']!,
          _startUtcMicrosMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_startUtcMicrosMeta);
    }
    if (data.containsKey('end_utc_micros')) {
      context.handle(
        _endUtcMicrosMeta,
        endUtcMicros.isAcceptableOrUnknown(
          data['end_utc_micros']!,
          _endUtcMicrosMeta,
        ),
      );
    }
    if (data.containsKey('created_at_utc_micros')) {
      context.handle(
        _createdAtUtcMicrosMeta,
        createdAtUtcMicros.isAcceptableOrUnknown(
          data['created_at_utc_micros']!,
          _createdAtUtcMicrosMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtUtcMicrosMeta);
    }
    if (data.containsKey('updated_at_utc_micros')) {
      context.handle(
        _updatedAtUtcMicrosMeta,
        updatedAtUtcMicros.isAcceptableOrUnknown(
          data['updated_at_utc_micros']!,
          _updatedAtUtcMicrosMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_updatedAtUtcMicrosMeta);
    }
    if (data.containsKey('revision')) {
      context.handle(
        _revisionMeta,
        revision.isAcceptableOrUnknown(data['revision']!, _revisionMeta),
      );
    } else if (isInserting) {
      context.missing(_revisionMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ShiftBreak map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ShiftBreak(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      shiftId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}shift_id'],
      )!,
      startUtcMicros: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}start_utc_micros'],
      )!,
      endUtcMicros: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}end_utc_micros'],
      ),
      createdAtUtcMicros: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at_utc_micros'],
      )!,
      updatedAtUtcMicros: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at_utc_micros'],
      )!,
      revision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}revision'],
      )!,
    );
  }

  @override
  $ShiftBreaksTable createAlias(String alias) {
    return $ShiftBreaksTable(attachedDatabase, alias);
  }
}

class ShiftBreak extends DataClass implements Insertable<ShiftBreak> {
  final String id;
  final String shiftId;
  final int startUtcMicros;
  final int? endUtcMicros;
  final int createdAtUtcMicros;
  final int updatedAtUtcMicros;
  final int revision;
  const ShiftBreak({
    required this.id,
    required this.shiftId,
    required this.startUtcMicros,
    this.endUtcMicros,
    required this.createdAtUtcMicros,
    required this.updatedAtUtcMicros,
    required this.revision,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['shift_id'] = Variable<String>(shiftId);
    map['start_utc_micros'] = Variable<int>(startUtcMicros);
    if (!nullToAbsent || endUtcMicros != null) {
      map['end_utc_micros'] = Variable<int>(endUtcMicros);
    }
    map['created_at_utc_micros'] = Variable<int>(createdAtUtcMicros);
    map['updated_at_utc_micros'] = Variable<int>(updatedAtUtcMicros);
    map['revision'] = Variable<int>(revision);
    return map;
  }

  ShiftBreaksCompanion toCompanion(bool nullToAbsent) {
    return ShiftBreaksCompanion(
      id: Value(id),
      shiftId: Value(shiftId),
      startUtcMicros: Value(startUtcMicros),
      endUtcMicros: endUtcMicros == null && nullToAbsent
          ? const Value.absent()
          : Value(endUtcMicros),
      createdAtUtcMicros: Value(createdAtUtcMicros),
      updatedAtUtcMicros: Value(updatedAtUtcMicros),
      revision: Value(revision),
    );
  }

  factory ShiftBreak.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ShiftBreak(
      id: serializer.fromJson<String>(json['id']),
      shiftId: serializer.fromJson<String>(json['shiftId']),
      startUtcMicros: serializer.fromJson<int>(json['startUtcMicros']),
      endUtcMicros: serializer.fromJson<int?>(json['endUtcMicros']),
      createdAtUtcMicros: serializer.fromJson<int>(json['createdAtUtcMicros']),
      updatedAtUtcMicros: serializer.fromJson<int>(json['updatedAtUtcMicros']),
      revision: serializer.fromJson<int>(json['revision']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'shiftId': serializer.toJson<String>(shiftId),
      'startUtcMicros': serializer.toJson<int>(startUtcMicros),
      'endUtcMicros': serializer.toJson<int?>(endUtcMicros),
      'createdAtUtcMicros': serializer.toJson<int>(createdAtUtcMicros),
      'updatedAtUtcMicros': serializer.toJson<int>(updatedAtUtcMicros),
      'revision': serializer.toJson<int>(revision),
    };
  }

  ShiftBreak copyWith({
    String? id,
    String? shiftId,
    int? startUtcMicros,
    Value<int?> endUtcMicros = const Value.absent(),
    int? createdAtUtcMicros,
    int? updatedAtUtcMicros,
    int? revision,
  }) => ShiftBreak(
    id: id ?? this.id,
    shiftId: shiftId ?? this.shiftId,
    startUtcMicros: startUtcMicros ?? this.startUtcMicros,
    endUtcMicros: endUtcMicros.present ? endUtcMicros.value : this.endUtcMicros,
    createdAtUtcMicros: createdAtUtcMicros ?? this.createdAtUtcMicros,
    updatedAtUtcMicros: updatedAtUtcMicros ?? this.updatedAtUtcMicros,
    revision: revision ?? this.revision,
  );
  ShiftBreak copyWithCompanion(ShiftBreaksCompanion data) {
    return ShiftBreak(
      id: data.id.present ? data.id.value : this.id,
      shiftId: data.shiftId.present ? data.shiftId.value : this.shiftId,
      startUtcMicros: data.startUtcMicros.present
          ? data.startUtcMicros.value
          : this.startUtcMicros,
      endUtcMicros: data.endUtcMicros.present
          ? data.endUtcMicros.value
          : this.endUtcMicros,
      createdAtUtcMicros: data.createdAtUtcMicros.present
          ? data.createdAtUtcMicros.value
          : this.createdAtUtcMicros,
      updatedAtUtcMicros: data.updatedAtUtcMicros.present
          ? data.updatedAtUtcMicros.value
          : this.updatedAtUtcMicros,
      revision: data.revision.present ? data.revision.value : this.revision,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ShiftBreak(')
          ..write('id: $id, ')
          ..write('shiftId: $shiftId, ')
          ..write('startUtcMicros: $startUtcMicros, ')
          ..write('endUtcMicros: $endUtcMicros, ')
          ..write('createdAtUtcMicros: $createdAtUtcMicros, ')
          ..write('updatedAtUtcMicros: $updatedAtUtcMicros, ')
          ..write('revision: $revision')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    shiftId,
    startUtcMicros,
    endUtcMicros,
    createdAtUtcMicros,
    updatedAtUtcMicros,
    revision,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ShiftBreak &&
          other.id == this.id &&
          other.shiftId == this.shiftId &&
          other.startUtcMicros == this.startUtcMicros &&
          other.endUtcMicros == this.endUtcMicros &&
          other.createdAtUtcMicros == this.createdAtUtcMicros &&
          other.updatedAtUtcMicros == this.updatedAtUtcMicros &&
          other.revision == this.revision);
}

class ShiftBreaksCompanion extends UpdateCompanion<ShiftBreak> {
  final Value<String> id;
  final Value<String> shiftId;
  final Value<int> startUtcMicros;
  final Value<int?> endUtcMicros;
  final Value<int> createdAtUtcMicros;
  final Value<int> updatedAtUtcMicros;
  final Value<int> revision;
  final Value<int> rowid;
  const ShiftBreaksCompanion({
    this.id = const Value.absent(),
    this.shiftId = const Value.absent(),
    this.startUtcMicros = const Value.absent(),
    this.endUtcMicros = const Value.absent(),
    this.createdAtUtcMicros = const Value.absent(),
    this.updatedAtUtcMicros = const Value.absent(),
    this.revision = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ShiftBreaksCompanion.insert({
    required String id,
    required String shiftId,
    required int startUtcMicros,
    this.endUtcMicros = const Value.absent(),
    required int createdAtUtcMicros,
    required int updatedAtUtcMicros,
    required int revision,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       shiftId = Value(shiftId),
       startUtcMicros = Value(startUtcMicros),
       createdAtUtcMicros = Value(createdAtUtcMicros),
       updatedAtUtcMicros = Value(updatedAtUtcMicros),
       revision = Value(revision);
  static Insertable<ShiftBreak> custom({
    Expression<String>? id,
    Expression<String>? shiftId,
    Expression<int>? startUtcMicros,
    Expression<int>? endUtcMicros,
    Expression<int>? createdAtUtcMicros,
    Expression<int>? updatedAtUtcMicros,
    Expression<int>? revision,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (shiftId != null) 'shift_id': shiftId,
      if (startUtcMicros != null) 'start_utc_micros': startUtcMicros,
      if (endUtcMicros != null) 'end_utc_micros': endUtcMicros,
      if (createdAtUtcMicros != null)
        'created_at_utc_micros': createdAtUtcMicros,
      if (updatedAtUtcMicros != null)
        'updated_at_utc_micros': updatedAtUtcMicros,
      if (revision != null) 'revision': revision,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ShiftBreaksCompanion copyWith({
    Value<String>? id,
    Value<String>? shiftId,
    Value<int>? startUtcMicros,
    Value<int?>? endUtcMicros,
    Value<int>? createdAtUtcMicros,
    Value<int>? updatedAtUtcMicros,
    Value<int>? revision,
    Value<int>? rowid,
  }) {
    return ShiftBreaksCompanion(
      id: id ?? this.id,
      shiftId: shiftId ?? this.shiftId,
      startUtcMicros: startUtcMicros ?? this.startUtcMicros,
      endUtcMicros: endUtcMicros ?? this.endUtcMicros,
      createdAtUtcMicros: createdAtUtcMicros ?? this.createdAtUtcMicros,
      updatedAtUtcMicros: updatedAtUtcMicros ?? this.updatedAtUtcMicros,
      revision: revision ?? this.revision,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (shiftId.present) {
      map['shift_id'] = Variable<String>(shiftId.value);
    }
    if (startUtcMicros.present) {
      map['start_utc_micros'] = Variable<int>(startUtcMicros.value);
    }
    if (endUtcMicros.present) {
      map['end_utc_micros'] = Variable<int>(endUtcMicros.value);
    }
    if (createdAtUtcMicros.present) {
      map['created_at_utc_micros'] = Variable<int>(createdAtUtcMicros.value);
    }
    if (updatedAtUtcMicros.present) {
      map['updated_at_utc_micros'] = Variable<int>(updatedAtUtcMicros.value);
    }
    if (revision.present) {
      map['revision'] = Variable<int>(revision.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ShiftBreaksCompanion(')
          ..write('id: $id, ')
          ..write('shiftId: $shiftId, ')
          ..write('startUtcMicros: $startUtcMicros, ')
          ..write('endUtcMicros: $endUtcMicros, ')
          ..write('createdAtUtcMicros: $createdAtUtcMicros, ')
          ..write('updatedAtUtcMicros: $updatedAtUtcMicros, ')
          ..write('revision: $revision, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PayPeriodsTable extends PayPeriods
    with TableInfo<$PayPeriodsTable, PayPeriod> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PayPeriodsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _employmentIdMeta = const VerificationMeta(
    'employmentId',
  );
  @override
  late final GeneratedColumn<String> employmentId = GeneratedColumn<String>(
    'employment_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES employments (id) ON DELETE RESTRICT',
    ),
  );
  static const VerificationMeta _startMeta = const VerificationMeta('start');
  @override
  late final GeneratedColumn<String> start = GeneratedColumn<String>(
    'start',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endMeta = const VerificationMeta('end');
  @override
  late final GeneratedColumn<String> end = GeneratedColumn<String>(
    'end',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _labelMeta = const VerificationMeta('label');
  @override
  late final GeneratedColumn<String> label = GeneratedColumn<String>(
    'label',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _stateMeta = const VerificationMeta('state');
  @override
  late final GeneratedColumn<String> state = GeneratedColumn<String>(
    'state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtUtcMicrosMeta =
      const VerificationMeta('createdAtUtcMicros');
  @override
  late final GeneratedColumn<int> createdAtUtcMicros = GeneratedColumn<int>(
    'created_at_utc_micros',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtUtcMicrosMeta =
      const VerificationMeta('updatedAtUtcMicros');
  @override
  late final GeneratedColumn<int> updatedAtUtcMicros = GeneratedColumn<int>(
    'updated_at_utc_micros',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _revisionMeta = const VerificationMeta(
    'revision',
  );
  @override
  late final GeneratedColumn<int> revision = GeneratedColumn<int>(
    'revision',
    aliasedName,
    false,
    check: () => const CustomExpression<bool>('revision >= 0'),
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    employmentId,
    start,
    end,
    label,
    state,
    createdAtUtcMicros,
    updatedAtUtcMicros,
    revision,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pay_periods';
  @override
  VerificationContext validateIntegrity(
    Insertable<PayPeriod> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('employment_id')) {
      context.handle(
        _employmentIdMeta,
        employmentId.isAcceptableOrUnknown(
          data['employment_id']!,
          _employmentIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_employmentIdMeta);
    }
    if (data.containsKey('start')) {
      context.handle(
        _startMeta,
        start.isAcceptableOrUnknown(data['start']!, _startMeta),
      );
    } else if (isInserting) {
      context.missing(_startMeta);
    }
    if (data.containsKey('end')) {
      context.handle(
        _endMeta,
        end.isAcceptableOrUnknown(data['end']!, _endMeta),
      );
    } else if (isInserting) {
      context.missing(_endMeta);
    }
    if (data.containsKey('label')) {
      context.handle(
        _labelMeta,
        label.isAcceptableOrUnknown(data['label']!, _labelMeta),
      );
    }
    if (data.containsKey('state')) {
      context.handle(
        _stateMeta,
        state.isAcceptableOrUnknown(data['state']!, _stateMeta),
      );
    } else if (isInserting) {
      context.missing(_stateMeta);
    }
    if (data.containsKey('created_at_utc_micros')) {
      context.handle(
        _createdAtUtcMicrosMeta,
        createdAtUtcMicros.isAcceptableOrUnknown(
          data['created_at_utc_micros']!,
          _createdAtUtcMicrosMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtUtcMicrosMeta);
    }
    if (data.containsKey('updated_at_utc_micros')) {
      context.handle(
        _updatedAtUtcMicrosMeta,
        updatedAtUtcMicros.isAcceptableOrUnknown(
          data['updated_at_utc_micros']!,
          _updatedAtUtcMicrosMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_updatedAtUtcMicrosMeta);
    }
    if (data.containsKey('revision')) {
      context.handle(
        _revisionMeta,
        revision.isAcceptableOrUnknown(data['revision']!, _revisionMeta),
      );
    } else if (isInserting) {
      context.missing(_revisionMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PayPeriod map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PayPeriod(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      employmentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}employment_id'],
      )!,
      start: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}start'],
      )!,
      end: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}end'],
      )!,
      label: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}label'],
      ),
      state: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}state'],
      )!,
      createdAtUtcMicros: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at_utc_micros'],
      )!,
      updatedAtUtcMicros: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at_utc_micros'],
      )!,
      revision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}revision'],
      )!,
    );
  }

  @override
  $PayPeriodsTable createAlias(String alias) {
    return $PayPeriodsTable(attachedDatabase, alias);
  }
}

class PayPeriod extends DataClass implements Insertable<PayPeriod> {
  final String id;
  final String employmentId;
  final String start;
  final String end;
  final String? label;
  final String state;
  final int createdAtUtcMicros;
  final int updatedAtUtcMicros;
  final int revision;
  const PayPeriod({
    required this.id,
    required this.employmentId,
    required this.start,
    required this.end,
    this.label,
    required this.state,
    required this.createdAtUtcMicros,
    required this.updatedAtUtcMicros,
    required this.revision,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['employment_id'] = Variable<String>(employmentId);
    map['start'] = Variable<String>(start);
    map['end'] = Variable<String>(end);
    if (!nullToAbsent || label != null) {
      map['label'] = Variable<String>(label);
    }
    map['state'] = Variable<String>(state);
    map['created_at_utc_micros'] = Variable<int>(createdAtUtcMicros);
    map['updated_at_utc_micros'] = Variable<int>(updatedAtUtcMicros);
    map['revision'] = Variable<int>(revision);
    return map;
  }

  PayPeriodsCompanion toCompanion(bool nullToAbsent) {
    return PayPeriodsCompanion(
      id: Value(id),
      employmentId: Value(employmentId),
      start: Value(start),
      end: Value(end),
      label: label == null && nullToAbsent
          ? const Value.absent()
          : Value(label),
      state: Value(state),
      createdAtUtcMicros: Value(createdAtUtcMicros),
      updatedAtUtcMicros: Value(updatedAtUtcMicros),
      revision: Value(revision),
    );
  }

  factory PayPeriod.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PayPeriod(
      id: serializer.fromJson<String>(json['id']),
      employmentId: serializer.fromJson<String>(json['employmentId']),
      start: serializer.fromJson<String>(json['start']),
      end: serializer.fromJson<String>(json['end']),
      label: serializer.fromJson<String?>(json['label']),
      state: serializer.fromJson<String>(json['state']),
      createdAtUtcMicros: serializer.fromJson<int>(json['createdAtUtcMicros']),
      updatedAtUtcMicros: serializer.fromJson<int>(json['updatedAtUtcMicros']),
      revision: serializer.fromJson<int>(json['revision']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'employmentId': serializer.toJson<String>(employmentId),
      'start': serializer.toJson<String>(start),
      'end': serializer.toJson<String>(end),
      'label': serializer.toJson<String?>(label),
      'state': serializer.toJson<String>(state),
      'createdAtUtcMicros': serializer.toJson<int>(createdAtUtcMicros),
      'updatedAtUtcMicros': serializer.toJson<int>(updatedAtUtcMicros),
      'revision': serializer.toJson<int>(revision),
    };
  }

  PayPeriod copyWith({
    String? id,
    String? employmentId,
    String? start,
    String? end,
    Value<String?> label = const Value.absent(),
    String? state,
    int? createdAtUtcMicros,
    int? updatedAtUtcMicros,
    int? revision,
  }) => PayPeriod(
    id: id ?? this.id,
    employmentId: employmentId ?? this.employmentId,
    start: start ?? this.start,
    end: end ?? this.end,
    label: label.present ? label.value : this.label,
    state: state ?? this.state,
    createdAtUtcMicros: createdAtUtcMicros ?? this.createdAtUtcMicros,
    updatedAtUtcMicros: updatedAtUtcMicros ?? this.updatedAtUtcMicros,
    revision: revision ?? this.revision,
  );
  PayPeriod copyWithCompanion(PayPeriodsCompanion data) {
    return PayPeriod(
      id: data.id.present ? data.id.value : this.id,
      employmentId: data.employmentId.present
          ? data.employmentId.value
          : this.employmentId,
      start: data.start.present ? data.start.value : this.start,
      end: data.end.present ? data.end.value : this.end,
      label: data.label.present ? data.label.value : this.label,
      state: data.state.present ? data.state.value : this.state,
      createdAtUtcMicros: data.createdAtUtcMicros.present
          ? data.createdAtUtcMicros.value
          : this.createdAtUtcMicros,
      updatedAtUtcMicros: data.updatedAtUtcMicros.present
          ? data.updatedAtUtcMicros.value
          : this.updatedAtUtcMicros,
      revision: data.revision.present ? data.revision.value : this.revision,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PayPeriod(')
          ..write('id: $id, ')
          ..write('employmentId: $employmentId, ')
          ..write('start: $start, ')
          ..write('end: $end, ')
          ..write('label: $label, ')
          ..write('state: $state, ')
          ..write('createdAtUtcMicros: $createdAtUtcMicros, ')
          ..write('updatedAtUtcMicros: $updatedAtUtcMicros, ')
          ..write('revision: $revision')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    employmentId,
    start,
    end,
    label,
    state,
    createdAtUtcMicros,
    updatedAtUtcMicros,
    revision,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PayPeriod &&
          other.id == this.id &&
          other.employmentId == this.employmentId &&
          other.start == this.start &&
          other.end == this.end &&
          other.label == this.label &&
          other.state == this.state &&
          other.createdAtUtcMicros == this.createdAtUtcMicros &&
          other.updatedAtUtcMicros == this.updatedAtUtcMicros &&
          other.revision == this.revision);
}

class PayPeriodsCompanion extends UpdateCompanion<PayPeriod> {
  final Value<String> id;
  final Value<String> employmentId;
  final Value<String> start;
  final Value<String> end;
  final Value<String?> label;
  final Value<String> state;
  final Value<int> createdAtUtcMicros;
  final Value<int> updatedAtUtcMicros;
  final Value<int> revision;
  final Value<int> rowid;
  const PayPeriodsCompanion({
    this.id = const Value.absent(),
    this.employmentId = const Value.absent(),
    this.start = const Value.absent(),
    this.end = const Value.absent(),
    this.label = const Value.absent(),
    this.state = const Value.absent(),
    this.createdAtUtcMicros = const Value.absent(),
    this.updatedAtUtcMicros = const Value.absent(),
    this.revision = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PayPeriodsCompanion.insert({
    required String id,
    required String employmentId,
    required String start,
    required String end,
    this.label = const Value.absent(),
    required String state,
    required int createdAtUtcMicros,
    required int updatedAtUtcMicros,
    required int revision,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       employmentId = Value(employmentId),
       start = Value(start),
       end = Value(end),
       state = Value(state),
       createdAtUtcMicros = Value(createdAtUtcMicros),
       updatedAtUtcMicros = Value(updatedAtUtcMicros),
       revision = Value(revision);
  static Insertable<PayPeriod> custom({
    Expression<String>? id,
    Expression<String>? employmentId,
    Expression<String>? start,
    Expression<String>? end,
    Expression<String>? label,
    Expression<String>? state,
    Expression<int>? createdAtUtcMicros,
    Expression<int>? updatedAtUtcMicros,
    Expression<int>? revision,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (employmentId != null) 'employment_id': employmentId,
      if (start != null) 'start': start,
      if (end != null) 'end': end,
      if (label != null) 'label': label,
      if (state != null) 'state': state,
      if (createdAtUtcMicros != null)
        'created_at_utc_micros': createdAtUtcMicros,
      if (updatedAtUtcMicros != null)
        'updated_at_utc_micros': updatedAtUtcMicros,
      if (revision != null) 'revision': revision,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PayPeriodsCompanion copyWith({
    Value<String>? id,
    Value<String>? employmentId,
    Value<String>? start,
    Value<String>? end,
    Value<String?>? label,
    Value<String>? state,
    Value<int>? createdAtUtcMicros,
    Value<int>? updatedAtUtcMicros,
    Value<int>? revision,
    Value<int>? rowid,
  }) {
    return PayPeriodsCompanion(
      id: id ?? this.id,
      employmentId: employmentId ?? this.employmentId,
      start: start ?? this.start,
      end: end ?? this.end,
      label: label ?? this.label,
      state: state ?? this.state,
      createdAtUtcMicros: createdAtUtcMicros ?? this.createdAtUtcMicros,
      updatedAtUtcMicros: updatedAtUtcMicros ?? this.updatedAtUtcMicros,
      revision: revision ?? this.revision,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (employmentId.present) {
      map['employment_id'] = Variable<String>(employmentId.value);
    }
    if (start.present) {
      map['start'] = Variable<String>(start.value);
    }
    if (end.present) {
      map['end'] = Variable<String>(end.value);
    }
    if (label.present) {
      map['label'] = Variable<String>(label.value);
    }
    if (state.present) {
      map['state'] = Variable<String>(state.value);
    }
    if (createdAtUtcMicros.present) {
      map['created_at_utc_micros'] = Variable<int>(createdAtUtcMicros.value);
    }
    if (updatedAtUtcMicros.present) {
      map['updated_at_utc_micros'] = Variable<int>(updatedAtUtcMicros.value);
    }
    if (revision.present) {
      map['revision'] = Variable<int>(revision.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PayPeriodsCompanion(')
          ..write('id: $id, ')
          ..write('employmentId: $employmentId, ')
          ..write('start: $start, ')
          ..write('end: $end, ')
          ..write('label: $label, ')
          ..write('state: $state, ')
          ..write('createdAtUtcMicros: $createdAtUtcMicros, ')
          ..write('updatedAtUtcMicros: $updatedAtUtcMicros, ')
          ..write('revision: $revision, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PayslipsTable extends Payslips with TableInfo<$PayslipsTable, Payslip> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PayslipsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _periodIdMeta = const VerificationMeta(
    'periodId',
  );
  @override
  late final GeneratedColumn<String> periodId = GeneratedColumn<String>(
    'period_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES pay_periods (id) ON DELETE RESTRICT',
    ),
  );
  static const VerificationMeta _issuedDateMeta = const VerificationMeta(
    'issuedDate',
  );
  @override
  late final GeneratedColumn<String> issuedDate = GeneratedColumn<String>(
    'issued_date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _paidDateMeta = const VerificationMeta(
    'paidDate',
  );
  @override
  late final GeneratedColumn<String> paidDate = GeneratedColumn<String>(
    'paid_date',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _amountMinorUnitsMeta = const VerificationMeta(
    'amountMinorUnits',
  );
  @override
  late final GeneratedColumn<int> amountMinorUnits = GeneratedColumn<int>(
    'amount_minor_units',
    aliasedName,
    false,
    check: () => const CustomExpression<bool>('amount_minor_units > 0'),
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _currencyMeta = const VerificationMeta(
    'currency',
  );
  @override
  late final GeneratedColumn<String> currency = GeneratedColumn<String>(
    'currency',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _basisMeta = const VerificationMeta('basis');
  @override
  late final GeneratedColumn<String> basis = GeneratedColumn<String>(
    'basis',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _grossMinorUnitsMeta = const VerificationMeta(
    'grossMinorUnits',
  );
  @override
  late final GeneratedColumn<int> grossMinorUnits = GeneratedColumn<int>(
    'gross_minor_units',
    aliasedName,
    true,
    check: () => const CustomExpression<bool>(
      'gross_minor_units IS NULL OR gross_minor_units >= 0',
    ),
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _netMinorUnitsMeta = const VerificationMeta(
    'netMinorUnits',
  );
  @override
  late final GeneratedColumn<int> netMinorUnits = GeneratedColumn<int>(
    'net_minor_units',
    aliasedName,
    true,
    check: () => const CustomExpression<bool>(
      'net_minor_units IS NULL OR net_minor_units >= 0',
    ),
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deductionMinorUnitsMeta =
      const VerificationMeta('deductionMinorUnits');
  @override
  late final GeneratedColumn<int> deductionMinorUnits = GeneratedColumn<int>(
    'deduction_minor_units',
    aliasedName,
    true,
    check: () => const CustomExpression<bool>(
      'deduction_minor_units IS NULL OR deduction_minor_units >= 0',
    ),
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _referenceMeta = const VerificationMeta(
    'reference',
  );
  @override
  late final GeneratedColumn<String> reference = GeneratedColumn<String>(
    'reference',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _stateMeta = const VerificationMeta('state');
  @override
  late final GeneratedColumn<String> state = GeneratedColumn<String>(
    'state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _voidReasonMeta = const VerificationMeta(
    'voidReason',
  );
  @override
  late final GeneratedColumn<String> voidReason = GeneratedColumn<String>(
    'void_reason',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _replacementPayslipIdMeta =
      const VerificationMeta('replacementPayslipId');
  @override
  late final GeneratedColumn<String> replacementPayslipId =
      GeneratedColumn<String>(
        'replacement_payslip_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES payslips (id) ON DELETE RESTRICT',
        ),
      );
  static const VerificationMeta _replacedPayslipIdMeta = const VerificationMeta(
    'replacedPayslipId',
  );
  @override
  late final GeneratedColumn<String> replacedPayslipId =
      GeneratedColumn<String>(
        'replaced_payslip_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES payslips (id) ON DELETE RESTRICT',
        ),
      );
  static const VerificationMeta _createdAtUtcMicrosMeta =
      const VerificationMeta('createdAtUtcMicros');
  @override
  late final GeneratedColumn<int> createdAtUtcMicros = GeneratedColumn<int>(
    'created_at_utc_micros',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtUtcMicrosMeta =
      const VerificationMeta('updatedAtUtcMicros');
  @override
  late final GeneratedColumn<int> updatedAtUtcMicros = GeneratedColumn<int>(
    'updated_at_utc_micros',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _revisionMeta = const VerificationMeta(
    'revision',
  );
  @override
  late final GeneratedColumn<int> revision = GeneratedColumn<int>(
    'revision',
    aliasedName,
    false,
    check: () => const CustomExpression<bool>('revision >= 0'),
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    periodId,
    issuedDate,
    paidDate,
    amountMinorUnits,
    currency,
    basis,
    grossMinorUnits,
    netMinorUnits,
    deductionMinorUnits,
    reference,
    note,
    state,
    voidReason,
    replacementPayslipId,
    replacedPayslipId,
    createdAtUtcMicros,
    updatedAtUtcMicros,
    revision,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'payslips';
  @override
  VerificationContext validateIntegrity(
    Insertable<Payslip> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('period_id')) {
      context.handle(
        _periodIdMeta,
        periodId.isAcceptableOrUnknown(data['period_id']!, _periodIdMeta),
      );
    } else if (isInserting) {
      context.missing(_periodIdMeta);
    }
    if (data.containsKey('issued_date')) {
      context.handle(
        _issuedDateMeta,
        issuedDate.isAcceptableOrUnknown(data['issued_date']!, _issuedDateMeta),
      );
    } else if (isInserting) {
      context.missing(_issuedDateMeta);
    }
    if (data.containsKey('paid_date')) {
      context.handle(
        _paidDateMeta,
        paidDate.isAcceptableOrUnknown(data['paid_date']!, _paidDateMeta),
      );
    }
    if (data.containsKey('amount_minor_units')) {
      context.handle(
        _amountMinorUnitsMeta,
        amountMinorUnits.isAcceptableOrUnknown(
          data['amount_minor_units']!,
          _amountMinorUnitsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_amountMinorUnitsMeta);
    }
    if (data.containsKey('currency')) {
      context.handle(
        _currencyMeta,
        currency.isAcceptableOrUnknown(data['currency']!, _currencyMeta),
      );
    } else if (isInserting) {
      context.missing(_currencyMeta);
    }
    if (data.containsKey('basis')) {
      context.handle(
        _basisMeta,
        basis.isAcceptableOrUnknown(data['basis']!, _basisMeta),
      );
    } else if (isInserting) {
      context.missing(_basisMeta);
    }
    if (data.containsKey('gross_minor_units')) {
      context.handle(
        _grossMinorUnitsMeta,
        grossMinorUnits.isAcceptableOrUnknown(
          data['gross_minor_units']!,
          _grossMinorUnitsMeta,
        ),
      );
    }
    if (data.containsKey('net_minor_units')) {
      context.handle(
        _netMinorUnitsMeta,
        netMinorUnits.isAcceptableOrUnknown(
          data['net_minor_units']!,
          _netMinorUnitsMeta,
        ),
      );
    }
    if (data.containsKey('deduction_minor_units')) {
      context.handle(
        _deductionMinorUnitsMeta,
        deductionMinorUnits.isAcceptableOrUnknown(
          data['deduction_minor_units']!,
          _deductionMinorUnitsMeta,
        ),
      );
    }
    if (data.containsKey('reference')) {
      context.handle(
        _referenceMeta,
        reference.isAcceptableOrUnknown(data['reference']!, _referenceMeta),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('state')) {
      context.handle(
        _stateMeta,
        state.isAcceptableOrUnknown(data['state']!, _stateMeta),
      );
    } else if (isInserting) {
      context.missing(_stateMeta);
    }
    if (data.containsKey('void_reason')) {
      context.handle(
        _voidReasonMeta,
        voidReason.isAcceptableOrUnknown(data['void_reason']!, _voidReasonMeta),
      );
    }
    if (data.containsKey('replacement_payslip_id')) {
      context.handle(
        _replacementPayslipIdMeta,
        replacementPayslipId.isAcceptableOrUnknown(
          data['replacement_payslip_id']!,
          _replacementPayslipIdMeta,
        ),
      );
    }
    if (data.containsKey('replaced_payslip_id')) {
      context.handle(
        _replacedPayslipIdMeta,
        replacedPayslipId.isAcceptableOrUnknown(
          data['replaced_payslip_id']!,
          _replacedPayslipIdMeta,
        ),
      );
    }
    if (data.containsKey('created_at_utc_micros')) {
      context.handle(
        _createdAtUtcMicrosMeta,
        createdAtUtcMicros.isAcceptableOrUnknown(
          data['created_at_utc_micros']!,
          _createdAtUtcMicrosMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtUtcMicrosMeta);
    }
    if (data.containsKey('updated_at_utc_micros')) {
      context.handle(
        _updatedAtUtcMicrosMeta,
        updatedAtUtcMicros.isAcceptableOrUnknown(
          data['updated_at_utc_micros']!,
          _updatedAtUtcMicrosMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_updatedAtUtcMicrosMeta);
    }
    if (data.containsKey('revision')) {
      context.handle(
        _revisionMeta,
        revision.isAcceptableOrUnknown(data['revision']!, _revisionMeta),
      );
    } else if (isInserting) {
      context.missing(_revisionMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Payslip map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Payslip(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      periodId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}period_id'],
      )!,
      issuedDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}issued_date'],
      )!,
      paidDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}paid_date'],
      ),
      amountMinorUnits: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}amount_minor_units'],
      )!,
      currency: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}currency'],
      )!,
      basis: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}basis'],
      )!,
      grossMinorUnits: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}gross_minor_units'],
      ),
      netMinorUnits: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}net_minor_units'],
      ),
      deductionMinorUnits: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deduction_minor_units'],
      ),
      reference: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reference'],
      ),
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      state: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}state'],
      )!,
      voidReason: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}void_reason'],
      ),
      replacementPayslipId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}replacement_payslip_id'],
      ),
      replacedPayslipId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}replaced_payslip_id'],
      ),
      createdAtUtcMicros: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at_utc_micros'],
      )!,
      updatedAtUtcMicros: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at_utc_micros'],
      )!,
      revision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}revision'],
      )!,
    );
  }

  @override
  $PayslipsTable createAlias(String alias) {
    return $PayslipsTable(attachedDatabase, alias);
  }
}

class Payslip extends DataClass implements Insertable<Payslip> {
  final String id;
  final String periodId;
  final String issuedDate;
  final String? paidDate;
  final int amountMinorUnits;
  final String currency;
  final String basis;
  final int? grossMinorUnits;
  final int? netMinorUnits;
  final int? deductionMinorUnits;
  final String? reference;
  final String? note;
  final String state;
  final String? voidReason;
  final String? replacementPayslipId;
  final String? replacedPayslipId;
  final int createdAtUtcMicros;
  final int updatedAtUtcMicros;
  final int revision;
  const Payslip({
    required this.id,
    required this.periodId,
    required this.issuedDate,
    this.paidDate,
    required this.amountMinorUnits,
    required this.currency,
    required this.basis,
    this.grossMinorUnits,
    this.netMinorUnits,
    this.deductionMinorUnits,
    this.reference,
    this.note,
    required this.state,
    this.voidReason,
    this.replacementPayslipId,
    this.replacedPayslipId,
    required this.createdAtUtcMicros,
    required this.updatedAtUtcMicros,
    required this.revision,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['period_id'] = Variable<String>(periodId);
    map['issued_date'] = Variable<String>(issuedDate);
    if (!nullToAbsent || paidDate != null) {
      map['paid_date'] = Variable<String>(paidDate);
    }
    map['amount_minor_units'] = Variable<int>(amountMinorUnits);
    map['currency'] = Variable<String>(currency);
    map['basis'] = Variable<String>(basis);
    if (!nullToAbsent || grossMinorUnits != null) {
      map['gross_minor_units'] = Variable<int>(grossMinorUnits);
    }
    if (!nullToAbsent || netMinorUnits != null) {
      map['net_minor_units'] = Variable<int>(netMinorUnits);
    }
    if (!nullToAbsent || deductionMinorUnits != null) {
      map['deduction_minor_units'] = Variable<int>(deductionMinorUnits);
    }
    if (!nullToAbsent || reference != null) {
      map['reference'] = Variable<String>(reference);
    }
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    map['state'] = Variable<String>(state);
    if (!nullToAbsent || voidReason != null) {
      map['void_reason'] = Variable<String>(voidReason);
    }
    if (!nullToAbsent || replacementPayslipId != null) {
      map['replacement_payslip_id'] = Variable<String>(replacementPayslipId);
    }
    if (!nullToAbsent || replacedPayslipId != null) {
      map['replaced_payslip_id'] = Variable<String>(replacedPayslipId);
    }
    map['created_at_utc_micros'] = Variable<int>(createdAtUtcMicros);
    map['updated_at_utc_micros'] = Variable<int>(updatedAtUtcMicros);
    map['revision'] = Variable<int>(revision);
    return map;
  }

  PayslipsCompanion toCompanion(bool nullToAbsent) {
    return PayslipsCompanion(
      id: Value(id),
      periodId: Value(periodId),
      issuedDate: Value(issuedDate),
      paidDate: paidDate == null && nullToAbsent
          ? const Value.absent()
          : Value(paidDate),
      amountMinorUnits: Value(amountMinorUnits),
      currency: Value(currency),
      basis: Value(basis),
      grossMinorUnits: grossMinorUnits == null && nullToAbsent
          ? const Value.absent()
          : Value(grossMinorUnits),
      netMinorUnits: netMinorUnits == null && nullToAbsent
          ? const Value.absent()
          : Value(netMinorUnits),
      deductionMinorUnits: deductionMinorUnits == null && nullToAbsent
          ? const Value.absent()
          : Value(deductionMinorUnits),
      reference: reference == null && nullToAbsent
          ? const Value.absent()
          : Value(reference),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      state: Value(state),
      voidReason: voidReason == null && nullToAbsent
          ? const Value.absent()
          : Value(voidReason),
      replacementPayslipId: replacementPayslipId == null && nullToAbsent
          ? const Value.absent()
          : Value(replacementPayslipId),
      replacedPayslipId: replacedPayslipId == null && nullToAbsent
          ? const Value.absent()
          : Value(replacedPayslipId),
      createdAtUtcMicros: Value(createdAtUtcMicros),
      updatedAtUtcMicros: Value(updatedAtUtcMicros),
      revision: Value(revision),
    );
  }

  factory Payslip.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Payslip(
      id: serializer.fromJson<String>(json['id']),
      periodId: serializer.fromJson<String>(json['periodId']),
      issuedDate: serializer.fromJson<String>(json['issuedDate']),
      paidDate: serializer.fromJson<String?>(json['paidDate']),
      amountMinorUnits: serializer.fromJson<int>(json['amountMinorUnits']),
      currency: serializer.fromJson<String>(json['currency']),
      basis: serializer.fromJson<String>(json['basis']),
      grossMinorUnits: serializer.fromJson<int?>(json['grossMinorUnits']),
      netMinorUnits: serializer.fromJson<int?>(json['netMinorUnits']),
      deductionMinorUnits: serializer.fromJson<int?>(
        json['deductionMinorUnits'],
      ),
      reference: serializer.fromJson<String?>(json['reference']),
      note: serializer.fromJson<String?>(json['note']),
      state: serializer.fromJson<String>(json['state']),
      voidReason: serializer.fromJson<String?>(json['voidReason']),
      replacementPayslipId: serializer.fromJson<String?>(
        json['replacementPayslipId'],
      ),
      replacedPayslipId: serializer.fromJson<String?>(
        json['replacedPayslipId'],
      ),
      createdAtUtcMicros: serializer.fromJson<int>(json['createdAtUtcMicros']),
      updatedAtUtcMicros: serializer.fromJson<int>(json['updatedAtUtcMicros']),
      revision: serializer.fromJson<int>(json['revision']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'periodId': serializer.toJson<String>(periodId),
      'issuedDate': serializer.toJson<String>(issuedDate),
      'paidDate': serializer.toJson<String?>(paidDate),
      'amountMinorUnits': serializer.toJson<int>(amountMinorUnits),
      'currency': serializer.toJson<String>(currency),
      'basis': serializer.toJson<String>(basis),
      'grossMinorUnits': serializer.toJson<int?>(grossMinorUnits),
      'netMinorUnits': serializer.toJson<int?>(netMinorUnits),
      'deductionMinorUnits': serializer.toJson<int?>(deductionMinorUnits),
      'reference': serializer.toJson<String?>(reference),
      'note': serializer.toJson<String?>(note),
      'state': serializer.toJson<String>(state),
      'voidReason': serializer.toJson<String?>(voidReason),
      'replacementPayslipId': serializer.toJson<String?>(replacementPayslipId),
      'replacedPayslipId': serializer.toJson<String?>(replacedPayslipId),
      'createdAtUtcMicros': serializer.toJson<int>(createdAtUtcMicros),
      'updatedAtUtcMicros': serializer.toJson<int>(updatedAtUtcMicros),
      'revision': serializer.toJson<int>(revision),
    };
  }

  Payslip copyWith({
    String? id,
    String? periodId,
    String? issuedDate,
    Value<String?> paidDate = const Value.absent(),
    int? amountMinorUnits,
    String? currency,
    String? basis,
    Value<int?> grossMinorUnits = const Value.absent(),
    Value<int?> netMinorUnits = const Value.absent(),
    Value<int?> deductionMinorUnits = const Value.absent(),
    Value<String?> reference = const Value.absent(),
    Value<String?> note = const Value.absent(),
    String? state,
    Value<String?> voidReason = const Value.absent(),
    Value<String?> replacementPayslipId = const Value.absent(),
    Value<String?> replacedPayslipId = const Value.absent(),
    int? createdAtUtcMicros,
    int? updatedAtUtcMicros,
    int? revision,
  }) => Payslip(
    id: id ?? this.id,
    periodId: periodId ?? this.periodId,
    issuedDate: issuedDate ?? this.issuedDate,
    paidDate: paidDate.present ? paidDate.value : this.paidDate,
    amountMinorUnits: amountMinorUnits ?? this.amountMinorUnits,
    currency: currency ?? this.currency,
    basis: basis ?? this.basis,
    grossMinorUnits: grossMinorUnits.present
        ? grossMinorUnits.value
        : this.grossMinorUnits,
    netMinorUnits: netMinorUnits.present
        ? netMinorUnits.value
        : this.netMinorUnits,
    deductionMinorUnits: deductionMinorUnits.present
        ? deductionMinorUnits.value
        : this.deductionMinorUnits,
    reference: reference.present ? reference.value : this.reference,
    note: note.present ? note.value : this.note,
    state: state ?? this.state,
    voidReason: voidReason.present ? voidReason.value : this.voidReason,
    replacementPayslipId: replacementPayslipId.present
        ? replacementPayslipId.value
        : this.replacementPayslipId,
    replacedPayslipId: replacedPayslipId.present
        ? replacedPayslipId.value
        : this.replacedPayslipId,
    createdAtUtcMicros: createdAtUtcMicros ?? this.createdAtUtcMicros,
    updatedAtUtcMicros: updatedAtUtcMicros ?? this.updatedAtUtcMicros,
    revision: revision ?? this.revision,
  );
  Payslip copyWithCompanion(PayslipsCompanion data) {
    return Payslip(
      id: data.id.present ? data.id.value : this.id,
      periodId: data.periodId.present ? data.periodId.value : this.periodId,
      issuedDate: data.issuedDate.present
          ? data.issuedDate.value
          : this.issuedDate,
      paidDate: data.paidDate.present ? data.paidDate.value : this.paidDate,
      amountMinorUnits: data.amountMinorUnits.present
          ? data.amountMinorUnits.value
          : this.amountMinorUnits,
      currency: data.currency.present ? data.currency.value : this.currency,
      basis: data.basis.present ? data.basis.value : this.basis,
      grossMinorUnits: data.grossMinorUnits.present
          ? data.grossMinorUnits.value
          : this.grossMinorUnits,
      netMinorUnits: data.netMinorUnits.present
          ? data.netMinorUnits.value
          : this.netMinorUnits,
      deductionMinorUnits: data.deductionMinorUnits.present
          ? data.deductionMinorUnits.value
          : this.deductionMinorUnits,
      reference: data.reference.present ? data.reference.value : this.reference,
      note: data.note.present ? data.note.value : this.note,
      state: data.state.present ? data.state.value : this.state,
      voidReason: data.voidReason.present
          ? data.voidReason.value
          : this.voidReason,
      replacementPayslipId: data.replacementPayslipId.present
          ? data.replacementPayslipId.value
          : this.replacementPayslipId,
      replacedPayslipId: data.replacedPayslipId.present
          ? data.replacedPayslipId.value
          : this.replacedPayslipId,
      createdAtUtcMicros: data.createdAtUtcMicros.present
          ? data.createdAtUtcMicros.value
          : this.createdAtUtcMicros,
      updatedAtUtcMicros: data.updatedAtUtcMicros.present
          ? data.updatedAtUtcMicros.value
          : this.updatedAtUtcMicros,
      revision: data.revision.present ? data.revision.value : this.revision,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Payslip(')
          ..write('id: $id, ')
          ..write('periodId: $periodId, ')
          ..write('issuedDate: $issuedDate, ')
          ..write('paidDate: $paidDate, ')
          ..write('amountMinorUnits: $amountMinorUnits, ')
          ..write('currency: $currency, ')
          ..write('basis: $basis, ')
          ..write('grossMinorUnits: $grossMinorUnits, ')
          ..write('netMinorUnits: $netMinorUnits, ')
          ..write('deductionMinorUnits: $deductionMinorUnits, ')
          ..write('reference: $reference, ')
          ..write('note: $note, ')
          ..write('state: $state, ')
          ..write('voidReason: $voidReason, ')
          ..write('replacementPayslipId: $replacementPayslipId, ')
          ..write('replacedPayslipId: $replacedPayslipId, ')
          ..write('createdAtUtcMicros: $createdAtUtcMicros, ')
          ..write('updatedAtUtcMicros: $updatedAtUtcMicros, ')
          ..write('revision: $revision')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    periodId,
    issuedDate,
    paidDate,
    amountMinorUnits,
    currency,
    basis,
    grossMinorUnits,
    netMinorUnits,
    deductionMinorUnits,
    reference,
    note,
    state,
    voidReason,
    replacementPayslipId,
    replacedPayslipId,
    createdAtUtcMicros,
    updatedAtUtcMicros,
    revision,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Payslip &&
          other.id == this.id &&
          other.periodId == this.periodId &&
          other.issuedDate == this.issuedDate &&
          other.paidDate == this.paidDate &&
          other.amountMinorUnits == this.amountMinorUnits &&
          other.currency == this.currency &&
          other.basis == this.basis &&
          other.grossMinorUnits == this.grossMinorUnits &&
          other.netMinorUnits == this.netMinorUnits &&
          other.deductionMinorUnits == this.deductionMinorUnits &&
          other.reference == this.reference &&
          other.note == this.note &&
          other.state == this.state &&
          other.voidReason == this.voidReason &&
          other.replacementPayslipId == this.replacementPayslipId &&
          other.replacedPayslipId == this.replacedPayslipId &&
          other.createdAtUtcMicros == this.createdAtUtcMicros &&
          other.updatedAtUtcMicros == this.updatedAtUtcMicros &&
          other.revision == this.revision);
}

class PayslipsCompanion extends UpdateCompanion<Payslip> {
  final Value<String> id;
  final Value<String> periodId;
  final Value<String> issuedDate;
  final Value<String?> paidDate;
  final Value<int> amountMinorUnits;
  final Value<String> currency;
  final Value<String> basis;
  final Value<int?> grossMinorUnits;
  final Value<int?> netMinorUnits;
  final Value<int?> deductionMinorUnits;
  final Value<String?> reference;
  final Value<String?> note;
  final Value<String> state;
  final Value<String?> voidReason;
  final Value<String?> replacementPayslipId;
  final Value<String?> replacedPayslipId;
  final Value<int> createdAtUtcMicros;
  final Value<int> updatedAtUtcMicros;
  final Value<int> revision;
  final Value<int> rowid;
  const PayslipsCompanion({
    this.id = const Value.absent(),
    this.periodId = const Value.absent(),
    this.issuedDate = const Value.absent(),
    this.paidDate = const Value.absent(),
    this.amountMinorUnits = const Value.absent(),
    this.currency = const Value.absent(),
    this.basis = const Value.absent(),
    this.grossMinorUnits = const Value.absent(),
    this.netMinorUnits = const Value.absent(),
    this.deductionMinorUnits = const Value.absent(),
    this.reference = const Value.absent(),
    this.note = const Value.absent(),
    this.state = const Value.absent(),
    this.voidReason = const Value.absent(),
    this.replacementPayslipId = const Value.absent(),
    this.replacedPayslipId = const Value.absent(),
    this.createdAtUtcMicros = const Value.absent(),
    this.updatedAtUtcMicros = const Value.absent(),
    this.revision = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PayslipsCompanion.insert({
    required String id,
    required String periodId,
    required String issuedDate,
    this.paidDate = const Value.absent(),
    required int amountMinorUnits,
    required String currency,
    required String basis,
    this.grossMinorUnits = const Value.absent(),
    this.netMinorUnits = const Value.absent(),
    this.deductionMinorUnits = const Value.absent(),
    this.reference = const Value.absent(),
    this.note = const Value.absent(),
    required String state,
    this.voidReason = const Value.absent(),
    this.replacementPayslipId = const Value.absent(),
    this.replacedPayslipId = const Value.absent(),
    required int createdAtUtcMicros,
    required int updatedAtUtcMicros,
    required int revision,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       periodId = Value(periodId),
       issuedDate = Value(issuedDate),
       amountMinorUnits = Value(amountMinorUnits),
       currency = Value(currency),
       basis = Value(basis),
       state = Value(state),
       createdAtUtcMicros = Value(createdAtUtcMicros),
       updatedAtUtcMicros = Value(updatedAtUtcMicros),
       revision = Value(revision);
  static Insertable<Payslip> custom({
    Expression<String>? id,
    Expression<String>? periodId,
    Expression<String>? issuedDate,
    Expression<String>? paidDate,
    Expression<int>? amountMinorUnits,
    Expression<String>? currency,
    Expression<String>? basis,
    Expression<int>? grossMinorUnits,
    Expression<int>? netMinorUnits,
    Expression<int>? deductionMinorUnits,
    Expression<String>? reference,
    Expression<String>? note,
    Expression<String>? state,
    Expression<String>? voidReason,
    Expression<String>? replacementPayslipId,
    Expression<String>? replacedPayslipId,
    Expression<int>? createdAtUtcMicros,
    Expression<int>? updatedAtUtcMicros,
    Expression<int>? revision,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (periodId != null) 'period_id': periodId,
      if (issuedDate != null) 'issued_date': issuedDate,
      if (paidDate != null) 'paid_date': paidDate,
      if (amountMinorUnits != null) 'amount_minor_units': amountMinorUnits,
      if (currency != null) 'currency': currency,
      if (basis != null) 'basis': basis,
      if (grossMinorUnits != null) 'gross_minor_units': grossMinorUnits,
      if (netMinorUnits != null) 'net_minor_units': netMinorUnits,
      if (deductionMinorUnits != null)
        'deduction_minor_units': deductionMinorUnits,
      if (reference != null) 'reference': reference,
      if (note != null) 'note': note,
      if (state != null) 'state': state,
      if (voidReason != null) 'void_reason': voidReason,
      if (replacementPayslipId != null)
        'replacement_payslip_id': replacementPayslipId,
      if (replacedPayslipId != null) 'replaced_payslip_id': replacedPayslipId,
      if (createdAtUtcMicros != null)
        'created_at_utc_micros': createdAtUtcMicros,
      if (updatedAtUtcMicros != null)
        'updated_at_utc_micros': updatedAtUtcMicros,
      if (revision != null) 'revision': revision,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PayslipsCompanion copyWith({
    Value<String>? id,
    Value<String>? periodId,
    Value<String>? issuedDate,
    Value<String?>? paidDate,
    Value<int>? amountMinorUnits,
    Value<String>? currency,
    Value<String>? basis,
    Value<int?>? grossMinorUnits,
    Value<int?>? netMinorUnits,
    Value<int?>? deductionMinorUnits,
    Value<String?>? reference,
    Value<String?>? note,
    Value<String>? state,
    Value<String?>? voidReason,
    Value<String?>? replacementPayslipId,
    Value<String?>? replacedPayslipId,
    Value<int>? createdAtUtcMicros,
    Value<int>? updatedAtUtcMicros,
    Value<int>? revision,
    Value<int>? rowid,
  }) {
    return PayslipsCompanion(
      id: id ?? this.id,
      periodId: periodId ?? this.periodId,
      issuedDate: issuedDate ?? this.issuedDate,
      paidDate: paidDate ?? this.paidDate,
      amountMinorUnits: amountMinorUnits ?? this.amountMinorUnits,
      currency: currency ?? this.currency,
      basis: basis ?? this.basis,
      grossMinorUnits: grossMinorUnits ?? this.grossMinorUnits,
      netMinorUnits: netMinorUnits ?? this.netMinorUnits,
      deductionMinorUnits: deductionMinorUnits ?? this.deductionMinorUnits,
      reference: reference ?? this.reference,
      note: note ?? this.note,
      state: state ?? this.state,
      voidReason: voidReason ?? this.voidReason,
      replacementPayslipId: replacementPayslipId ?? this.replacementPayslipId,
      replacedPayslipId: replacedPayslipId ?? this.replacedPayslipId,
      createdAtUtcMicros: createdAtUtcMicros ?? this.createdAtUtcMicros,
      updatedAtUtcMicros: updatedAtUtcMicros ?? this.updatedAtUtcMicros,
      revision: revision ?? this.revision,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (periodId.present) {
      map['period_id'] = Variable<String>(periodId.value);
    }
    if (issuedDate.present) {
      map['issued_date'] = Variable<String>(issuedDate.value);
    }
    if (paidDate.present) {
      map['paid_date'] = Variable<String>(paidDate.value);
    }
    if (amountMinorUnits.present) {
      map['amount_minor_units'] = Variable<int>(amountMinorUnits.value);
    }
    if (currency.present) {
      map['currency'] = Variable<String>(currency.value);
    }
    if (basis.present) {
      map['basis'] = Variable<String>(basis.value);
    }
    if (grossMinorUnits.present) {
      map['gross_minor_units'] = Variable<int>(grossMinorUnits.value);
    }
    if (netMinorUnits.present) {
      map['net_minor_units'] = Variable<int>(netMinorUnits.value);
    }
    if (deductionMinorUnits.present) {
      map['deduction_minor_units'] = Variable<int>(deductionMinorUnits.value);
    }
    if (reference.present) {
      map['reference'] = Variable<String>(reference.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (state.present) {
      map['state'] = Variable<String>(state.value);
    }
    if (voidReason.present) {
      map['void_reason'] = Variable<String>(voidReason.value);
    }
    if (replacementPayslipId.present) {
      map['replacement_payslip_id'] = Variable<String>(
        replacementPayslipId.value,
      );
    }
    if (replacedPayslipId.present) {
      map['replaced_payslip_id'] = Variable<String>(replacedPayslipId.value);
    }
    if (createdAtUtcMicros.present) {
      map['created_at_utc_micros'] = Variable<int>(createdAtUtcMicros.value);
    }
    if (updatedAtUtcMicros.present) {
      map['updated_at_utc_micros'] = Variable<int>(updatedAtUtcMicros.value);
    }
    if (revision.present) {
      map['revision'] = Variable<int>(revision.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PayslipsCompanion(')
          ..write('id: $id, ')
          ..write('periodId: $periodId, ')
          ..write('issuedDate: $issuedDate, ')
          ..write('paidDate: $paidDate, ')
          ..write('amountMinorUnits: $amountMinorUnits, ')
          ..write('currency: $currency, ')
          ..write('basis: $basis, ')
          ..write('grossMinorUnits: $grossMinorUnits, ')
          ..write('netMinorUnits: $netMinorUnits, ')
          ..write('deductionMinorUnits: $deductionMinorUnits, ')
          ..write('reference: $reference, ')
          ..write('note: $note, ')
          ..write('state: $state, ')
          ..write('voidReason: $voidReason, ')
          ..write('replacementPayslipId: $replacementPayslipId, ')
          ..write('replacedPayslipId: $replacedPayslipId, ')
          ..write('createdAtUtcMicros: $createdAtUtcMicros, ')
          ..write('updatedAtUtcMicros: $updatedAtUtcMicros, ')
          ..write('revision: $revision, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $CoreMetadataTable coreMetadata = $CoreMetadataTable(this);
  late final $EmploymentsTable employments = $EmploymentsTable(this);
  late final $PayAgreementsTable payAgreements = $PayAgreementsTable(this);
  late final $WorkShiftsTable workShifts = $WorkShiftsTable(this);
  late final $ShiftBreaksTable shiftBreaks = $ShiftBreaksTable(this);
  late final $PayPeriodsTable payPeriods = $PayPeriodsTable(this);
  late final $PayslipsTable payslips = $PayslipsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    coreMetadata,
    employments,
    payAgreements,
    workShifts,
    shiftBreaks,
    payPeriods,
    payslips,
  ];
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
typedef $$EmploymentsTableCreateCompanionBuilder =
    EmploymentsCompanion Function({
      required String id,
      required String name,
      Value<String?> legalLabel,
      required String status,
      required int createdAtUtcMicros,
      required int updatedAtUtcMicros,
      required int revision,
      Value<int> rowid,
    });
typedef $$EmploymentsTableUpdateCompanionBuilder =
    EmploymentsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String?> legalLabel,
      Value<String> status,
      Value<int> createdAtUtcMicros,
      Value<int> updatedAtUtcMicros,
      Value<int> revision,
      Value<int> rowid,
    });

final class $$EmploymentsTableReferences
    extends BaseReferences<_$AppDatabase, $EmploymentsTable, Employment> {
  $$EmploymentsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$PayAgreementsTable, List<PayAgreement>>
  _payAgreementsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.payAgreements,
    aliasName: 'employments__id__pay_agreements__employment_id',
  );

  $$PayAgreementsTableProcessedTableManager get payAgreementsRefs {
    final manager = $$PayAgreementsTableTableManager(
      $_db,
      $_db.payAgreements,
    ).filter((f) => f.employmentId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_payAgreementsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$WorkShiftsTable, List<WorkShift>>
  _workShiftsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.workShifts,
    aliasName: 'employments__id__work_shifts__employment_id',
  );

  $$WorkShiftsTableProcessedTableManager get workShiftsRefs {
    final manager = $$WorkShiftsTableTableManager(
      $_db,
      $_db.workShifts,
    ).filter((f) => f.employmentId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_workShiftsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$PayPeriodsTable, List<PayPeriod>>
  _payPeriodsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.payPeriods,
    aliasName: 'employments__id__pay_periods__employment_id',
  );

  $$PayPeriodsTableProcessedTableManager get payPeriodsRefs {
    final manager = $$PayPeriodsTableTableManager(
      $_db,
      $_db.payPeriods,
    ).filter((f) => f.employmentId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_payPeriodsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$EmploymentsTableFilterComposer
    extends Composer<_$AppDatabase, $EmploymentsTable> {
  $$EmploymentsTableFilterComposer({
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

  ColumnFilters<String> get legalLabel => $composableBuilder(
    column: $table.legalLabel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAtUtcMicros => $composableBuilder(
    column: $table.createdAtUtcMicros,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAtUtcMicros => $composableBuilder(
    column: $table.updatedAtUtcMicros,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> payAgreementsRefs(
    Expression<bool> Function($$PayAgreementsTableFilterComposer f) f,
  ) {
    final $$PayAgreementsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.payAgreements,
      getReferencedColumn: (t) => t.employmentId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PayAgreementsTableFilterComposer(
            $db: $db,
            $table: $db.payAgreements,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> workShiftsRefs(
    Expression<bool> Function($$WorkShiftsTableFilterComposer f) f,
  ) {
    final $$WorkShiftsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.workShifts,
      getReferencedColumn: (t) => t.employmentId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkShiftsTableFilterComposer(
            $db: $db,
            $table: $db.workShifts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> payPeriodsRefs(
    Expression<bool> Function($$PayPeriodsTableFilterComposer f) f,
  ) {
    final $$PayPeriodsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.payPeriods,
      getReferencedColumn: (t) => t.employmentId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PayPeriodsTableFilterComposer(
            $db: $db,
            $table: $db.payPeriods,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$EmploymentsTableOrderingComposer
    extends Composer<_$AppDatabase, $EmploymentsTable> {
  $$EmploymentsTableOrderingComposer({
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

  ColumnOrderings<String> get legalLabel => $composableBuilder(
    column: $table.legalLabel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAtUtcMicros => $composableBuilder(
    column: $table.createdAtUtcMicros,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAtUtcMicros => $composableBuilder(
    column: $table.updatedAtUtcMicros,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$EmploymentsTableAnnotationComposer
    extends Composer<_$AppDatabase, $EmploymentsTable> {
  $$EmploymentsTableAnnotationComposer({
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

  GeneratedColumn<String> get legalLabel => $composableBuilder(
    column: $table.legalLabel,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get createdAtUtcMicros => $composableBuilder(
    column: $table.createdAtUtcMicros,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAtUtcMicros => $composableBuilder(
    column: $table.updatedAtUtcMicros,
    builder: (column) => column,
  );

  GeneratedColumn<int> get revision =>
      $composableBuilder(column: $table.revision, builder: (column) => column);

  Expression<T> payAgreementsRefs<T extends Object>(
    Expression<T> Function($$PayAgreementsTableAnnotationComposer a) f,
  ) {
    final $$PayAgreementsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.payAgreements,
      getReferencedColumn: (t) => t.employmentId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PayAgreementsTableAnnotationComposer(
            $db: $db,
            $table: $db.payAgreements,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> workShiftsRefs<T extends Object>(
    Expression<T> Function($$WorkShiftsTableAnnotationComposer a) f,
  ) {
    final $$WorkShiftsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.workShifts,
      getReferencedColumn: (t) => t.employmentId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkShiftsTableAnnotationComposer(
            $db: $db,
            $table: $db.workShifts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> payPeriodsRefs<T extends Object>(
    Expression<T> Function($$PayPeriodsTableAnnotationComposer a) f,
  ) {
    final $$PayPeriodsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.payPeriods,
      getReferencedColumn: (t) => t.employmentId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PayPeriodsTableAnnotationComposer(
            $db: $db,
            $table: $db.payPeriods,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$EmploymentsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $EmploymentsTable,
          Employment,
          $$EmploymentsTableFilterComposer,
          $$EmploymentsTableOrderingComposer,
          $$EmploymentsTableAnnotationComposer,
          $$EmploymentsTableCreateCompanionBuilder,
          $$EmploymentsTableUpdateCompanionBuilder,
          (Employment, $$EmploymentsTableReferences),
          Employment,
          PrefetchHooks Function({
            bool payAgreementsRefs,
            bool workShiftsRefs,
            bool payPeriodsRefs,
          })
        > {
  $$EmploymentsTableTableManager(_$AppDatabase db, $EmploymentsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EmploymentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EmploymentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EmploymentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> legalLabel = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> createdAtUtcMicros = const Value.absent(),
                Value<int> updatedAtUtcMicros = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EmploymentsCompanion(
                id: id,
                name: name,
                legalLabel: legalLabel,
                status: status,
                createdAtUtcMicros: createdAtUtcMicros,
                updatedAtUtcMicros: updatedAtUtcMicros,
                revision: revision,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<String?> legalLabel = const Value.absent(),
                required String status,
                required int createdAtUtcMicros,
                required int updatedAtUtcMicros,
                required int revision,
                Value<int> rowid = const Value.absent(),
              }) => EmploymentsCompanion.insert(
                id: id,
                name: name,
                legalLabel: legalLabel,
                status: status,
                createdAtUtcMicros: createdAtUtcMicros,
                updatedAtUtcMicros: updatedAtUtcMicros,
                revision: revision,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$EmploymentsTable, Employment>(table),
                  $$EmploymentsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                payAgreementsRefs = false,
                workShiftsRefs = false,
                payPeriodsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (payAgreementsRefs) db.payAgreements,
                    if (workShiftsRefs) db.workShifts,
                    if (payPeriodsRefs) db.payPeriods,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (payAgreementsRefs)
                        await $_getPrefetchedData<
                          Employment,
                          $EmploymentsTable,
                          PayAgreement
                        >(
                          currentTable: table,
                          referencedTable: $$EmploymentsTableReferences
                              ._payAgreementsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$EmploymentsTableReferences(
                                db,
                                table,
                                p0,
                              ).payAgreementsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.employmentId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (workShiftsRefs)
                        await $_getPrefetchedData<
                          Employment,
                          $EmploymentsTable,
                          WorkShift
                        >(
                          currentTable: table,
                          referencedTable: $$EmploymentsTableReferences
                              ._workShiftsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$EmploymentsTableReferences(
                                db,
                                table,
                                p0,
                              ).workShiftsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.employmentId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (payPeriodsRefs)
                        await $_getPrefetchedData<
                          Employment,
                          $EmploymentsTable,
                          PayPeriod
                        >(
                          currentTable: table,
                          referencedTable: $$EmploymentsTableReferences
                              ._payPeriodsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$EmploymentsTableReferences(
                                db,
                                table,
                                p0,
                              ).payPeriodsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.employmentId == item.id,
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

typedef $$EmploymentsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $EmploymentsTable,
      Employment,
      $$EmploymentsTableFilterComposer,
      $$EmploymentsTableOrderingComposer,
      $$EmploymentsTableAnnotationComposer,
      $$EmploymentsTableCreateCompanionBuilder,
      $$EmploymentsTableUpdateCompanionBuilder,
      (Employment, $$EmploymentsTableReferences),
      Employment,
      PrefetchHooks Function({
        bool payAgreementsRefs,
        bool workShiftsRefs,
        bool payPeriodsRefs,
      })
    >;
typedef $$PayAgreementsTableCreateCompanionBuilder =
    PayAgreementsCompanion Function({
      required String id,
      required String employmentId,
      required int version,
      required String effectiveStart,
      Value<String?> effectiveEnd,
      required int hourlyRateMicroEur,
      required String basis,
      required int overtimeThresholdMinutes,
      required int overtimeMultiplierNumerator,
      required int overtimeMultiplierDenominator,
      Value<String?> label,
      Value<String?> note,
      required int createdAtUtcMicros,
      required int revision,
      Value<int> rowid,
    });
typedef $$PayAgreementsTableUpdateCompanionBuilder =
    PayAgreementsCompanion Function({
      Value<String> id,
      Value<String> employmentId,
      Value<int> version,
      Value<String> effectiveStart,
      Value<String?> effectiveEnd,
      Value<int> hourlyRateMicroEur,
      Value<String> basis,
      Value<int> overtimeThresholdMinutes,
      Value<int> overtimeMultiplierNumerator,
      Value<int> overtimeMultiplierDenominator,
      Value<String?> label,
      Value<String?> note,
      Value<int> createdAtUtcMicros,
      Value<int> revision,
      Value<int> rowid,
    });

final class $$PayAgreementsTableReferences
    extends BaseReferences<_$AppDatabase, $PayAgreementsTable, PayAgreement> {
  $$PayAgreementsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $EmploymentsTable _employmentIdTable(_$AppDatabase db) => db
      .employments
      .createAlias('pay_agreements__employment_id__employments__id');

  $$EmploymentsTableProcessedTableManager get employmentId {
    final $_column = $_itemColumn<String>('employment_id')!;

    final manager = $$EmploymentsTableTableManager(
      $_db,
      $_db.employments,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_employmentIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$WorkShiftsTable, List<WorkShift>>
  _workShiftsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.workShifts,
    aliasName: 'pay_agreements__id__work_shifts__agreement_id',
  );

  $$WorkShiftsTableProcessedTableManager get workShiftsRefs {
    final manager = $$WorkShiftsTableTableManager(
      $_db,
      $_db.workShifts,
    ).filter((f) => f.agreementId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_workShiftsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$PayAgreementsTableFilterComposer
    extends Composer<_$AppDatabase, $PayAgreementsTable> {
  $$PayAgreementsTableFilterComposer({
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

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get effectiveStart => $composableBuilder(
    column: $table.effectiveStart,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get effectiveEnd => $composableBuilder(
    column: $table.effectiveEnd,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get hourlyRateMicroEur => $composableBuilder(
    column: $table.hourlyRateMicroEur,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get basis => $composableBuilder(
    column: $table.basis,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get overtimeThresholdMinutes => $composableBuilder(
    column: $table.overtimeThresholdMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get overtimeMultiplierNumerator => $composableBuilder(
    column: $table.overtimeMultiplierNumerator,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get overtimeMultiplierDenominator => $composableBuilder(
    column: $table.overtimeMultiplierDenominator,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAtUtcMicros => $composableBuilder(
    column: $table.createdAtUtcMicros,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnFilters(column),
  );

  $$EmploymentsTableFilterComposer get employmentId {
    final $$EmploymentsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.employmentId,
      referencedTable: $db.employments,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EmploymentsTableFilterComposer(
            $db: $db,
            $table: $db.employments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> workShiftsRefs(
    Expression<bool> Function($$WorkShiftsTableFilterComposer f) f,
  ) {
    final $$WorkShiftsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.workShifts,
      getReferencedColumn: (t) => t.agreementId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkShiftsTableFilterComposer(
            $db: $db,
            $table: $db.workShifts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PayAgreementsTableOrderingComposer
    extends Composer<_$AppDatabase, $PayAgreementsTable> {
  $$PayAgreementsTableOrderingComposer({
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

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get effectiveStart => $composableBuilder(
    column: $table.effectiveStart,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get effectiveEnd => $composableBuilder(
    column: $table.effectiveEnd,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get hourlyRateMicroEur => $composableBuilder(
    column: $table.hourlyRateMicroEur,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get basis => $composableBuilder(
    column: $table.basis,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get overtimeThresholdMinutes => $composableBuilder(
    column: $table.overtimeThresholdMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get overtimeMultiplierNumerator => $composableBuilder(
    column: $table.overtimeMultiplierNumerator,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get overtimeMultiplierDenominator => $composableBuilder(
    column: $table.overtimeMultiplierDenominator,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAtUtcMicros => $composableBuilder(
    column: $table.createdAtUtcMicros,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnOrderings(column),
  );

  $$EmploymentsTableOrderingComposer get employmentId {
    final $$EmploymentsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.employmentId,
      referencedTable: $db.employments,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EmploymentsTableOrderingComposer(
            $db: $db,
            $table: $db.employments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PayAgreementsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PayAgreementsTable> {
  $$PayAgreementsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<String> get effectiveStart => $composableBuilder(
    column: $table.effectiveStart,
    builder: (column) => column,
  );

  GeneratedColumn<String> get effectiveEnd => $composableBuilder(
    column: $table.effectiveEnd,
    builder: (column) => column,
  );

  GeneratedColumn<int> get hourlyRateMicroEur => $composableBuilder(
    column: $table.hourlyRateMicroEur,
    builder: (column) => column,
  );

  GeneratedColumn<String> get basis =>
      $composableBuilder(column: $table.basis, builder: (column) => column);

  GeneratedColumn<int> get overtimeThresholdMinutes => $composableBuilder(
    column: $table.overtimeThresholdMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<int> get overtimeMultiplierNumerator => $composableBuilder(
    column: $table.overtimeMultiplierNumerator,
    builder: (column) => column,
  );

  GeneratedColumn<int> get overtimeMultiplierDenominator => $composableBuilder(
    column: $table.overtimeMultiplierDenominator,
    builder: (column) => column,
  );

  GeneratedColumn<String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<int> get createdAtUtcMicros => $composableBuilder(
    column: $table.createdAtUtcMicros,
    builder: (column) => column,
  );

  GeneratedColumn<int> get revision =>
      $composableBuilder(column: $table.revision, builder: (column) => column);

  $$EmploymentsTableAnnotationComposer get employmentId {
    final $$EmploymentsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.employmentId,
      referencedTable: $db.employments,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EmploymentsTableAnnotationComposer(
            $db: $db,
            $table: $db.employments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> workShiftsRefs<T extends Object>(
    Expression<T> Function($$WorkShiftsTableAnnotationComposer a) f,
  ) {
    final $$WorkShiftsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.workShifts,
      getReferencedColumn: (t) => t.agreementId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkShiftsTableAnnotationComposer(
            $db: $db,
            $table: $db.workShifts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PayAgreementsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PayAgreementsTable,
          PayAgreement,
          $$PayAgreementsTableFilterComposer,
          $$PayAgreementsTableOrderingComposer,
          $$PayAgreementsTableAnnotationComposer,
          $$PayAgreementsTableCreateCompanionBuilder,
          $$PayAgreementsTableUpdateCompanionBuilder,
          (PayAgreement, $$PayAgreementsTableReferences),
          PayAgreement,
          PrefetchHooks Function({bool employmentId, bool workShiftsRefs})
        > {
  $$PayAgreementsTableTableManager(_$AppDatabase db, $PayAgreementsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PayAgreementsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PayAgreementsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PayAgreementsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> employmentId = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<String> effectiveStart = const Value.absent(),
                Value<String?> effectiveEnd = const Value.absent(),
                Value<int> hourlyRateMicroEur = const Value.absent(),
                Value<String> basis = const Value.absent(),
                Value<int> overtimeThresholdMinutes = const Value.absent(),
                Value<int> overtimeMultiplierNumerator = const Value.absent(),
                Value<int> overtimeMultiplierDenominator = const Value.absent(),
                Value<String?> label = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<int> createdAtUtcMicros = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PayAgreementsCompanion(
                id: id,
                employmentId: employmentId,
                version: version,
                effectiveStart: effectiveStart,
                effectiveEnd: effectiveEnd,
                hourlyRateMicroEur: hourlyRateMicroEur,
                basis: basis,
                overtimeThresholdMinutes: overtimeThresholdMinutes,
                overtimeMultiplierNumerator: overtimeMultiplierNumerator,
                overtimeMultiplierDenominator: overtimeMultiplierDenominator,
                label: label,
                note: note,
                createdAtUtcMicros: createdAtUtcMicros,
                revision: revision,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String employmentId,
                required int version,
                required String effectiveStart,
                Value<String?> effectiveEnd = const Value.absent(),
                required int hourlyRateMicroEur,
                required String basis,
                required int overtimeThresholdMinutes,
                required int overtimeMultiplierNumerator,
                required int overtimeMultiplierDenominator,
                Value<String?> label = const Value.absent(),
                Value<String?> note = const Value.absent(),
                required int createdAtUtcMicros,
                required int revision,
                Value<int> rowid = const Value.absent(),
              }) => PayAgreementsCompanion.insert(
                id: id,
                employmentId: employmentId,
                version: version,
                effectiveStart: effectiveStart,
                effectiveEnd: effectiveEnd,
                hourlyRateMicroEur: hourlyRateMicroEur,
                basis: basis,
                overtimeThresholdMinutes: overtimeThresholdMinutes,
                overtimeMultiplierNumerator: overtimeMultiplierNumerator,
                overtimeMultiplierDenominator: overtimeMultiplierDenominator,
                label: label,
                note: note,
                createdAtUtcMicros: createdAtUtcMicros,
                revision: revision,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PayAgreementsTable, PayAgreement>(table),
                  $$PayAgreementsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({employmentId = false, workShiftsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [if (workShiftsRefs) db.workShifts],
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
                        if (employmentId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.employmentId,
                            referencedTable: $$PayAgreementsTableReferences
                                ._employmentIdTable(db),
                            referencedColumn: $$PayAgreementsTableReferences
                                ._employmentIdTable(db)
                                .id,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (workShiftsRefs)
                        await $_getPrefetchedData<
                          PayAgreement,
                          $PayAgreementsTable,
                          WorkShift
                        >(
                          currentTable: table,
                          referencedTable: $$PayAgreementsTableReferences
                              ._workShiftsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$PayAgreementsTableReferences(
                                db,
                                table,
                                p0,
                              ).workShiftsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.agreementId == item.id,
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

typedef $$PayAgreementsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PayAgreementsTable,
      PayAgreement,
      $$PayAgreementsTableFilterComposer,
      $$PayAgreementsTableOrderingComposer,
      $$PayAgreementsTableAnnotationComposer,
      $$PayAgreementsTableCreateCompanionBuilder,
      $$PayAgreementsTableUpdateCompanionBuilder,
      (PayAgreement, $$PayAgreementsTableReferences),
      PayAgreement,
      PrefetchHooks Function({bool employmentId, bool workShiftsRefs})
    >;
typedef $$WorkShiftsTableCreateCompanionBuilder = WorkShiftsCompanion Function({
  required String id,
  required String employmentId,
  Value<String?> agreementId,
  required String state,
  required int startUtcMicros,
  Value<int?> endUtcMicros,
  required String timezoneId,
  required String localStartDate,
  required int overtimeMinutes,
  Value<String?> note,
  Value<String?> voidReason,
  Value<String?> replacementShiftId,
  Value<String?> replacedShiftId,
  required int createdAtUtcMicros,
  required int updatedAtUtcMicros,
  required int revision,
  Value<int> rowid,
});
typedef $$WorkShiftsTableUpdateCompanionBuilder = WorkShiftsCompanion Function({
  Value<String> id,
  Value<String> employmentId,
  Value<String?> agreementId,
  Value<String> state,
  Value<int> startUtcMicros,
  Value<int?> endUtcMicros,
  Value<String> timezoneId,
  Value<String> localStartDate,
  Value<int> overtimeMinutes,
  Value<String?> note,
  Value<String?> voidReason,
  Value<String?> replacementShiftId,
  Value<String?> replacedShiftId,
  Value<int> createdAtUtcMicros,
  Value<int> updatedAtUtcMicros,
  Value<int> revision,
  Value<int> rowid,
});

final class $$WorkShiftsTableReferences
    extends BaseReferences<_$AppDatabase, $WorkShiftsTable, WorkShift> {
  $$WorkShiftsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $EmploymentsTable _employmentIdTable(_$AppDatabase db) =>
      db.employments.createAlias('work_shifts__employment_id__employments__id');

  $$EmploymentsTableProcessedTableManager get employmentId {
    final $_column = $_itemColumn<String>('employment_id')!;

    final manager = $$EmploymentsTableTableManager(
      $_db,
      $_db.employments,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_employmentIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $PayAgreementsTable _agreementIdTable(_$AppDatabase db) => db
      .payAgreements
      .createAlias('work_shifts__agreement_id__pay_agreements__id');

  $$PayAgreementsTableProcessedTableManager? get agreementId {
    final $_column = $_itemColumn<String>('agreement_id');
    if ($_column == null) return null;
    final manager = $$PayAgreementsTableTableManager(
      $_db,
      $_db.payAgreements,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_agreementIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $WorkShiftsTable _replacementShiftIdTable(_$AppDatabase db) => db
      .workShifts
      .createAlias('work_shifts__replacement_shift_id__work_shifts__id');

  $$WorkShiftsTableProcessedTableManager? get replacementShiftId {
    final $_column = $_itemColumn<String>('replacement_shift_id');
    if ($_column == null) return null;
    final manager = $$WorkShiftsTableTableManager(
      $_db,
      $_db.workShifts,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_replacementShiftIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $WorkShiftsTable _replacedShiftIdTable(_$AppDatabase db) => db
      .workShifts
      .createAlias('work_shifts__replaced_shift_id__work_shifts__id');

  $$WorkShiftsTableProcessedTableManager? get replacedShiftId {
    final $_column = $_itemColumn<String>('replaced_shift_id');
    if ($_column == null) return null;
    final manager = $$WorkShiftsTableTableManager(
      $_db,
      $_db.workShifts,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_replacedShiftIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$ShiftBreaksTable, List<ShiftBreak>>
  _shiftBreaksRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.shiftBreaks,
    aliasName: 'work_shifts__id__shift_breaks__shift_id',
  );

  $$ShiftBreaksTableProcessedTableManager get shiftBreaksRefs {
    final manager = $$ShiftBreaksTableTableManager(
      $_db,
      $_db.shiftBreaks,
    ).filter((f) => f.shiftId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_shiftBreaksRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$WorkShiftsTableFilterComposer
    extends Composer<_$AppDatabase, $WorkShiftsTable> {
  $$WorkShiftsTableFilterComposer({
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

  ColumnFilters<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startUtcMicros => $composableBuilder(
    column: $table.startUtcMicros,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get endUtcMicros => $composableBuilder(
    column: $table.endUtcMicros,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get timezoneId => $composableBuilder(
    column: $table.timezoneId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localStartDate => $composableBuilder(
    column: $table.localStartDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get overtimeMinutes => $composableBuilder(
    column: $table.overtimeMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get voidReason => $composableBuilder(
    column: $table.voidReason,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAtUtcMicros => $composableBuilder(
    column: $table.createdAtUtcMicros,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAtUtcMicros => $composableBuilder(
    column: $table.updatedAtUtcMicros,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnFilters(column),
  );

  $$EmploymentsTableFilterComposer get employmentId {
    final $$EmploymentsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.employmentId,
      referencedTable: $db.employments,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EmploymentsTableFilterComposer(
            $db: $db,
            $table: $db.employments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$PayAgreementsTableFilterComposer get agreementId {
    final $$PayAgreementsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.agreementId,
      referencedTable: $db.payAgreements,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PayAgreementsTableFilterComposer(
            $db: $db,
            $table: $db.payAgreements,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$WorkShiftsTableFilterComposer get replacementShiftId {
    final $$WorkShiftsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.replacementShiftId,
      referencedTable: $db.workShifts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkShiftsTableFilterComposer(
            $db: $db,
            $table: $db.workShifts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$WorkShiftsTableFilterComposer get replacedShiftId {
    final $$WorkShiftsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.replacedShiftId,
      referencedTable: $db.workShifts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkShiftsTableFilterComposer(
            $db: $db,
            $table: $db.workShifts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> shiftBreaksRefs(
    Expression<bool> Function($$ShiftBreaksTableFilterComposer f) f,
  ) {
    final $$ShiftBreaksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.shiftBreaks,
      getReferencedColumn: (t) => t.shiftId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ShiftBreaksTableFilterComposer(
            $db: $db,
            $table: $db.shiftBreaks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$WorkShiftsTableOrderingComposer
    extends Composer<_$AppDatabase, $WorkShiftsTable> {
  $$WorkShiftsTableOrderingComposer({
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

  ColumnOrderings<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startUtcMicros => $composableBuilder(
    column: $table.startUtcMicros,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get endUtcMicros => $composableBuilder(
    column: $table.endUtcMicros,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get timezoneId => $composableBuilder(
    column: $table.timezoneId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localStartDate => $composableBuilder(
    column: $table.localStartDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get overtimeMinutes => $composableBuilder(
    column: $table.overtimeMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get voidReason => $composableBuilder(
    column: $table.voidReason,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAtUtcMicros => $composableBuilder(
    column: $table.createdAtUtcMicros,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAtUtcMicros => $composableBuilder(
    column: $table.updatedAtUtcMicros,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnOrderings(column),
  );

  $$EmploymentsTableOrderingComposer get employmentId {
    final $$EmploymentsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.employmentId,
      referencedTable: $db.employments,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EmploymentsTableOrderingComposer(
            $db: $db,
            $table: $db.employments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$PayAgreementsTableOrderingComposer get agreementId {
    final $$PayAgreementsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.agreementId,
      referencedTable: $db.payAgreements,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PayAgreementsTableOrderingComposer(
            $db: $db,
            $table: $db.payAgreements,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$WorkShiftsTableOrderingComposer get replacementShiftId {
    final $$WorkShiftsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.replacementShiftId,
      referencedTable: $db.workShifts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkShiftsTableOrderingComposer(
            $db: $db,
            $table: $db.workShifts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$WorkShiftsTableOrderingComposer get replacedShiftId {
    final $$WorkShiftsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.replacedShiftId,
      referencedTable: $db.workShifts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkShiftsTableOrderingComposer(
            $db: $db,
            $table: $db.workShifts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$WorkShiftsTableAnnotationComposer
    extends Composer<_$AppDatabase, $WorkShiftsTable> {
  $$WorkShiftsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get state =>
      $composableBuilder(column: $table.state, builder: (column) => column);

  GeneratedColumn<int> get startUtcMicros => $composableBuilder(
    column: $table.startUtcMicros,
    builder: (column) => column,
  );

  GeneratedColumn<int> get endUtcMicros => $composableBuilder(
    column: $table.endUtcMicros,
    builder: (column) => column,
  );

  GeneratedColumn<String> get timezoneId => $composableBuilder(
    column: $table.timezoneId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get localStartDate => $composableBuilder(
    column: $table.localStartDate,
    builder: (column) => column,
  );

  GeneratedColumn<int> get overtimeMinutes => $composableBuilder(
    column: $table.overtimeMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<String> get voidReason => $composableBuilder(
    column: $table.voidReason,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAtUtcMicros => $composableBuilder(
    column: $table.createdAtUtcMicros,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAtUtcMicros => $composableBuilder(
    column: $table.updatedAtUtcMicros,
    builder: (column) => column,
  );

  GeneratedColumn<int> get revision =>
      $composableBuilder(column: $table.revision, builder: (column) => column);

  $$EmploymentsTableAnnotationComposer get employmentId {
    final $$EmploymentsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.employmentId,
      referencedTable: $db.employments,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EmploymentsTableAnnotationComposer(
            $db: $db,
            $table: $db.employments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$PayAgreementsTableAnnotationComposer get agreementId {
    final $$PayAgreementsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.agreementId,
      referencedTable: $db.payAgreements,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PayAgreementsTableAnnotationComposer(
            $db: $db,
            $table: $db.payAgreements,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$WorkShiftsTableAnnotationComposer get replacementShiftId {
    final $$WorkShiftsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.replacementShiftId,
      referencedTable: $db.workShifts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkShiftsTableAnnotationComposer(
            $db: $db,
            $table: $db.workShifts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$WorkShiftsTableAnnotationComposer get replacedShiftId {
    final $$WorkShiftsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.replacedShiftId,
      referencedTable: $db.workShifts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkShiftsTableAnnotationComposer(
            $db: $db,
            $table: $db.workShifts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> shiftBreaksRefs<T extends Object>(
    Expression<T> Function($$ShiftBreaksTableAnnotationComposer a) f,
  ) {
    final $$ShiftBreaksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.shiftBreaks,
      getReferencedColumn: (t) => t.shiftId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ShiftBreaksTableAnnotationComposer(
            $db: $db,
            $table: $db.shiftBreaks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$WorkShiftsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WorkShiftsTable,
          WorkShift,
          $$WorkShiftsTableFilterComposer,
          $$WorkShiftsTableOrderingComposer,
          $$WorkShiftsTableAnnotationComposer,
          $$WorkShiftsTableCreateCompanionBuilder,
          $$WorkShiftsTableUpdateCompanionBuilder,
          (WorkShift, $$WorkShiftsTableReferences),
          WorkShift,
          PrefetchHooks Function({
            bool employmentId,
            bool agreementId,
            bool replacementShiftId,
            bool replacedShiftId,
            bool shiftBreaksRefs,
          })
        > {
  $$WorkShiftsTableTableManager(_$AppDatabase db, $WorkShiftsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WorkShiftsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WorkShiftsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WorkShiftsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> employmentId = const Value.absent(),
                Value<String?> agreementId = const Value.absent(),
                Value<String> state = const Value.absent(),
                Value<int> startUtcMicros = const Value.absent(),
                Value<int?> endUtcMicros = const Value.absent(),
                Value<String> timezoneId = const Value.absent(),
                Value<String> localStartDate = const Value.absent(),
                Value<int> overtimeMinutes = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<String?> voidReason = const Value.absent(),
                Value<String?> replacementShiftId = const Value.absent(),
                Value<String?> replacedShiftId = const Value.absent(),
                Value<int> createdAtUtcMicros = const Value.absent(),
                Value<int> updatedAtUtcMicros = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WorkShiftsCompanion(
                id: id,
                employmentId: employmentId,
                agreementId: agreementId,
                state: state,
                startUtcMicros: startUtcMicros,
                endUtcMicros: endUtcMicros,
                timezoneId: timezoneId,
                localStartDate: localStartDate,
                overtimeMinutes: overtimeMinutes,
                note: note,
                voidReason: voidReason,
                replacementShiftId: replacementShiftId,
                replacedShiftId: replacedShiftId,
                createdAtUtcMicros: createdAtUtcMicros,
                updatedAtUtcMicros: updatedAtUtcMicros,
                revision: revision,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String employmentId,
                Value<String?> agreementId = const Value.absent(),
                required String state,
                required int startUtcMicros,
                Value<int?> endUtcMicros = const Value.absent(),
                required String timezoneId,
                required String localStartDate,
                required int overtimeMinutes,
                Value<String?> note = const Value.absent(),
                Value<String?> voidReason = const Value.absent(),
                Value<String?> replacementShiftId = const Value.absent(),
                Value<String?> replacedShiftId = const Value.absent(),
                required int createdAtUtcMicros,
                required int updatedAtUtcMicros,
                required int revision,
                Value<int> rowid = const Value.absent(),
              }) => WorkShiftsCompanion.insert(
                id: id,
                employmentId: employmentId,
                agreementId: agreementId,
                state: state,
                startUtcMicros: startUtcMicros,
                endUtcMicros: endUtcMicros,
                timezoneId: timezoneId,
                localStartDate: localStartDate,
                overtimeMinutes: overtimeMinutes,
                note: note,
                voidReason: voidReason,
                replacementShiftId: replacementShiftId,
                replacedShiftId: replacedShiftId,
                createdAtUtcMicros: createdAtUtcMicros,
                updatedAtUtcMicros: updatedAtUtcMicros,
                revision: revision,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$WorkShiftsTable, WorkShift>(table),
                  $$WorkShiftsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                employmentId = false,
                agreementId = false,
                replacementShiftId = false,
                replacedShiftId = false,
                shiftBreaksRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (shiftBreaksRefs) db.shiftBreaks,
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
                        if (employmentId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.employmentId,
                            referencedTable: $$WorkShiftsTableReferences
                                ._employmentIdTable(db),
                            referencedColumn: $$WorkShiftsTableReferences
                                ._employmentIdTable(db)
                                .id,
                          ) as T;
                        }
                        if (agreementId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.agreementId,
                            referencedTable: $$WorkShiftsTableReferences
                                ._agreementIdTable(db),
                            referencedColumn: $$WorkShiftsTableReferences
                                ._agreementIdTable(db)
                                .id,
                          ) as T;
                        }
                        if (replacementShiftId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.replacementShiftId,
                            referencedTable: $$WorkShiftsTableReferences
                                ._replacementShiftIdTable(db),
                            referencedColumn: $$WorkShiftsTableReferences
                                ._replacementShiftIdTable(db)
                                .id,
                          ) as T;
                        }
                        if (replacedShiftId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.replacedShiftId,
                            referencedTable: $$WorkShiftsTableReferences
                                ._replacedShiftIdTable(db),
                            referencedColumn: $$WorkShiftsTableReferences
                                ._replacedShiftIdTable(db)
                                .id,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (shiftBreaksRefs)
                        await $_getPrefetchedData<
                          WorkShift,
                          $WorkShiftsTable,
                          ShiftBreak
                        >(
                          currentTable: table,
                          referencedTable: $$WorkShiftsTableReferences
                              ._shiftBreaksRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$WorkShiftsTableReferences(
                                db,
                                table,
                                p0,
                              ).shiftBreaksRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.shiftId == item.id,
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

typedef $$WorkShiftsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WorkShiftsTable,
      WorkShift,
      $$WorkShiftsTableFilterComposer,
      $$WorkShiftsTableOrderingComposer,
      $$WorkShiftsTableAnnotationComposer,
      $$WorkShiftsTableCreateCompanionBuilder,
      $$WorkShiftsTableUpdateCompanionBuilder,
      (WorkShift, $$WorkShiftsTableReferences),
      WorkShift,
      PrefetchHooks Function({
        bool employmentId,
        bool agreementId,
        bool replacementShiftId,
        bool replacedShiftId,
        bool shiftBreaksRefs,
      })
    >;
typedef $$ShiftBreaksTableCreateCompanionBuilder =
    ShiftBreaksCompanion Function({
      required String id,
      required String shiftId,
      required int startUtcMicros,
      Value<int?> endUtcMicros,
      required int createdAtUtcMicros,
      required int updatedAtUtcMicros,
      required int revision,
      Value<int> rowid,
    });
typedef $$ShiftBreaksTableUpdateCompanionBuilder =
    ShiftBreaksCompanion Function({
      Value<String> id,
      Value<String> shiftId,
      Value<int> startUtcMicros,
      Value<int?> endUtcMicros,
      Value<int> createdAtUtcMicros,
      Value<int> updatedAtUtcMicros,
      Value<int> revision,
      Value<int> rowid,
    });

final class $$ShiftBreaksTableReferences
    extends BaseReferences<_$AppDatabase, $ShiftBreaksTable, ShiftBreak> {
  $$ShiftBreaksTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $WorkShiftsTable _shiftIdTable(_$AppDatabase db) =>
      db.workShifts.createAlias('shift_breaks__shift_id__work_shifts__id');

  $$WorkShiftsTableProcessedTableManager get shiftId {
    final $_column = $_itemColumn<String>('shift_id')!;

    final manager = $$WorkShiftsTableTableManager(
      $_db,
      $_db.workShifts,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_shiftIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ShiftBreaksTableFilterComposer
    extends Composer<_$AppDatabase, $ShiftBreaksTable> {
  $$ShiftBreaksTableFilterComposer({
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

  ColumnFilters<int> get startUtcMicros => $composableBuilder(
    column: $table.startUtcMicros,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get endUtcMicros => $composableBuilder(
    column: $table.endUtcMicros,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAtUtcMicros => $composableBuilder(
    column: $table.createdAtUtcMicros,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAtUtcMicros => $composableBuilder(
    column: $table.updatedAtUtcMicros,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnFilters(column),
  );

  $$WorkShiftsTableFilterComposer get shiftId {
    final $$WorkShiftsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.shiftId,
      referencedTable: $db.workShifts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkShiftsTableFilterComposer(
            $db: $db,
            $table: $db.workShifts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ShiftBreaksTableOrderingComposer
    extends Composer<_$AppDatabase, $ShiftBreaksTable> {
  $$ShiftBreaksTableOrderingComposer({
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

  ColumnOrderings<int> get startUtcMicros => $composableBuilder(
    column: $table.startUtcMicros,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get endUtcMicros => $composableBuilder(
    column: $table.endUtcMicros,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAtUtcMicros => $composableBuilder(
    column: $table.createdAtUtcMicros,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAtUtcMicros => $composableBuilder(
    column: $table.updatedAtUtcMicros,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnOrderings(column),
  );

  $$WorkShiftsTableOrderingComposer get shiftId {
    final $$WorkShiftsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.shiftId,
      referencedTable: $db.workShifts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkShiftsTableOrderingComposer(
            $db: $db,
            $table: $db.workShifts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ShiftBreaksTableAnnotationComposer
    extends Composer<_$AppDatabase, $ShiftBreaksTable> {
  $$ShiftBreaksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get startUtcMicros => $composableBuilder(
    column: $table.startUtcMicros,
    builder: (column) => column,
  );

  GeneratedColumn<int> get endUtcMicros => $composableBuilder(
    column: $table.endUtcMicros,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAtUtcMicros => $composableBuilder(
    column: $table.createdAtUtcMicros,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAtUtcMicros => $composableBuilder(
    column: $table.updatedAtUtcMicros,
    builder: (column) => column,
  );

  GeneratedColumn<int> get revision =>
      $composableBuilder(column: $table.revision, builder: (column) => column);

  $$WorkShiftsTableAnnotationComposer get shiftId {
    final $$WorkShiftsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.shiftId,
      referencedTable: $db.workShifts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkShiftsTableAnnotationComposer(
            $db: $db,
            $table: $db.workShifts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ShiftBreaksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ShiftBreaksTable,
          ShiftBreak,
          $$ShiftBreaksTableFilterComposer,
          $$ShiftBreaksTableOrderingComposer,
          $$ShiftBreaksTableAnnotationComposer,
          $$ShiftBreaksTableCreateCompanionBuilder,
          $$ShiftBreaksTableUpdateCompanionBuilder,
          (ShiftBreak, $$ShiftBreaksTableReferences),
          ShiftBreak,
          PrefetchHooks Function({bool shiftId})
        > {
  $$ShiftBreaksTableTableManager(_$AppDatabase db, $ShiftBreaksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ShiftBreaksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ShiftBreaksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ShiftBreaksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> shiftId = const Value.absent(),
                Value<int> startUtcMicros = const Value.absent(),
                Value<int?> endUtcMicros = const Value.absent(),
                Value<int> createdAtUtcMicros = const Value.absent(),
                Value<int> updatedAtUtcMicros = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ShiftBreaksCompanion(
                id: id,
                shiftId: shiftId,
                startUtcMicros: startUtcMicros,
                endUtcMicros: endUtcMicros,
                createdAtUtcMicros: createdAtUtcMicros,
                updatedAtUtcMicros: updatedAtUtcMicros,
                revision: revision,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String shiftId,
                required int startUtcMicros,
                Value<int?> endUtcMicros = const Value.absent(),
                required int createdAtUtcMicros,
                required int updatedAtUtcMicros,
                required int revision,
                Value<int> rowid = const Value.absent(),
              }) => ShiftBreaksCompanion.insert(
                id: id,
                shiftId: shiftId,
                startUtcMicros: startUtcMicros,
                endUtcMicros: endUtcMicros,
                createdAtUtcMicros: createdAtUtcMicros,
                updatedAtUtcMicros: updatedAtUtcMicros,
                revision: revision,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ShiftBreaksTable, ShiftBreak>(table),
                  $$ShiftBreaksTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({shiftId = false}) {
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
                    if (shiftId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.shiftId,
                        referencedTable: $$ShiftBreaksTableReferences
                            ._shiftIdTable(db),
                        referencedColumn: $$ShiftBreaksTableReferences
                            ._shiftIdTable(db)
                            .id,
                      ) as T;
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

typedef $$ShiftBreaksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ShiftBreaksTable,
      ShiftBreak,
      $$ShiftBreaksTableFilterComposer,
      $$ShiftBreaksTableOrderingComposer,
      $$ShiftBreaksTableAnnotationComposer,
      $$ShiftBreaksTableCreateCompanionBuilder,
      $$ShiftBreaksTableUpdateCompanionBuilder,
      (ShiftBreak, $$ShiftBreaksTableReferences),
      ShiftBreak,
      PrefetchHooks Function({bool shiftId})
    >;
typedef $$PayPeriodsTableCreateCompanionBuilder = PayPeriodsCompanion Function({
  required String id,
  required String employmentId,
  required String start,
  required String end,
  Value<String?> label,
  required String state,
  required int createdAtUtcMicros,
  required int updatedAtUtcMicros,
  required int revision,
  Value<int> rowid,
});
typedef $$PayPeriodsTableUpdateCompanionBuilder = PayPeriodsCompanion Function({
  Value<String> id,
  Value<String> employmentId,
  Value<String> start,
  Value<String> end,
  Value<String?> label,
  Value<String> state,
  Value<int> createdAtUtcMicros,
  Value<int> updatedAtUtcMicros,
  Value<int> revision,
  Value<int> rowid,
});

final class $$PayPeriodsTableReferences
    extends BaseReferences<_$AppDatabase, $PayPeriodsTable, PayPeriod> {
  $$PayPeriodsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $EmploymentsTable _employmentIdTable(_$AppDatabase db) =>
      db.employments.createAlias('pay_periods__employment_id__employments__id');

  $$EmploymentsTableProcessedTableManager get employmentId {
    final $_column = $_itemColumn<String>('employment_id')!;

    final manager = $$EmploymentsTableTableManager(
      $_db,
      $_db.employments,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_employmentIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$PayslipsTable, List<Payslip>> _payslipsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.payslips,
    aliasName: 'pay_periods__id__payslips__period_id',
  );

  $$PayslipsTableProcessedTableManager get payslipsRefs {
    final manager = $$PayslipsTableTableManager(
      $_db,
      $_db.payslips,
    ).filter((f) => f.periodId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_payslipsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$PayPeriodsTableFilterComposer
    extends Composer<_$AppDatabase, $PayPeriodsTable> {
  $$PayPeriodsTableFilterComposer({
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

  ColumnFilters<String> get start => $composableBuilder(
    column: $table.start,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get end => $composableBuilder(
    column: $table.end,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAtUtcMicros => $composableBuilder(
    column: $table.createdAtUtcMicros,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAtUtcMicros => $composableBuilder(
    column: $table.updatedAtUtcMicros,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnFilters(column),
  );

  $$EmploymentsTableFilterComposer get employmentId {
    final $$EmploymentsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.employmentId,
      referencedTable: $db.employments,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EmploymentsTableFilterComposer(
            $db: $db,
            $table: $db.employments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> payslipsRefs(
    Expression<bool> Function($$PayslipsTableFilterComposer f) f,
  ) {
    final $$PayslipsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.payslips,
      getReferencedColumn: (t) => t.periodId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PayslipsTableFilterComposer(
            $db: $db,
            $table: $db.payslips,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PayPeriodsTableOrderingComposer
    extends Composer<_$AppDatabase, $PayPeriodsTable> {
  $$PayPeriodsTableOrderingComposer({
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

  ColumnOrderings<String> get start => $composableBuilder(
    column: $table.start,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get end => $composableBuilder(
    column: $table.end,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAtUtcMicros => $composableBuilder(
    column: $table.createdAtUtcMicros,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAtUtcMicros => $composableBuilder(
    column: $table.updatedAtUtcMicros,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnOrderings(column),
  );

  $$EmploymentsTableOrderingComposer get employmentId {
    final $$EmploymentsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.employmentId,
      referencedTable: $db.employments,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EmploymentsTableOrderingComposer(
            $db: $db,
            $table: $db.employments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PayPeriodsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PayPeriodsTable> {
  $$PayPeriodsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get start =>
      $composableBuilder(column: $table.start, builder: (column) => column);

  GeneratedColumn<String> get end =>
      $composableBuilder(column: $table.end, builder: (column) => column);

  GeneratedColumn<String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => column);

  GeneratedColumn<String> get state =>
      $composableBuilder(column: $table.state, builder: (column) => column);

  GeneratedColumn<int> get createdAtUtcMicros => $composableBuilder(
    column: $table.createdAtUtcMicros,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAtUtcMicros => $composableBuilder(
    column: $table.updatedAtUtcMicros,
    builder: (column) => column,
  );

  GeneratedColumn<int> get revision =>
      $composableBuilder(column: $table.revision, builder: (column) => column);

  $$EmploymentsTableAnnotationComposer get employmentId {
    final $$EmploymentsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.employmentId,
      referencedTable: $db.employments,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EmploymentsTableAnnotationComposer(
            $db: $db,
            $table: $db.employments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> payslipsRefs<T extends Object>(
    Expression<T> Function($$PayslipsTableAnnotationComposer a) f,
  ) {
    final $$PayslipsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.payslips,
      getReferencedColumn: (t) => t.periodId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PayslipsTableAnnotationComposer(
            $db: $db,
            $table: $db.payslips,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PayPeriodsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PayPeriodsTable,
          PayPeriod,
          $$PayPeriodsTableFilterComposer,
          $$PayPeriodsTableOrderingComposer,
          $$PayPeriodsTableAnnotationComposer,
          $$PayPeriodsTableCreateCompanionBuilder,
          $$PayPeriodsTableUpdateCompanionBuilder,
          (PayPeriod, $$PayPeriodsTableReferences),
          PayPeriod,
          PrefetchHooks Function({bool employmentId, bool payslipsRefs})
        > {
  $$PayPeriodsTableTableManager(_$AppDatabase db, $PayPeriodsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PayPeriodsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PayPeriodsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PayPeriodsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> employmentId = const Value.absent(),
                Value<String> start = const Value.absent(),
                Value<String> end = const Value.absent(),
                Value<String?> label = const Value.absent(),
                Value<String> state = const Value.absent(),
                Value<int> createdAtUtcMicros = const Value.absent(),
                Value<int> updatedAtUtcMicros = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PayPeriodsCompanion(
                id: id,
                employmentId: employmentId,
                start: start,
                end: end,
                label: label,
                state: state,
                createdAtUtcMicros: createdAtUtcMicros,
                updatedAtUtcMicros: updatedAtUtcMicros,
                revision: revision,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String employmentId,
                required String start,
                required String end,
                Value<String?> label = const Value.absent(),
                required String state,
                required int createdAtUtcMicros,
                required int updatedAtUtcMicros,
                required int revision,
                Value<int> rowid = const Value.absent(),
              }) => PayPeriodsCompanion.insert(
                id: id,
                employmentId: employmentId,
                start: start,
                end: end,
                label: label,
                state: state,
                createdAtUtcMicros: createdAtUtcMicros,
                updatedAtUtcMicros: updatedAtUtcMicros,
                revision: revision,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PayPeriodsTable, PayPeriod>(table),
                  $$PayPeriodsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({employmentId = false, payslipsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [if (payslipsRefs) db.payslips],
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
                        if (employmentId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.employmentId,
                            referencedTable: $$PayPeriodsTableReferences
                                ._employmentIdTable(db),
                            referencedColumn: $$PayPeriodsTableReferences
                                ._employmentIdTable(db)
                                .id,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (payslipsRefs)
                        await $_getPrefetchedData<
                          PayPeriod,
                          $PayPeriodsTable,
                          Payslip
                        >(
                          currentTable: table,
                          referencedTable: $$PayPeriodsTableReferences
                              ._payslipsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$PayPeriodsTableReferences(
                                db,
                                table,
                                p0,
                              ).payslipsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.periodId == item.id,
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

typedef $$PayPeriodsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PayPeriodsTable,
      PayPeriod,
      $$PayPeriodsTableFilterComposer,
      $$PayPeriodsTableOrderingComposer,
      $$PayPeriodsTableAnnotationComposer,
      $$PayPeriodsTableCreateCompanionBuilder,
      $$PayPeriodsTableUpdateCompanionBuilder,
      (PayPeriod, $$PayPeriodsTableReferences),
      PayPeriod,
      PrefetchHooks Function({bool employmentId, bool payslipsRefs})
    >;
typedef $$PayslipsTableCreateCompanionBuilder = PayslipsCompanion Function({
  required String id,
  required String periodId,
  required String issuedDate,
  Value<String?> paidDate,
  required int amountMinorUnits,
  required String currency,
  required String basis,
  Value<int?> grossMinorUnits,
  Value<int?> netMinorUnits,
  Value<int?> deductionMinorUnits,
  Value<String?> reference,
  Value<String?> note,
  required String state,
  Value<String?> voidReason,
  Value<String?> replacementPayslipId,
  Value<String?> replacedPayslipId,
  required int createdAtUtcMicros,
  required int updatedAtUtcMicros,
  required int revision,
  Value<int> rowid,
});
typedef $$PayslipsTableUpdateCompanionBuilder = PayslipsCompanion Function({
  Value<String> id,
  Value<String> periodId,
  Value<String> issuedDate,
  Value<String?> paidDate,
  Value<int> amountMinorUnits,
  Value<String> currency,
  Value<String> basis,
  Value<int?> grossMinorUnits,
  Value<int?> netMinorUnits,
  Value<int?> deductionMinorUnits,
  Value<String?> reference,
  Value<String?> note,
  Value<String> state,
  Value<String?> voidReason,
  Value<String?> replacementPayslipId,
  Value<String?> replacedPayslipId,
  Value<int> createdAtUtcMicros,
  Value<int> updatedAtUtcMicros,
  Value<int> revision,
  Value<int> rowid,
});

final class $$PayslipsTableReferences
    extends BaseReferences<_$AppDatabase, $PayslipsTable, Payslip> {
  $$PayslipsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $PayPeriodsTable _periodIdTable(_$AppDatabase db) =>
      db.payPeriods.createAlias('payslips__period_id__pay_periods__id');

  $$PayPeriodsTableProcessedTableManager get periodId {
    final $_column = $_itemColumn<String>('period_id')!;

    final manager = $$PayPeriodsTableTableManager(
      $_db,
      $_db.payPeriods,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_periodIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $PayslipsTable _replacementPayslipIdTable(_$AppDatabase db) =>
      db.payslips.createAlias('payslips__replacement_payslip_id__payslips__id');

  $$PayslipsTableProcessedTableManager? get replacementPayslipId {
    final $_column = $_itemColumn<String>('replacement_payslip_id');
    if ($_column == null) return null;
    final manager = $$PayslipsTableTableManager(
      $_db,
      $_db.payslips,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(
      _replacementPayslipIdTable($_db),
    );
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $PayslipsTable _replacedPayslipIdTable(_$AppDatabase db) =>
      db.payslips.createAlias('payslips__replaced_payslip_id__payslips__id');

  $$PayslipsTableProcessedTableManager? get replacedPayslipId {
    final $_column = $_itemColumn<String>('replaced_payslip_id');
    if ($_column == null) return null;
    final manager = $$PayslipsTableTableManager(
      $_db,
      $_db.payslips,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_replacedPayslipIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$PayslipsTableFilterComposer
    extends Composer<_$AppDatabase, $PayslipsTable> {
  $$PayslipsTableFilterComposer({
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

  ColumnFilters<String> get issuedDate => $composableBuilder(
    column: $table.issuedDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get paidDate => $composableBuilder(
    column: $table.paidDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get amountMinorUnits => $composableBuilder(
    column: $table.amountMinorUnits,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get basis => $composableBuilder(
    column: $table.basis,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get grossMinorUnits => $composableBuilder(
    column: $table.grossMinorUnits,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get netMinorUnits => $composableBuilder(
    column: $table.netMinorUnits,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deductionMinorUnits => $composableBuilder(
    column: $table.deductionMinorUnits,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reference => $composableBuilder(
    column: $table.reference,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get voidReason => $composableBuilder(
    column: $table.voidReason,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAtUtcMicros => $composableBuilder(
    column: $table.createdAtUtcMicros,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAtUtcMicros => $composableBuilder(
    column: $table.updatedAtUtcMicros,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnFilters(column),
  );

  $$PayPeriodsTableFilterComposer get periodId {
    final $$PayPeriodsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.periodId,
      referencedTable: $db.payPeriods,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PayPeriodsTableFilterComposer(
            $db: $db,
            $table: $db.payPeriods,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$PayslipsTableFilterComposer get replacementPayslipId {
    final $$PayslipsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.replacementPayslipId,
      referencedTable: $db.payslips,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PayslipsTableFilterComposer(
            $db: $db,
            $table: $db.payslips,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$PayslipsTableFilterComposer get replacedPayslipId {
    final $$PayslipsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.replacedPayslipId,
      referencedTable: $db.payslips,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PayslipsTableFilterComposer(
            $db: $db,
            $table: $db.payslips,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PayslipsTableOrderingComposer
    extends Composer<_$AppDatabase, $PayslipsTable> {
  $$PayslipsTableOrderingComposer({
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

  ColumnOrderings<String> get issuedDate => $composableBuilder(
    column: $table.issuedDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get paidDate => $composableBuilder(
    column: $table.paidDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get amountMinorUnits => $composableBuilder(
    column: $table.amountMinorUnits,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get basis => $composableBuilder(
    column: $table.basis,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get grossMinorUnits => $composableBuilder(
    column: $table.grossMinorUnits,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get netMinorUnits => $composableBuilder(
    column: $table.netMinorUnits,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deductionMinorUnits => $composableBuilder(
    column: $table.deductionMinorUnits,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reference => $composableBuilder(
    column: $table.reference,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get voidReason => $composableBuilder(
    column: $table.voidReason,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAtUtcMicros => $composableBuilder(
    column: $table.createdAtUtcMicros,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAtUtcMicros => $composableBuilder(
    column: $table.updatedAtUtcMicros,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnOrderings(column),
  );

  $$PayPeriodsTableOrderingComposer get periodId {
    final $$PayPeriodsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.periodId,
      referencedTable: $db.payPeriods,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PayPeriodsTableOrderingComposer(
            $db: $db,
            $table: $db.payPeriods,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$PayslipsTableOrderingComposer get replacementPayslipId {
    final $$PayslipsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.replacementPayslipId,
      referencedTable: $db.payslips,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PayslipsTableOrderingComposer(
            $db: $db,
            $table: $db.payslips,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$PayslipsTableOrderingComposer get replacedPayslipId {
    final $$PayslipsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.replacedPayslipId,
      referencedTable: $db.payslips,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PayslipsTableOrderingComposer(
            $db: $db,
            $table: $db.payslips,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PayslipsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PayslipsTable> {
  $$PayslipsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get issuedDate => $composableBuilder(
    column: $table.issuedDate,
    builder: (column) => column,
  );

  GeneratedColumn<String> get paidDate =>
      $composableBuilder(column: $table.paidDate, builder: (column) => column);

  GeneratedColumn<int> get amountMinorUnits => $composableBuilder(
    column: $table.amountMinorUnits,
    builder: (column) => column,
  );

  GeneratedColumn<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => column);

  GeneratedColumn<String> get basis =>
      $composableBuilder(column: $table.basis, builder: (column) => column);

  GeneratedColumn<int> get grossMinorUnits => $composableBuilder(
    column: $table.grossMinorUnits,
    builder: (column) => column,
  );

  GeneratedColumn<int> get netMinorUnits => $composableBuilder(
    column: $table.netMinorUnits,
    builder: (column) => column,
  );

  GeneratedColumn<int> get deductionMinorUnits => $composableBuilder(
    column: $table.deductionMinorUnits,
    builder: (column) => column,
  );

  GeneratedColumn<String> get reference =>
      $composableBuilder(column: $table.reference, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<String> get state =>
      $composableBuilder(column: $table.state, builder: (column) => column);

  GeneratedColumn<String> get voidReason => $composableBuilder(
    column: $table.voidReason,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAtUtcMicros => $composableBuilder(
    column: $table.createdAtUtcMicros,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAtUtcMicros => $composableBuilder(
    column: $table.updatedAtUtcMicros,
    builder: (column) => column,
  );

  GeneratedColumn<int> get revision =>
      $composableBuilder(column: $table.revision, builder: (column) => column);

  $$PayPeriodsTableAnnotationComposer get periodId {
    final $$PayPeriodsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.periodId,
      referencedTable: $db.payPeriods,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PayPeriodsTableAnnotationComposer(
            $db: $db,
            $table: $db.payPeriods,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$PayslipsTableAnnotationComposer get replacementPayslipId {
    final $$PayslipsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.replacementPayslipId,
      referencedTable: $db.payslips,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PayslipsTableAnnotationComposer(
            $db: $db,
            $table: $db.payslips,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$PayslipsTableAnnotationComposer get replacedPayslipId {
    final $$PayslipsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.replacedPayslipId,
      referencedTable: $db.payslips,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PayslipsTableAnnotationComposer(
            $db: $db,
            $table: $db.payslips,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PayslipsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PayslipsTable,
          Payslip,
          $$PayslipsTableFilterComposer,
          $$PayslipsTableOrderingComposer,
          $$PayslipsTableAnnotationComposer,
          $$PayslipsTableCreateCompanionBuilder,
          $$PayslipsTableUpdateCompanionBuilder,
          (Payslip, $$PayslipsTableReferences),
          Payslip,
          PrefetchHooks Function({
            bool periodId,
            bool replacementPayslipId,
            bool replacedPayslipId,
          })
        > {
  $$PayslipsTableTableManager(_$AppDatabase db, $PayslipsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PayslipsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PayslipsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PayslipsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> periodId = const Value.absent(),
                Value<String> issuedDate = const Value.absent(),
                Value<String?> paidDate = const Value.absent(),
                Value<int> amountMinorUnits = const Value.absent(),
                Value<String> currency = const Value.absent(),
                Value<String> basis = const Value.absent(),
                Value<int?> grossMinorUnits = const Value.absent(),
                Value<int?> netMinorUnits = const Value.absent(),
                Value<int?> deductionMinorUnits = const Value.absent(),
                Value<String?> reference = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<String> state = const Value.absent(),
                Value<String?> voidReason = const Value.absent(),
                Value<String?> replacementPayslipId = const Value.absent(),
                Value<String?> replacedPayslipId = const Value.absent(),
                Value<int> createdAtUtcMicros = const Value.absent(),
                Value<int> updatedAtUtcMicros = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PayslipsCompanion(
                id: id,
                periodId: periodId,
                issuedDate: issuedDate,
                paidDate: paidDate,
                amountMinorUnits: amountMinorUnits,
                currency: currency,
                basis: basis,
                grossMinorUnits: grossMinorUnits,
                netMinorUnits: netMinorUnits,
                deductionMinorUnits: deductionMinorUnits,
                reference: reference,
                note: note,
                state: state,
                voidReason: voidReason,
                replacementPayslipId: replacementPayslipId,
                replacedPayslipId: replacedPayslipId,
                createdAtUtcMicros: createdAtUtcMicros,
                updatedAtUtcMicros: updatedAtUtcMicros,
                revision: revision,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String periodId,
                required String issuedDate,
                Value<String?> paidDate = const Value.absent(),
                required int amountMinorUnits,
                required String currency,
                required String basis,
                Value<int?> grossMinorUnits = const Value.absent(),
                Value<int?> netMinorUnits = const Value.absent(),
                Value<int?> deductionMinorUnits = const Value.absent(),
                Value<String?> reference = const Value.absent(),
                Value<String?> note = const Value.absent(),
                required String state,
                Value<String?> voidReason = const Value.absent(),
                Value<String?> replacementPayslipId = const Value.absent(),
                Value<String?> replacedPayslipId = const Value.absent(),
                required int createdAtUtcMicros,
                required int updatedAtUtcMicros,
                required int revision,
                Value<int> rowid = const Value.absent(),
              }) => PayslipsCompanion.insert(
                id: id,
                periodId: periodId,
                issuedDate: issuedDate,
                paidDate: paidDate,
                amountMinorUnits: amountMinorUnits,
                currency: currency,
                basis: basis,
                grossMinorUnits: grossMinorUnits,
                netMinorUnits: netMinorUnits,
                deductionMinorUnits: deductionMinorUnits,
                reference: reference,
                note: note,
                state: state,
                voidReason: voidReason,
                replacementPayslipId: replacementPayslipId,
                replacedPayslipId: replacedPayslipId,
                createdAtUtcMicros: createdAtUtcMicros,
                updatedAtUtcMicros: updatedAtUtcMicros,
                revision: revision,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PayslipsTable, Payslip>(table),
                  $$PayslipsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                periodId = false,
                replacementPayslipId = false,
                replacedPayslipId = false,
              }) {
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
                        if (periodId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.periodId,
                            referencedTable: $$PayslipsTableReferences
                                ._periodIdTable(db),
                            referencedColumn: $$PayslipsTableReferences
                                ._periodIdTable(db)
                                .id,
                          ) as T;
                        }
                        if (replacementPayslipId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.replacementPayslipId,
                            referencedTable: $$PayslipsTableReferences
                                ._replacementPayslipIdTable(db),
                            referencedColumn: $$PayslipsTableReferences
                                ._replacementPayslipIdTable(db)
                                .id,
                          ) as T;
                        }
                        if (replacedPayslipId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.replacedPayslipId,
                            referencedTable: $$PayslipsTableReferences
                                ._replacedPayslipIdTable(db),
                            referencedColumn: $$PayslipsTableReferences
                                ._replacedPayslipIdTable(db)
                                .id,
                          ) as T;
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

typedef $$PayslipsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PayslipsTable,
      Payslip,
      $$PayslipsTableFilterComposer,
      $$PayslipsTableOrderingComposer,
      $$PayslipsTableAnnotationComposer,
      $$PayslipsTableCreateCompanionBuilder,
      $$PayslipsTableUpdateCompanionBuilder,
      (Payslip, $$PayslipsTableReferences),
      Payslip,
      PrefetchHooks Function({
        bool periodId,
        bool replacementPayslipId,
        bool replacedPayslipId,
      })
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$CoreMetadataTableTableManager get coreMetadata =>
      $$CoreMetadataTableTableManager(_db, _db.coreMetadata);
  $$EmploymentsTableTableManager get employments =>
      $$EmploymentsTableTableManager(_db, _db.employments);
  $$PayAgreementsTableTableManager get payAgreements =>
      $$PayAgreementsTableTableManager(_db, _db.payAgreements);
  $$WorkShiftsTableTableManager get workShifts =>
      $$WorkShiftsTableTableManager(_db, _db.workShifts);
  $$ShiftBreaksTableTableManager get shiftBreaks =>
      $$ShiftBreaksTableTableManager(_db, _db.shiftBreaks);
  $$PayPeriodsTableTableManager get payPeriods =>
      $$PayPeriodsTableTableManager(_db, _db.payPeriods);
  $$PayslipsTableTableManager get payslips =>
      $$PayslipsTableTableManager(_db, _db.payslips);
}
