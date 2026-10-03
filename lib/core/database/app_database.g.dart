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
  static const VerificationMeta _nightEnabledMeta = const VerificationMeta(
    'nightEnabled',
  );
  @override
  late final GeneratedColumn<bool> nightEnabled = GeneratedColumn<bool>(
    'night_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("night_enabled" IN (0, 1))',
    ),
  );
  static const VerificationMeta _nightStartMinuteMeta = const VerificationMeta(
    'nightStartMinute',
  );
  @override
  late final GeneratedColumn<int> nightStartMinute = GeneratedColumn<int>(
    'night_start_minute',
    aliasedName,
    false,
    check: () =>
        const CustomExpression<bool>('night_start_minute BETWEEN 0 AND 1439'),
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nightEndMinuteMeta = const VerificationMeta(
    'nightEndMinute',
  );
  @override
  late final GeneratedColumn<int> nightEndMinute = GeneratedColumn<int>(
    'night_end_minute',
    aliasedName,
    false,
    check: () =>
        const CustomExpression<bool>('night_end_minute BETWEEN 0 AND 1439'),
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nightMultiplierNumeratorMeta =
      const VerificationMeta('nightMultiplierNumerator');
  @override
  late final GeneratedColumn<int> nightMultiplierNumerator =
      GeneratedColumn<int>(
        'night_multiplier_numerator',
        aliasedName,
        false,
        check: () =>
            const CustomExpression<bool>('night_multiplier_numerator > 0'),
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _nightMultiplierDenominatorMeta =
      const VerificationMeta('nightMultiplierDenominator');
  @override
  late final GeneratedColumn<int> nightMultiplierDenominator =
      GeneratedColumn<int>(
        'night_multiplier_denominator',
        aliasedName,
        false,
        check: () =>
            const CustomExpression<bool>('night_multiplier_denominator > 0'),
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _holidayCalendarMeta = const VerificationMeta(
    'holidayCalendar',
  );
  @override
  late final GeneratedColumn<String> holidayCalendar = GeneratedColumn<String>(
    'holiday_calendar',
    aliasedName,
    false,
    check: () => const CustomExpression<bool>(
      "holiday_calendar IN ('none', 'lithuania')",
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _holidayMultiplierNumeratorMeta =
      const VerificationMeta('holidayMultiplierNumerator');
  @override
  late final GeneratedColumn<int> holidayMultiplierNumerator =
      GeneratedColumn<int>(
        'holiday_multiplier_numerator',
        aliasedName,
        false,
        check: () =>
            const CustomExpression<bool>('holiday_multiplier_numerator > 0'),
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _holidayMultiplierDenominatorMeta =
      const VerificationMeta('holidayMultiplierDenominator');
  @override
  late final GeneratedColumn<int> holidayMultiplierDenominator =
      GeneratedColumn<int>(
        'holiday_multiplier_denominator',
        aliasedName,
        false,
        check: () =>
            const CustomExpression<bool>('holiday_multiplier_denominator > 0'),
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _premiumStackingMeta = const VerificationMeta(
    'premiumStacking',
  );
  @override
  late final GeneratedColumn<String> premiumStacking = GeneratedColumn<String>(
    'premium_stacking',
    aliasedName,
    false,
    check: () => const CustomExpression<bool>(
      "premium_stacking IN ('highest', 'additive', 'multiplicative')",
    ),
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
  static const VerificationMeta _vacationPayNumeratorMeta =
      const VerificationMeta('vacationPayNumerator');
  @override
  late final GeneratedColumn<int> vacationPayNumerator = GeneratedColumn<int>(
    'vacation_pay_numerator',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _vacationPayDenominatorMeta =
      const VerificationMeta('vacationPayDenominator');
  @override
  late final GeneratedColumn<int> vacationPayDenominator = GeneratedColumn<int>(
    'vacation_pay_denominator',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _sickPayNumeratorMeta = const VerificationMeta(
    'sickPayNumerator',
  );
  @override
  late final GeneratedColumn<int> sickPayNumerator = GeneratedColumn<int>(
    'sick_pay_numerator',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(3103),
  );
  static const VerificationMeta _sickPayDenominatorMeta =
      const VerificationMeta('sickPayDenominator');
  @override
  late final GeneratedColumn<int> sickPayDenominator = GeneratedColumn<int>(
    'sick_pay_denominator',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(5000),
  );
  static const VerificationMeta _sickEmployerDaysMeta = const VerificationMeta(
    'sickEmployerDays',
  );
  @override
  late final GeneratedColumn<int> sickEmployerDays = GeneratedColumn<int>(
    'sick_employer_days',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(2),
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
    nightEnabled,
    nightStartMinute,
    nightEndMinute,
    nightMultiplierNumerator,
    nightMultiplierDenominator,
    holidayCalendar,
    holidayMultiplierNumerator,
    holidayMultiplierDenominator,
    premiumStacking,
    label,
    note,
    createdAtUtcMicros,
    revision,
    vacationPayNumerator,
    vacationPayDenominator,
    sickPayNumerator,
    sickPayDenominator,
    sickEmployerDays,
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
    if (data.containsKey('night_enabled')) {
      context.handle(
        _nightEnabledMeta,
        nightEnabled.isAcceptableOrUnknown(
          data['night_enabled']!,
          _nightEnabledMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_nightEnabledMeta);
    }
    if (data.containsKey('night_start_minute')) {
      context.handle(
        _nightStartMinuteMeta,
        nightStartMinute.isAcceptableOrUnknown(
          data['night_start_minute']!,
          _nightStartMinuteMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_nightStartMinuteMeta);
    }
    if (data.containsKey('night_end_minute')) {
      context.handle(
        _nightEndMinuteMeta,
        nightEndMinute.isAcceptableOrUnknown(
          data['night_end_minute']!,
          _nightEndMinuteMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_nightEndMinuteMeta);
    }
    if (data.containsKey('night_multiplier_numerator')) {
      context.handle(
        _nightMultiplierNumeratorMeta,
        nightMultiplierNumerator.isAcceptableOrUnknown(
          data['night_multiplier_numerator']!,
          _nightMultiplierNumeratorMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_nightMultiplierNumeratorMeta);
    }
    if (data.containsKey('night_multiplier_denominator')) {
      context.handle(
        _nightMultiplierDenominatorMeta,
        nightMultiplierDenominator.isAcceptableOrUnknown(
          data['night_multiplier_denominator']!,
          _nightMultiplierDenominatorMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_nightMultiplierDenominatorMeta);
    }
    if (data.containsKey('holiday_calendar')) {
      context.handle(
        _holidayCalendarMeta,
        holidayCalendar.isAcceptableOrUnknown(
          data['holiday_calendar']!,
          _holidayCalendarMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_holidayCalendarMeta);
    }
    if (data.containsKey('holiday_multiplier_numerator')) {
      context.handle(
        _holidayMultiplierNumeratorMeta,
        holidayMultiplierNumerator.isAcceptableOrUnknown(
          data['holiday_multiplier_numerator']!,
          _holidayMultiplierNumeratorMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_holidayMultiplierNumeratorMeta);
    }
    if (data.containsKey('holiday_multiplier_denominator')) {
      context.handle(
        _holidayMultiplierDenominatorMeta,
        holidayMultiplierDenominator.isAcceptableOrUnknown(
          data['holiday_multiplier_denominator']!,
          _holidayMultiplierDenominatorMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_holidayMultiplierDenominatorMeta);
    }
    if (data.containsKey('premium_stacking')) {
      context.handle(
        _premiumStackingMeta,
        premiumStacking.isAcceptableOrUnknown(
          data['premium_stacking']!,
          _premiumStackingMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_premiumStackingMeta);
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
    if (data.containsKey('vacation_pay_numerator')) {
      context.handle(
        _vacationPayNumeratorMeta,
        vacationPayNumerator.isAcceptableOrUnknown(
          data['vacation_pay_numerator']!,
          _vacationPayNumeratorMeta,
        ),
      );
    }
    if (data.containsKey('vacation_pay_denominator')) {
      context.handle(
        _vacationPayDenominatorMeta,
        vacationPayDenominator.isAcceptableOrUnknown(
          data['vacation_pay_denominator']!,
          _vacationPayDenominatorMeta,
        ),
      );
    }
    if (data.containsKey('sick_pay_numerator')) {
      context.handle(
        _sickPayNumeratorMeta,
        sickPayNumerator.isAcceptableOrUnknown(
          data['sick_pay_numerator']!,
          _sickPayNumeratorMeta,
        ),
      );
    }
    if (data.containsKey('sick_pay_denominator')) {
      context.handle(
        _sickPayDenominatorMeta,
        sickPayDenominator.isAcceptableOrUnknown(
          data['sick_pay_denominator']!,
          _sickPayDenominatorMeta,
        ),
      );
    }
    if (data.containsKey('sick_employer_days')) {
      context.handle(
        _sickEmployerDaysMeta,
        sickEmployerDays.isAcceptableOrUnknown(
          data['sick_employer_days']!,
          _sickEmployerDaysMeta,
        ),
      );
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
      nightEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}night_enabled'],
      )!,
      nightStartMinute: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}night_start_minute'],
      )!,
      nightEndMinute: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}night_end_minute'],
      )!,
      nightMultiplierNumerator: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}night_multiplier_numerator'],
      )!,
      nightMultiplierDenominator: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}night_multiplier_denominator'],
      )!,
      holidayCalendar: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}holiday_calendar'],
      )!,
      holidayMultiplierNumerator: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}holiday_multiplier_numerator'],
      )!,
      holidayMultiplierDenominator: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}holiday_multiplier_denominator'],
      )!,
      premiumStacking: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}premium_stacking'],
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
      vacationPayNumerator: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}vacation_pay_numerator'],
      )!,
      vacationPayDenominator: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}vacation_pay_denominator'],
      )!,
      sickPayNumerator: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sick_pay_numerator'],
      )!,
      sickPayDenominator: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sick_pay_denominator'],
      )!,
      sickEmployerDays: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sick_employer_days'],
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
  final bool nightEnabled;
  final int nightStartMinute;
  final int nightEndMinute;
  final int nightMultiplierNumerator;
  final int nightMultiplierDenominator;
  final String holidayCalendar;
  final int holidayMultiplierNumerator;
  final int holidayMultiplierDenominator;
  final String premiumStacking;
  final String? label;
  final String? note;
  final int createdAtUtcMicros;
  final int revision;
  final int vacationPayNumerator;
  final int vacationPayDenominator;
  final int sickPayNumerator;
  final int sickPayDenominator;
  final int sickEmployerDays;
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
    required this.nightEnabled,
    required this.nightStartMinute,
    required this.nightEndMinute,
    required this.nightMultiplierNumerator,
    required this.nightMultiplierDenominator,
    required this.holidayCalendar,
    required this.holidayMultiplierNumerator,
    required this.holidayMultiplierDenominator,
    required this.premiumStacking,
    this.label,
    this.note,
    required this.createdAtUtcMicros,
    required this.revision,
    required this.vacationPayNumerator,
    required this.vacationPayDenominator,
    required this.sickPayNumerator,
    required this.sickPayDenominator,
    required this.sickEmployerDays,
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
    map['night_enabled'] = Variable<bool>(nightEnabled);
    map['night_start_minute'] = Variable<int>(nightStartMinute);
    map['night_end_minute'] = Variable<int>(nightEndMinute);
    map['night_multiplier_numerator'] = Variable<int>(nightMultiplierNumerator);
    map['night_multiplier_denominator'] = Variable<int>(
      nightMultiplierDenominator,
    );
    map['holiday_calendar'] = Variable<String>(holidayCalendar);
    map['holiday_multiplier_numerator'] = Variable<int>(
      holidayMultiplierNumerator,
    );
    map['holiday_multiplier_denominator'] = Variable<int>(
      holidayMultiplierDenominator,
    );
    map['premium_stacking'] = Variable<String>(premiumStacking);
    if (!nullToAbsent || label != null) {
      map['label'] = Variable<String>(label);
    }
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    map['created_at_utc_micros'] = Variable<int>(createdAtUtcMicros);
    map['revision'] = Variable<int>(revision);
    map['vacation_pay_numerator'] = Variable<int>(vacationPayNumerator);
    map['vacation_pay_denominator'] = Variable<int>(vacationPayDenominator);
    map['sick_pay_numerator'] = Variable<int>(sickPayNumerator);
    map['sick_pay_denominator'] = Variable<int>(sickPayDenominator);
    map['sick_employer_days'] = Variable<int>(sickEmployerDays);
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
      nightEnabled: Value(nightEnabled),
      nightStartMinute: Value(nightStartMinute),
      nightEndMinute: Value(nightEndMinute),
      nightMultiplierNumerator: Value(nightMultiplierNumerator),
      nightMultiplierDenominator: Value(nightMultiplierDenominator),
      holidayCalendar: Value(holidayCalendar),
      holidayMultiplierNumerator: Value(holidayMultiplierNumerator),
      holidayMultiplierDenominator: Value(holidayMultiplierDenominator),
      premiumStacking: Value(premiumStacking),
      label: label == null && nullToAbsent
          ? const Value.absent()
          : Value(label),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      createdAtUtcMicros: Value(createdAtUtcMicros),
      revision: Value(revision),
      vacationPayNumerator: Value(vacationPayNumerator),
      vacationPayDenominator: Value(vacationPayDenominator),
      sickPayNumerator: Value(sickPayNumerator),
      sickPayDenominator: Value(sickPayDenominator),
      sickEmployerDays: Value(sickEmployerDays),
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
      nightEnabled: serializer.fromJson<bool>(json['nightEnabled']),
      nightStartMinute: serializer.fromJson<int>(json['nightStartMinute']),
      nightEndMinute: serializer.fromJson<int>(json['nightEndMinute']),
      nightMultiplierNumerator: serializer.fromJson<int>(
        json['nightMultiplierNumerator'],
      ),
      nightMultiplierDenominator: serializer.fromJson<int>(
        json['nightMultiplierDenominator'],
      ),
      holidayCalendar: serializer.fromJson<String>(json['holidayCalendar']),
      holidayMultiplierNumerator: serializer.fromJson<int>(
        json['holidayMultiplierNumerator'],
      ),
      holidayMultiplierDenominator: serializer.fromJson<int>(
        json['holidayMultiplierDenominator'],
      ),
      premiumStacking: serializer.fromJson<String>(json['premiumStacking']),
      label: serializer.fromJson<String?>(json['label']),
      note: serializer.fromJson<String?>(json['note']),
      createdAtUtcMicros: serializer.fromJson<int>(json['createdAtUtcMicros']),
      revision: serializer.fromJson<int>(json['revision']),
      vacationPayNumerator: serializer.fromJson<int>(
        json['vacationPayNumerator'],
      ),
      vacationPayDenominator: serializer.fromJson<int>(
        json['vacationPayDenominator'],
      ),
      sickPayNumerator: serializer.fromJson<int>(json['sickPayNumerator']),
      sickPayDenominator: serializer.fromJson<int>(json['sickPayDenominator']),
      sickEmployerDays: serializer.fromJson<int>(json['sickEmployerDays']),
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
      'nightEnabled': serializer.toJson<bool>(nightEnabled),
      'nightStartMinute': serializer.toJson<int>(nightStartMinute),
      'nightEndMinute': serializer.toJson<int>(nightEndMinute),
      'nightMultiplierNumerator': serializer.toJson<int>(
        nightMultiplierNumerator,
      ),
      'nightMultiplierDenominator': serializer.toJson<int>(
        nightMultiplierDenominator,
      ),
      'holidayCalendar': serializer.toJson<String>(holidayCalendar),
      'holidayMultiplierNumerator': serializer.toJson<int>(
        holidayMultiplierNumerator,
      ),
      'holidayMultiplierDenominator': serializer.toJson<int>(
        holidayMultiplierDenominator,
      ),
      'premiumStacking': serializer.toJson<String>(premiumStacking),
      'label': serializer.toJson<String?>(label),
      'note': serializer.toJson<String?>(note),
      'createdAtUtcMicros': serializer.toJson<int>(createdAtUtcMicros),
      'revision': serializer.toJson<int>(revision),
      'vacationPayNumerator': serializer.toJson<int>(vacationPayNumerator),
      'vacationPayDenominator': serializer.toJson<int>(vacationPayDenominator),
      'sickPayNumerator': serializer.toJson<int>(sickPayNumerator),
      'sickPayDenominator': serializer.toJson<int>(sickPayDenominator),
      'sickEmployerDays': serializer.toJson<int>(sickEmployerDays),
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
    bool? nightEnabled,
    int? nightStartMinute,
    int? nightEndMinute,
    int? nightMultiplierNumerator,
    int? nightMultiplierDenominator,
    String? holidayCalendar,
    int? holidayMultiplierNumerator,
    int? holidayMultiplierDenominator,
    String? premiumStacking,
    Value<String?> label = const Value.absent(),
    Value<String?> note = const Value.absent(),
    int? createdAtUtcMicros,
    int? revision,
    int? vacationPayNumerator,
    int? vacationPayDenominator,
    int? sickPayNumerator,
    int? sickPayDenominator,
    int? sickEmployerDays,
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
    nightEnabled: nightEnabled ?? this.nightEnabled,
    nightStartMinute: nightStartMinute ?? this.nightStartMinute,
    nightEndMinute: nightEndMinute ?? this.nightEndMinute,
    nightMultiplierNumerator:
        nightMultiplierNumerator ?? this.nightMultiplierNumerator,
    nightMultiplierDenominator:
        nightMultiplierDenominator ?? this.nightMultiplierDenominator,
    holidayCalendar: holidayCalendar ?? this.holidayCalendar,
    holidayMultiplierNumerator:
        holidayMultiplierNumerator ?? this.holidayMultiplierNumerator,
    holidayMultiplierDenominator:
        holidayMultiplierDenominator ?? this.holidayMultiplierDenominator,
    premiumStacking: premiumStacking ?? this.premiumStacking,
    label: label.present ? label.value : this.label,
    note: note.present ? note.value : this.note,
    createdAtUtcMicros: createdAtUtcMicros ?? this.createdAtUtcMicros,
    revision: revision ?? this.revision,
    vacationPayNumerator: vacationPayNumerator ?? this.vacationPayNumerator,
    vacationPayDenominator:
        vacationPayDenominator ?? this.vacationPayDenominator,
    sickPayNumerator: sickPayNumerator ?? this.sickPayNumerator,
    sickPayDenominator: sickPayDenominator ?? this.sickPayDenominator,
    sickEmployerDays: sickEmployerDays ?? this.sickEmployerDays,
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
      nightEnabled: data.nightEnabled.present
          ? data.nightEnabled.value
          : this.nightEnabled,
      nightStartMinute: data.nightStartMinute.present
          ? data.nightStartMinute.value
          : this.nightStartMinute,
      nightEndMinute: data.nightEndMinute.present
          ? data.nightEndMinute.value
          : this.nightEndMinute,
      nightMultiplierNumerator: data.nightMultiplierNumerator.present
          ? data.nightMultiplierNumerator.value
          : this.nightMultiplierNumerator,
      nightMultiplierDenominator: data.nightMultiplierDenominator.present
          ? data.nightMultiplierDenominator.value
          : this.nightMultiplierDenominator,
      holidayCalendar: data.holidayCalendar.present
          ? data.holidayCalendar.value
          : this.holidayCalendar,
      holidayMultiplierNumerator: data.holidayMultiplierNumerator.present
          ? data.holidayMultiplierNumerator.value
          : this.holidayMultiplierNumerator,
      holidayMultiplierDenominator: data.holidayMultiplierDenominator.present
          ? data.holidayMultiplierDenominator.value
          : this.holidayMultiplierDenominator,
      premiumStacking: data.premiumStacking.present
          ? data.premiumStacking.value
          : this.premiumStacking,
      label: data.label.present ? data.label.value : this.label,
      note: data.note.present ? data.note.value : this.note,
      createdAtUtcMicros: data.createdAtUtcMicros.present
          ? data.createdAtUtcMicros.value
          : this.createdAtUtcMicros,
      revision: data.revision.present ? data.revision.value : this.revision,
      vacationPayNumerator: data.vacationPayNumerator.present
          ? data.vacationPayNumerator.value
          : this.vacationPayNumerator,
      vacationPayDenominator: data.vacationPayDenominator.present
          ? data.vacationPayDenominator.value
          : this.vacationPayDenominator,
      sickPayNumerator: data.sickPayNumerator.present
          ? data.sickPayNumerator.value
          : this.sickPayNumerator,
      sickPayDenominator: data.sickPayDenominator.present
          ? data.sickPayDenominator.value
          : this.sickPayDenominator,
      sickEmployerDays: data.sickEmployerDays.present
          ? data.sickEmployerDays.value
          : this.sickEmployerDays,
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
          ..write('nightEnabled: $nightEnabled, ')
          ..write('nightStartMinute: $nightStartMinute, ')
          ..write('nightEndMinute: $nightEndMinute, ')
          ..write('nightMultiplierNumerator: $nightMultiplierNumerator, ')
          ..write('nightMultiplierDenominator: $nightMultiplierDenominator, ')
          ..write('holidayCalendar: $holidayCalendar, ')
          ..write('holidayMultiplierNumerator: $holidayMultiplierNumerator, ')
          ..write(
            'holidayMultiplierDenominator: $holidayMultiplierDenominator, ',
          )
          ..write('premiumStacking: $premiumStacking, ')
          ..write('label: $label, ')
          ..write('note: $note, ')
          ..write('createdAtUtcMicros: $createdAtUtcMicros, ')
          ..write('revision: $revision, ')
          ..write('vacationPayNumerator: $vacationPayNumerator, ')
          ..write('vacationPayDenominator: $vacationPayDenominator, ')
          ..write('sickPayNumerator: $sickPayNumerator, ')
          ..write('sickPayDenominator: $sickPayDenominator, ')
          ..write('sickEmployerDays: $sickEmployerDays')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
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
    nightEnabled,
    nightStartMinute,
    nightEndMinute,
    nightMultiplierNumerator,
    nightMultiplierDenominator,
    holidayCalendar,
    holidayMultiplierNumerator,
    holidayMultiplierDenominator,
    premiumStacking,
    label,
    note,
    createdAtUtcMicros,
    revision,
    vacationPayNumerator,
    vacationPayDenominator,
    sickPayNumerator,
    sickPayDenominator,
    sickEmployerDays,
  ]);
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
          other.nightEnabled == this.nightEnabled &&
          other.nightStartMinute == this.nightStartMinute &&
          other.nightEndMinute == this.nightEndMinute &&
          other.nightMultiplierNumerator == this.nightMultiplierNumerator &&
          other.nightMultiplierDenominator == this.nightMultiplierDenominator &&
          other.holidayCalendar == this.holidayCalendar &&
          other.holidayMultiplierNumerator == this.holidayMultiplierNumerator &&
          other.holidayMultiplierDenominator ==
              this.holidayMultiplierDenominator &&
          other.premiumStacking == this.premiumStacking &&
          other.label == this.label &&
          other.note == this.note &&
          other.createdAtUtcMicros == this.createdAtUtcMicros &&
          other.revision == this.revision &&
          other.vacationPayNumerator == this.vacationPayNumerator &&
          other.vacationPayDenominator == this.vacationPayDenominator &&
          other.sickPayNumerator == this.sickPayNumerator &&
          other.sickPayDenominator == this.sickPayDenominator &&
          other.sickEmployerDays == this.sickEmployerDays);
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
  final Value<bool> nightEnabled;
  final Value<int> nightStartMinute;
  final Value<int> nightEndMinute;
  final Value<int> nightMultiplierNumerator;
  final Value<int> nightMultiplierDenominator;
  final Value<String> holidayCalendar;
  final Value<int> holidayMultiplierNumerator;
  final Value<int> holidayMultiplierDenominator;
  final Value<String> premiumStacking;
  final Value<String?> label;
  final Value<String?> note;
  final Value<int> createdAtUtcMicros;
  final Value<int> revision;
  final Value<int> vacationPayNumerator;
  final Value<int> vacationPayDenominator;
  final Value<int> sickPayNumerator;
  final Value<int> sickPayDenominator;
  final Value<int> sickEmployerDays;
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
    this.nightEnabled = const Value.absent(),
    this.nightStartMinute = const Value.absent(),
    this.nightEndMinute = const Value.absent(),
    this.nightMultiplierNumerator = const Value.absent(),
    this.nightMultiplierDenominator = const Value.absent(),
    this.holidayCalendar = const Value.absent(),
    this.holidayMultiplierNumerator = const Value.absent(),
    this.holidayMultiplierDenominator = const Value.absent(),
    this.premiumStacking = const Value.absent(),
    this.label = const Value.absent(),
    this.note = const Value.absent(),
    this.createdAtUtcMicros = const Value.absent(),
    this.revision = const Value.absent(),
    this.vacationPayNumerator = const Value.absent(),
    this.vacationPayDenominator = const Value.absent(),
    this.sickPayNumerator = const Value.absent(),
    this.sickPayDenominator = const Value.absent(),
    this.sickEmployerDays = const Value.absent(),
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
    required bool nightEnabled,
    required int nightStartMinute,
    required int nightEndMinute,
    required int nightMultiplierNumerator,
    required int nightMultiplierDenominator,
    required String holidayCalendar,
    required int holidayMultiplierNumerator,
    required int holidayMultiplierDenominator,
    required String premiumStacking,
    this.label = const Value.absent(),
    this.note = const Value.absent(),
    required int createdAtUtcMicros,
    required int revision,
    this.vacationPayNumerator = const Value.absent(),
    this.vacationPayDenominator = const Value.absent(),
    this.sickPayNumerator = const Value.absent(),
    this.sickPayDenominator = const Value.absent(),
    this.sickEmployerDays = const Value.absent(),
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
       nightEnabled = Value(nightEnabled),
       nightStartMinute = Value(nightStartMinute),
       nightEndMinute = Value(nightEndMinute),
       nightMultiplierNumerator = Value(nightMultiplierNumerator),
       nightMultiplierDenominator = Value(nightMultiplierDenominator),
       holidayCalendar = Value(holidayCalendar),
       holidayMultiplierNumerator = Value(holidayMultiplierNumerator),
       holidayMultiplierDenominator = Value(holidayMultiplierDenominator),
       premiumStacking = Value(premiumStacking),
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
    Expression<bool>? nightEnabled,
    Expression<int>? nightStartMinute,
    Expression<int>? nightEndMinute,
    Expression<int>? nightMultiplierNumerator,
    Expression<int>? nightMultiplierDenominator,
    Expression<String>? holidayCalendar,
    Expression<int>? holidayMultiplierNumerator,
    Expression<int>? holidayMultiplierDenominator,
    Expression<String>? premiumStacking,
    Expression<String>? label,
    Expression<String>? note,
    Expression<int>? createdAtUtcMicros,
    Expression<int>? revision,
    Expression<int>? vacationPayNumerator,
    Expression<int>? vacationPayDenominator,
    Expression<int>? sickPayNumerator,
    Expression<int>? sickPayDenominator,
    Expression<int>? sickEmployerDays,
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
      if (nightEnabled != null) 'night_enabled': nightEnabled,
      if (nightStartMinute != null) 'night_start_minute': nightStartMinute,
      if (nightEndMinute != null) 'night_end_minute': nightEndMinute,
      if (nightMultiplierNumerator != null)
        'night_multiplier_numerator': nightMultiplierNumerator,
      if (nightMultiplierDenominator != null)
        'night_multiplier_denominator': nightMultiplierDenominator,
      if (holidayCalendar != null) 'holiday_calendar': holidayCalendar,
      if (holidayMultiplierNumerator != null)
        'holiday_multiplier_numerator': holidayMultiplierNumerator,
      if (holidayMultiplierDenominator != null)
        'holiday_multiplier_denominator': holidayMultiplierDenominator,
      if (premiumStacking != null) 'premium_stacking': premiumStacking,
      if (label != null) 'label': label,
      if (note != null) 'note': note,
      if (createdAtUtcMicros != null)
        'created_at_utc_micros': createdAtUtcMicros,
      if (revision != null) 'revision': revision,
      if (vacationPayNumerator != null)
        'vacation_pay_numerator': vacationPayNumerator,
      if (vacationPayDenominator != null)
        'vacation_pay_denominator': vacationPayDenominator,
      if (sickPayNumerator != null) 'sick_pay_numerator': sickPayNumerator,
      if (sickPayDenominator != null)
        'sick_pay_denominator': sickPayDenominator,
      if (sickEmployerDays != null) 'sick_employer_days': sickEmployerDays,
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
    Value<bool>? nightEnabled,
    Value<int>? nightStartMinute,
    Value<int>? nightEndMinute,
    Value<int>? nightMultiplierNumerator,
    Value<int>? nightMultiplierDenominator,
    Value<String>? holidayCalendar,
    Value<int>? holidayMultiplierNumerator,
    Value<int>? holidayMultiplierDenominator,
    Value<String>? premiumStacking,
    Value<String?>? label,
    Value<String?>? note,
    Value<int>? createdAtUtcMicros,
    Value<int>? revision,
    Value<int>? vacationPayNumerator,
    Value<int>? vacationPayDenominator,
    Value<int>? sickPayNumerator,
    Value<int>? sickPayDenominator,
    Value<int>? sickEmployerDays,
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
      nightEnabled: nightEnabled ?? this.nightEnabled,
      nightStartMinute: nightStartMinute ?? this.nightStartMinute,
      nightEndMinute: nightEndMinute ?? this.nightEndMinute,
      nightMultiplierNumerator:
          nightMultiplierNumerator ?? this.nightMultiplierNumerator,
      nightMultiplierDenominator:
          nightMultiplierDenominator ?? this.nightMultiplierDenominator,
      holidayCalendar: holidayCalendar ?? this.holidayCalendar,
      holidayMultiplierNumerator:
          holidayMultiplierNumerator ?? this.holidayMultiplierNumerator,
      holidayMultiplierDenominator:
          holidayMultiplierDenominator ?? this.holidayMultiplierDenominator,
      premiumStacking: premiumStacking ?? this.premiumStacking,
      label: label ?? this.label,
      note: note ?? this.note,
      createdAtUtcMicros: createdAtUtcMicros ?? this.createdAtUtcMicros,
      revision: revision ?? this.revision,
      vacationPayNumerator: vacationPayNumerator ?? this.vacationPayNumerator,
      vacationPayDenominator:
          vacationPayDenominator ?? this.vacationPayDenominator,
      sickPayNumerator: sickPayNumerator ?? this.sickPayNumerator,
      sickPayDenominator: sickPayDenominator ?? this.sickPayDenominator,
      sickEmployerDays: sickEmployerDays ?? this.sickEmployerDays,
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
    if (nightEnabled.present) {
      map['night_enabled'] = Variable<bool>(nightEnabled.value);
    }
    if (nightStartMinute.present) {
      map['night_start_minute'] = Variable<int>(nightStartMinute.value);
    }
    if (nightEndMinute.present) {
      map['night_end_minute'] = Variable<int>(nightEndMinute.value);
    }
    if (nightMultiplierNumerator.present) {
      map['night_multiplier_numerator'] = Variable<int>(
        nightMultiplierNumerator.value,
      );
    }
    if (nightMultiplierDenominator.present) {
      map['night_multiplier_denominator'] = Variable<int>(
        nightMultiplierDenominator.value,
      );
    }
    if (holidayCalendar.present) {
      map['holiday_calendar'] = Variable<String>(holidayCalendar.value);
    }
    if (holidayMultiplierNumerator.present) {
      map['holiday_multiplier_numerator'] = Variable<int>(
        holidayMultiplierNumerator.value,
      );
    }
    if (holidayMultiplierDenominator.present) {
      map['holiday_multiplier_denominator'] = Variable<int>(
        holidayMultiplierDenominator.value,
      );
    }
    if (premiumStacking.present) {
      map['premium_stacking'] = Variable<String>(premiumStacking.value);
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
    if (vacationPayNumerator.present) {
      map['vacation_pay_numerator'] = Variable<int>(vacationPayNumerator.value);
    }
    if (vacationPayDenominator.present) {
      map['vacation_pay_denominator'] = Variable<int>(
        vacationPayDenominator.value,
      );
    }
    if (sickPayNumerator.present) {
      map['sick_pay_numerator'] = Variable<int>(sickPayNumerator.value);
    }
    if (sickPayDenominator.present) {
      map['sick_pay_denominator'] = Variable<int>(sickPayDenominator.value);
    }
    if (sickEmployerDays.present) {
      map['sick_employer_days'] = Variable<int>(sickEmployerDays.value);
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
          ..write('nightEnabled: $nightEnabled, ')
          ..write('nightStartMinute: $nightStartMinute, ')
          ..write('nightEndMinute: $nightEndMinute, ')
          ..write('nightMultiplierNumerator: $nightMultiplierNumerator, ')
          ..write('nightMultiplierDenominator: $nightMultiplierDenominator, ')
          ..write('holidayCalendar: $holidayCalendar, ')
          ..write('holidayMultiplierNumerator: $holidayMultiplierNumerator, ')
          ..write(
            'holidayMultiplierDenominator: $holidayMultiplierDenominator, ',
          )
          ..write('premiumStacking: $premiumStacking, ')
          ..write('label: $label, ')
          ..write('note: $note, ')
          ..write('createdAtUtcMicros: $createdAtUtcMicros, ')
          ..write('revision: $revision, ')
          ..write('vacationPayNumerator: $vacationPayNumerator, ')
          ..write('vacationPayDenominator: $vacationPayDenominator, ')
          ..write('sickPayNumerator: $sickPayNumerator, ')
          ..write('sickPayDenominator: $sickPayDenominator, ')
          ..write('sickEmployerDays: $sickEmployerDays, ')
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
  static const VerificationMeta _scheduleIdMeta = const VerificationMeta(
    'scheduleId',
  );
  @override
  late final GeneratedColumn<String> scheduleId = GeneratedColumn<String>(
    'schedule_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _scheduleVersionMeta = const VerificationMeta(
    'scheduleVersion',
  );
  @override
  late final GeneratedColumn<int> scheduleVersion = GeneratedColumn<int>(
    'schedule_version',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _plannedDateMeta = const VerificationMeta(
    'plannedDate',
  );
  @override
  late final GeneratedColumn<String> plannedDate = GeneratedColumn<String>(
    'planned_date',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _plannedStartUtcMicrosMeta =
      const VerificationMeta('plannedStartUtcMicros');
  @override
  late final GeneratedColumn<int> plannedStartUtcMicros = GeneratedColumn<int>(
    'planned_start_utc_micros',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _plannedEndUtcMicrosMeta =
      const VerificationMeta('plannedEndUtcMicros');
  @override
  late final GeneratedColumn<int> plannedEndUtcMicros = GeneratedColumn<int>(
    'planned_end_utc_micros',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isExtraMeta = const VerificationMeta(
    'isExtra',
  );
  @override
  late final GeneratedColumn<bool> isExtra = GeneratedColumn<bool>(
    'is_extra',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_extra" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _extraCountsAsOvertimeMeta =
      const VerificationMeta('extraCountsAsOvertime');
  @override
  late final GeneratedColumn<bool> extraCountsAsOvertime =
      GeneratedColumn<bool>(
        'extra_counts_as_overtime',
        aliasedName,
        false,
        type: DriftSqlType.bool,
        requiredDuringInsert: false,
        defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("extra_counts_as_overtime" IN (0, 1))',
        ),
        defaultValue: const Constant(false),
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
    note,
    voidReason,
    replacementShiftId,
    replacedShiftId,
    createdAtUtcMicros,
    updatedAtUtcMicros,
    revision,
    scheduleId,
    scheduleVersion,
    plannedDate,
    plannedStartUtcMicros,
    plannedEndUtcMicros,
    isExtra,
    extraCountsAsOvertime,
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
    if (data.containsKey('schedule_id')) {
      context.handle(
        _scheduleIdMeta,
        scheduleId.isAcceptableOrUnknown(data['schedule_id']!, _scheduleIdMeta),
      );
    }
    if (data.containsKey('schedule_version')) {
      context.handle(
        _scheduleVersionMeta,
        scheduleVersion.isAcceptableOrUnknown(
          data['schedule_version']!,
          _scheduleVersionMeta,
        ),
      );
    }
    if (data.containsKey('planned_date')) {
      context.handle(
        _plannedDateMeta,
        plannedDate.isAcceptableOrUnknown(
          data['planned_date']!,
          _plannedDateMeta,
        ),
      );
    }
    if (data.containsKey('planned_start_utc_micros')) {
      context.handle(
        _plannedStartUtcMicrosMeta,
        plannedStartUtcMicros.isAcceptableOrUnknown(
          data['planned_start_utc_micros']!,
          _plannedStartUtcMicrosMeta,
        ),
      );
    }
    if (data.containsKey('planned_end_utc_micros')) {
      context.handle(
        _plannedEndUtcMicrosMeta,
        plannedEndUtcMicros.isAcceptableOrUnknown(
          data['planned_end_utc_micros']!,
          _plannedEndUtcMicrosMeta,
        ),
      );
    }
    if (data.containsKey('is_extra')) {
      context.handle(
        _isExtraMeta,
        isExtra.isAcceptableOrUnknown(data['is_extra']!, _isExtraMeta),
      );
    }
    if (data.containsKey('extra_counts_as_overtime')) {
      context.handle(
        _extraCountsAsOvertimeMeta,
        extraCountsAsOvertime.isAcceptableOrUnknown(
          data['extra_counts_as_overtime']!,
          _extraCountsAsOvertimeMeta,
        ),
      );
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
      scheduleId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}schedule_id'],
      ),
      scheduleVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}schedule_version'],
      ),
      plannedDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}planned_date'],
      ),
      plannedStartUtcMicros: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}planned_start_utc_micros'],
      ),
      plannedEndUtcMicros: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}planned_end_utc_micros'],
      ),
      isExtra: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_extra'],
      )!,
      extraCountsAsOvertime: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}extra_counts_as_overtime'],
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
  final String? note;
  final String? voidReason;
  final String? replacementShiftId;
  final String? replacedShiftId;
  final int createdAtUtcMicros;
  final int updatedAtUtcMicros;
  final int revision;

  /// The schedule a confirmed day was planned from (spec 3.6).
  final String? scheduleId;
  final int? scheduleVersion;
  final String? plannedDate;
  final int? plannedStartUtcMicros;
  final int? plannedEndUtcMicros;
  final bool isExtra;
  final bool extraCountsAsOvertime;
  const WorkShift({
    required this.id,
    required this.employmentId,
    this.agreementId,
    required this.state,
    required this.startUtcMicros,
    this.endUtcMicros,
    required this.timezoneId,
    required this.localStartDate,
    this.note,
    this.voidReason,
    this.replacementShiftId,
    this.replacedShiftId,
    required this.createdAtUtcMicros,
    required this.updatedAtUtcMicros,
    required this.revision,
    this.scheduleId,
    this.scheduleVersion,
    this.plannedDate,
    this.plannedStartUtcMicros,
    this.plannedEndUtcMicros,
    required this.isExtra,
    required this.extraCountsAsOvertime,
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
    if (!nullToAbsent || scheduleId != null) {
      map['schedule_id'] = Variable<String>(scheduleId);
    }
    if (!nullToAbsent || scheduleVersion != null) {
      map['schedule_version'] = Variable<int>(scheduleVersion);
    }
    if (!nullToAbsent || plannedDate != null) {
      map['planned_date'] = Variable<String>(plannedDate);
    }
    if (!nullToAbsent || plannedStartUtcMicros != null) {
      map['planned_start_utc_micros'] = Variable<int>(plannedStartUtcMicros);
    }
    if (!nullToAbsent || plannedEndUtcMicros != null) {
      map['planned_end_utc_micros'] = Variable<int>(plannedEndUtcMicros);
    }
    map['is_extra'] = Variable<bool>(isExtra);
    map['extra_counts_as_overtime'] = Variable<bool>(extraCountsAsOvertime);
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
      scheduleId: scheduleId == null && nullToAbsent
          ? const Value.absent()
          : Value(scheduleId),
      scheduleVersion: scheduleVersion == null && nullToAbsent
          ? const Value.absent()
          : Value(scheduleVersion),
      plannedDate: plannedDate == null && nullToAbsent
          ? const Value.absent()
          : Value(plannedDate),
      plannedStartUtcMicros: plannedStartUtcMicros == null && nullToAbsent
          ? const Value.absent()
          : Value(plannedStartUtcMicros),
      plannedEndUtcMicros: plannedEndUtcMicros == null && nullToAbsent
          ? const Value.absent()
          : Value(plannedEndUtcMicros),
      isExtra: Value(isExtra),
      extraCountsAsOvertime: Value(extraCountsAsOvertime),
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
      note: serializer.fromJson<String?>(json['note']),
      voidReason: serializer.fromJson<String?>(json['voidReason']),
      replacementShiftId: serializer.fromJson<String?>(
        json['replacementShiftId'],
      ),
      replacedShiftId: serializer.fromJson<String?>(json['replacedShiftId']),
      createdAtUtcMicros: serializer.fromJson<int>(json['createdAtUtcMicros']),
      updatedAtUtcMicros: serializer.fromJson<int>(json['updatedAtUtcMicros']),
      revision: serializer.fromJson<int>(json['revision']),
      scheduleId: serializer.fromJson<String?>(json['scheduleId']),
      scheduleVersion: serializer.fromJson<int?>(json['scheduleVersion']),
      plannedDate: serializer.fromJson<String?>(json['plannedDate']),
      plannedStartUtcMicros: serializer.fromJson<int?>(
        json['plannedStartUtcMicros'],
      ),
      plannedEndUtcMicros: serializer.fromJson<int?>(
        json['plannedEndUtcMicros'],
      ),
      isExtra: serializer.fromJson<bool>(json['isExtra']),
      extraCountsAsOvertime: serializer.fromJson<bool>(
        json['extraCountsAsOvertime'],
      ),
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
      'note': serializer.toJson<String?>(note),
      'voidReason': serializer.toJson<String?>(voidReason),
      'replacementShiftId': serializer.toJson<String?>(replacementShiftId),
      'replacedShiftId': serializer.toJson<String?>(replacedShiftId),
      'createdAtUtcMicros': serializer.toJson<int>(createdAtUtcMicros),
      'updatedAtUtcMicros': serializer.toJson<int>(updatedAtUtcMicros),
      'revision': serializer.toJson<int>(revision),
      'scheduleId': serializer.toJson<String?>(scheduleId),
      'scheduleVersion': serializer.toJson<int?>(scheduleVersion),
      'plannedDate': serializer.toJson<String?>(plannedDate),
      'plannedStartUtcMicros': serializer.toJson<int?>(plannedStartUtcMicros),
      'plannedEndUtcMicros': serializer.toJson<int?>(plannedEndUtcMicros),
      'isExtra': serializer.toJson<bool>(isExtra),
      'extraCountsAsOvertime': serializer.toJson<bool>(extraCountsAsOvertime),
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
    Value<String?> note = const Value.absent(),
    Value<String?> voidReason = const Value.absent(),
    Value<String?> replacementShiftId = const Value.absent(),
    Value<String?> replacedShiftId = const Value.absent(),
    int? createdAtUtcMicros,
    int? updatedAtUtcMicros,
    int? revision,
    Value<String?> scheduleId = const Value.absent(),
    Value<int?> scheduleVersion = const Value.absent(),
    Value<String?> plannedDate = const Value.absent(),
    Value<int?> plannedStartUtcMicros = const Value.absent(),
    Value<int?> plannedEndUtcMicros = const Value.absent(),
    bool? isExtra,
    bool? extraCountsAsOvertime,
  }) => WorkShift(
    id: id ?? this.id,
    employmentId: employmentId ?? this.employmentId,
    agreementId: agreementId.present ? agreementId.value : this.agreementId,
    state: state ?? this.state,
    startUtcMicros: startUtcMicros ?? this.startUtcMicros,
    endUtcMicros: endUtcMicros.present ? endUtcMicros.value : this.endUtcMicros,
    timezoneId: timezoneId ?? this.timezoneId,
    localStartDate: localStartDate ?? this.localStartDate,
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
    scheduleId: scheduleId.present ? scheduleId.value : this.scheduleId,
    scheduleVersion: scheduleVersion.present
        ? scheduleVersion.value
        : this.scheduleVersion,
    plannedDate: plannedDate.present ? plannedDate.value : this.plannedDate,
    plannedStartUtcMicros: plannedStartUtcMicros.present
        ? plannedStartUtcMicros.value
        : this.plannedStartUtcMicros,
    plannedEndUtcMicros: plannedEndUtcMicros.present
        ? plannedEndUtcMicros.value
        : this.plannedEndUtcMicros,
    isExtra: isExtra ?? this.isExtra,
    extraCountsAsOvertime: extraCountsAsOvertime ?? this.extraCountsAsOvertime,
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
      scheduleId: data.scheduleId.present
          ? data.scheduleId.value
          : this.scheduleId,
      scheduleVersion: data.scheduleVersion.present
          ? data.scheduleVersion.value
          : this.scheduleVersion,
      plannedDate: data.plannedDate.present
          ? data.plannedDate.value
          : this.plannedDate,
      plannedStartUtcMicros: data.plannedStartUtcMicros.present
          ? data.plannedStartUtcMicros.value
          : this.plannedStartUtcMicros,
      plannedEndUtcMicros: data.plannedEndUtcMicros.present
          ? data.plannedEndUtcMicros.value
          : this.plannedEndUtcMicros,
      isExtra: data.isExtra.present ? data.isExtra.value : this.isExtra,
      extraCountsAsOvertime: data.extraCountsAsOvertime.present
          ? data.extraCountsAsOvertime.value
          : this.extraCountsAsOvertime,
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
          ..write('note: $note, ')
          ..write('voidReason: $voidReason, ')
          ..write('replacementShiftId: $replacementShiftId, ')
          ..write('replacedShiftId: $replacedShiftId, ')
          ..write('createdAtUtcMicros: $createdAtUtcMicros, ')
          ..write('updatedAtUtcMicros: $updatedAtUtcMicros, ')
          ..write('revision: $revision, ')
          ..write('scheduleId: $scheduleId, ')
          ..write('scheduleVersion: $scheduleVersion, ')
          ..write('plannedDate: $plannedDate, ')
          ..write('plannedStartUtcMicros: $plannedStartUtcMicros, ')
          ..write('plannedEndUtcMicros: $plannedEndUtcMicros, ')
          ..write('isExtra: $isExtra, ')
          ..write('extraCountsAsOvertime: $extraCountsAsOvertime')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    employmentId,
    agreementId,
    state,
    startUtcMicros,
    endUtcMicros,
    timezoneId,
    localStartDate,
    note,
    voidReason,
    replacementShiftId,
    replacedShiftId,
    createdAtUtcMicros,
    updatedAtUtcMicros,
    revision,
    scheduleId,
    scheduleVersion,
    plannedDate,
    plannedStartUtcMicros,
    plannedEndUtcMicros,
    isExtra,
    extraCountsAsOvertime,
  ]);
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
          other.note == this.note &&
          other.voidReason == this.voidReason &&
          other.replacementShiftId == this.replacementShiftId &&
          other.replacedShiftId == this.replacedShiftId &&
          other.createdAtUtcMicros == this.createdAtUtcMicros &&
          other.updatedAtUtcMicros == this.updatedAtUtcMicros &&
          other.revision == this.revision &&
          other.scheduleId == this.scheduleId &&
          other.scheduleVersion == this.scheduleVersion &&
          other.plannedDate == this.plannedDate &&
          other.plannedStartUtcMicros == this.plannedStartUtcMicros &&
          other.plannedEndUtcMicros == this.plannedEndUtcMicros &&
          other.isExtra == this.isExtra &&
          other.extraCountsAsOvertime == this.extraCountsAsOvertime);
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
  final Value<String?> note;
  final Value<String?> voidReason;
  final Value<String?> replacementShiftId;
  final Value<String?> replacedShiftId;
  final Value<int> createdAtUtcMicros;
  final Value<int> updatedAtUtcMicros;
  final Value<int> revision;
  final Value<String?> scheduleId;
  final Value<int?> scheduleVersion;
  final Value<String?> plannedDate;
  final Value<int?> plannedStartUtcMicros;
  final Value<int?> plannedEndUtcMicros;
  final Value<bool> isExtra;
  final Value<bool> extraCountsAsOvertime;
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
    this.note = const Value.absent(),
    this.voidReason = const Value.absent(),
    this.replacementShiftId = const Value.absent(),
    this.replacedShiftId = const Value.absent(),
    this.createdAtUtcMicros = const Value.absent(),
    this.updatedAtUtcMicros = const Value.absent(),
    this.revision = const Value.absent(),
    this.scheduleId = const Value.absent(),
    this.scheduleVersion = const Value.absent(),
    this.plannedDate = const Value.absent(),
    this.plannedStartUtcMicros = const Value.absent(),
    this.plannedEndUtcMicros = const Value.absent(),
    this.isExtra = const Value.absent(),
    this.extraCountsAsOvertime = const Value.absent(),
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
    this.note = const Value.absent(),
    this.voidReason = const Value.absent(),
    this.replacementShiftId = const Value.absent(),
    this.replacedShiftId = const Value.absent(),
    required int createdAtUtcMicros,
    required int updatedAtUtcMicros,
    required int revision,
    this.scheduleId = const Value.absent(),
    this.scheduleVersion = const Value.absent(),
    this.plannedDate = const Value.absent(),
    this.plannedStartUtcMicros = const Value.absent(),
    this.plannedEndUtcMicros = const Value.absent(),
    this.isExtra = const Value.absent(),
    this.extraCountsAsOvertime = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       employmentId = Value(employmentId),
       state = Value(state),
       startUtcMicros = Value(startUtcMicros),
       timezoneId = Value(timezoneId),
       localStartDate = Value(localStartDate),
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
    Expression<String>? note,
    Expression<String>? voidReason,
    Expression<String>? replacementShiftId,
    Expression<String>? replacedShiftId,
    Expression<int>? createdAtUtcMicros,
    Expression<int>? updatedAtUtcMicros,
    Expression<int>? revision,
    Expression<String>? scheduleId,
    Expression<int>? scheduleVersion,
    Expression<String>? plannedDate,
    Expression<int>? plannedStartUtcMicros,
    Expression<int>? plannedEndUtcMicros,
    Expression<bool>? isExtra,
    Expression<bool>? extraCountsAsOvertime,
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
      if (scheduleId != null) 'schedule_id': scheduleId,
      if (scheduleVersion != null) 'schedule_version': scheduleVersion,
      if (plannedDate != null) 'planned_date': plannedDate,
      if (plannedStartUtcMicros != null)
        'planned_start_utc_micros': plannedStartUtcMicros,
      if (plannedEndUtcMicros != null)
        'planned_end_utc_micros': plannedEndUtcMicros,
      if (isExtra != null) 'is_extra': isExtra,
      if (extraCountsAsOvertime != null)
        'extra_counts_as_overtime': extraCountsAsOvertime,
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
    Value<String?>? note,
    Value<String?>? voidReason,
    Value<String?>? replacementShiftId,
    Value<String?>? replacedShiftId,
    Value<int>? createdAtUtcMicros,
    Value<int>? updatedAtUtcMicros,
    Value<int>? revision,
    Value<String?>? scheduleId,
    Value<int?>? scheduleVersion,
    Value<String?>? plannedDate,
    Value<int?>? plannedStartUtcMicros,
    Value<int?>? plannedEndUtcMicros,
    Value<bool>? isExtra,
    Value<bool>? extraCountsAsOvertime,
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
      note: note ?? this.note,
      voidReason: voidReason ?? this.voidReason,
      replacementShiftId: replacementShiftId ?? this.replacementShiftId,
      replacedShiftId: replacedShiftId ?? this.replacedShiftId,
      createdAtUtcMicros: createdAtUtcMicros ?? this.createdAtUtcMicros,
      updatedAtUtcMicros: updatedAtUtcMicros ?? this.updatedAtUtcMicros,
      revision: revision ?? this.revision,
      scheduleId: scheduleId ?? this.scheduleId,
      scheduleVersion: scheduleVersion ?? this.scheduleVersion,
      plannedDate: plannedDate ?? this.plannedDate,
      plannedStartUtcMicros:
          plannedStartUtcMicros ?? this.plannedStartUtcMicros,
      plannedEndUtcMicros: plannedEndUtcMicros ?? this.plannedEndUtcMicros,
      isExtra: isExtra ?? this.isExtra,
      extraCountsAsOvertime:
          extraCountsAsOvertime ?? this.extraCountsAsOvertime,
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
    if (scheduleId.present) {
      map['schedule_id'] = Variable<String>(scheduleId.value);
    }
    if (scheduleVersion.present) {
      map['schedule_version'] = Variable<int>(scheduleVersion.value);
    }
    if (plannedDate.present) {
      map['planned_date'] = Variable<String>(plannedDate.value);
    }
    if (plannedStartUtcMicros.present) {
      map['planned_start_utc_micros'] = Variable<int>(
        plannedStartUtcMicros.value,
      );
    }
    if (plannedEndUtcMicros.present) {
      map['planned_end_utc_micros'] = Variable<int>(plannedEndUtcMicros.value);
    }
    if (isExtra.present) {
      map['is_extra'] = Variable<bool>(isExtra.value);
    }
    if (extraCountsAsOvertime.present) {
      map['extra_counts_as_overtime'] = Variable<bool>(
        extraCountsAsOvertime.value,
      );
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
          ..write('note: $note, ')
          ..write('voidReason: $voidReason, ')
          ..write('replacementShiftId: $replacementShiftId, ')
          ..write('replacedShiftId: $replacedShiftId, ')
          ..write('createdAtUtcMicros: $createdAtUtcMicros, ')
          ..write('updatedAtUtcMicros: $updatedAtUtcMicros, ')
          ..write('revision: $revision, ')
          ..write('scheduleId: $scheduleId, ')
          ..write('scheduleVersion: $scheduleVersion, ')
          ..write('plannedDate: $plannedDate, ')
          ..write('plannedStartUtcMicros: $plannedStartUtcMicros, ')
          ..write('plannedEndUtcMicros: $plannedEndUtcMicros, ')
          ..write('isExtra: $isExtra, ')
          ..write('extraCountsAsOvertime: $extraCountsAsOvertime, ')
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

class $WorkSchedulesTable extends WorkSchedules
    with TableInfo<$WorkSchedulesTable, WorkSchedule> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WorkSchedulesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
  static const VerificationMeta _cycleStartMeta = const VerificationMeta(
    'cycleStart',
  );
  @override
  late final GeneratedColumn<String> cycleStart = GeneratedColumn<String>(
    'cycle_start',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _inUseFromMeta = const VerificationMeta(
    'inUseFrom',
  );
  @override
  late final GeneratedColumn<String> inUseFrom = GeneratedColumn<String>(
    'in_use_from',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _inUseUntilMeta = const VerificationMeta(
    'inUseUntil',
  );
  @override
  late final GeneratedColumn<String> inUseUntil = GeneratedColumn<String>(
    'in_use_until',
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
    version,
    employmentId,
    name,
    timezoneId,
    cycleStart,
    inUseFrom,
    inUseUntil,
    createdAtUtcMicros,
    revision,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'work_schedules';
  @override
  VerificationContext validateIntegrity(
    Insertable<WorkSchedule> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    } else if (isInserting) {
      context.missing(_versionMeta);
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
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('timezone_id')) {
      context.handle(
        _timezoneIdMeta,
        timezoneId.isAcceptableOrUnknown(data['timezone_id']!, _timezoneIdMeta),
      );
    } else if (isInserting) {
      context.missing(_timezoneIdMeta);
    }
    if (data.containsKey('cycle_start')) {
      context.handle(
        _cycleStartMeta,
        cycleStart.isAcceptableOrUnknown(data['cycle_start']!, _cycleStartMeta),
      );
    } else if (isInserting) {
      context.missing(_cycleStartMeta);
    }
    if (data.containsKey('in_use_from')) {
      context.handle(
        _inUseFromMeta,
        inUseFrom.isAcceptableOrUnknown(data['in_use_from']!, _inUseFromMeta),
      );
    } else if (isInserting) {
      context.missing(_inUseFromMeta);
    }
    if (data.containsKey('in_use_until')) {
      context.handle(
        _inUseUntilMeta,
        inUseUntil.isAcceptableOrUnknown(
          data['in_use_until']!,
          _inUseUntilMeta,
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
  Set<GeneratedColumn> get $primaryKey => {id, version};
  @override
  WorkSchedule map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WorkSchedule(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
      employmentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}employment_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      timezoneId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}timezone_id'],
      )!,
      cycleStart: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cycle_start'],
      )!,
      inUseFrom: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}in_use_from'],
      )!,
      inUseUntil: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}in_use_until'],
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
  $WorkSchedulesTable createAlias(String alias) {
    return $WorkSchedulesTable(attachedDatabase, alias);
  }
}

class WorkSchedule extends DataClass implements Insertable<WorkSchedule> {
  final String id;
  final int version;
  final String employmentId;
  final String name;
  final String timezoneId;
  final String cycleStart;
  final String inUseFrom;
  final String? inUseUntil;
  final int createdAtUtcMicros;
  final int revision;
  const WorkSchedule({
    required this.id,
    required this.version,
    required this.employmentId,
    required this.name,
    required this.timezoneId,
    required this.cycleStart,
    required this.inUseFrom,
    this.inUseUntil,
    required this.createdAtUtcMicros,
    required this.revision,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['version'] = Variable<int>(version);
    map['employment_id'] = Variable<String>(employmentId);
    map['name'] = Variable<String>(name);
    map['timezone_id'] = Variable<String>(timezoneId);
    map['cycle_start'] = Variable<String>(cycleStart);
    map['in_use_from'] = Variable<String>(inUseFrom);
    if (!nullToAbsent || inUseUntil != null) {
      map['in_use_until'] = Variable<String>(inUseUntil);
    }
    map['created_at_utc_micros'] = Variable<int>(createdAtUtcMicros);
    map['revision'] = Variable<int>(revision);
    return map;
  }

  WorkSchedulesCompanion toCompanion(bool nullToAbsent) {
    return WorkSchedulesCompanion(
      id: Value(id),
      version: Value(version),
      employmentId: Value(employmentId),
      name: Value(name),
      timezoneId: Value(timezoneId),
      cycleStart: Value(cycleStart),
      inUseFrom: Value(inUseFrom),
      inUseUntil: inUseUntil == null && nullToAbsent
          ? const Value.absent()
          : Value(inUseUntil),
      createdAtUtcMicros: Value(createdAtUtcMicros),
      revision: Value(revision),
    );
  }

  factory WorkSchedule.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WorkSchedule(
      id: serializer.fromJson<String>(json['id']),
      version: serializer.fromJson<int>(json['version']),
      employmentId: serializer.fromJson<String>(json['employmentId']),
      name: serializer.fromJson<String>(json['name']),
      timezoneId: serializer.fromJson<String>(json['timezoneId']),
      cycleStart: serializer.fromJson<String>(json['cycleStart']),
      inUseFrom: serializer.fromJson<String>(json['inUseFrom']),
      inUseUntil: serializer.fromJson<String?>(json['inUseUntil']),
      createdAtUtcMicros: serializer.fromJson<int>(json['createdAtUtcMicros']),
      revision: serializer.fromJson<int>(json['revision']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'version': serializer.toJson<int>(version),
      'employmentId': serializer.toJson<String>(employmentId),
      'name': serializer.toJson<String>(name),
      'timezoneId': serializer.toJson<String>(timezoneId),
      'cycleStart': serializer.toJson<String>(cycleStart),
      'inUseFrom': serializer.toJson<String>(inUseFrom),
      'inUseUntil': serializer.toJson<String?>(inUseUntil),
      'createdAtUtcMicros': serializer.toJson<int>(createdAtUtcMicros),
      'revision': serializer.toJson<int>(revision),
    };
  }

  WorkSchedule copyWith({
    String? id,
    int? version,
    String? employmentId,
    String? name,
    String? timezoneId,
    String? cycleStart,
    String? inUseFrom,
    Value<String?> inUseUntil = const Value.absent(),
    int? createdAtUtcMicros,
    int? revision,
  }) => WorkSchedule(
    id: id ?? this.id,
    version: version ?? this.version,
    employmentId: employmentId ?? this.employmentId,
    name: name ?? this.name,
    timezoneId: timezoneId ?? this.timezoneId,
    cycleStart: cycleStart ?? this.cycleStart,
    inUseFrom: inUseFrom ?? this.inUseFrom,
    inUseUntil: inUseUntil.present ? inUseUntil.value : this.inUseUntil,
    createdAtUtcMicros: createdAtUtcMicros ?? this.createdAtUtcMicros,
    revision: revision ?? this.revision,
  );
  WorkSchedule copyWithCompanion(WorkSchedulesCompanion data) {
    return WorkSchedule(
      id: data.id.present ? data.id.value : this.id,
      version: data.version.present ? data.version.value : this.version,
      employmentId: data.employmentId.present
          ? data.employmentId.value
          : this.employmentId,
      name: data.name.present ? data.name.value : this.name,
      timezoneId: data.timezoneId.present
          ? data.timezoneId.value
          : this.timezoneId,
      cycleStart: data.cycleStart.present
          ? data.cycleStart.value
          : this.cycleStart,
      inUseFrom: data.inUseFrom.present ? data.inUseFrom.value : this.inUseFrom,
      inUseUntil: data.inUseUntil.present
          ? data.inUseUntil.value
          : this.inUseUntil,
      createdAtUtcMicros: data.createdAtUtcMicros.present
          ? data.createdAtUtcMicros.value
          : this.createdAtUtcMicros,
      revision: data.revision.present ? data.revision.value : this.revision,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WorkSchedule(')
          ..write('id: $id, ')
          ..write('version: $version, ')
          ..write('employmentId: $employmentId, ')
          ..write('name: $name, ')
          ..write('timezoneId: $timezoneId, ')
          ..write('cycleStart: $cycleStart, ')
          ..write('inUseFrom: $inUseFrom, ')
          ..write('inUseUntil: $inUseUntil, ')
          ..write('createdAtUtcMicros: $createdAtUtcMicros, ')
          ..write('revision: $revision')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    version,
    employmentId,
    name,
    timezoneId,
    cycleStart,
    inUseFrom,
    inUseUntil,
    createdAtUtcMicros,
    revision,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WorkSchedule &&
          other.id == this.id &&
          other.version == this.version &&
          other.employmentId == this.employmentId &&
          other.name == this.name &&
          other.timezoneId == this.timezoneId &&
          other.cycleStart == this.cycleStart &&
          other.inUseFrom == this.inUseFrom &&
          other.inUseUntil == this.inUseUntil &&
          other.createdAtUtcMicros == this.createdAtUtcMicros &&
          other.revision == this.revision);
}

class WorkSchedulesCompanion extends UpdateCompanion<WorkSchedule> {
  final Value<String> id;
  final Value<int> version;
  final Value<String> employmentId;
  final Value<String> name;
  final Value<String> timezoneId;
  final Value<String> cycleStart;
  final Value<String> inUseFrom;
  final Value<String?> inUseUntil;
  final Value<int> createdAtUtcMicros;
  final Value<int> revision;
  final Value<int> rowid;
  const WorkSchedulesCompanion({
    this.id = const Value.absent(),
    this.version = const Value.absent(),
    this.employmentId = const Value.absent(),
    this.name = const Value.absent(),
    this.timezoneId = const Value.absent(),
    this.cycleStart = const Value.absent(),
    this.inUseFrom = const Value.absent(),
    this.inUseUntil = const Value.absent(),
    this.createdAtUtcMicros = const Value.absent(),
    this.revision = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WorkSchedulesCompanion.insert({
    required String id,
    required int version,
    required String employmentId,
    required String name,
    required String timezoneId,
    required String cycleStart,
    required String inUseFrom,
    this.inUseUntil = const Value.absent(),
    required int createdAtUtcMicros,
    required int revision,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       version = Value(version),
       employmentId = Value(employmentId),
       name = Value(name),
       timezoneId = Value(timezoneId),
       cycleStart = Value(cycleStart),
       inUseFrom = Value(inUseFrom),
       createdAtUtcMicros = Value(createdAtUtcMicros),
       revision = Value(revision);
  static Insertable<WorkSchedule> custom({
    Expression<String>? id,
    Expression<int>? version,
    Expression<String>? employmentId,
    Expression<String>? name,
    Expression<String>? timezoneId,
    Expression<String>? cycleStart,
    Expression<String>? inUseFrom,
    Expression<String>? inUseUntil,
    Expression<int>? createdAtUtcMicros,
    Expression<int>? revision,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (version != null) 'version': version,
      if (employmentId != null) 'employment_id': employmentId,
      if (name != null) 'name': name,
      if (timezoneId != null) 'timezone_id': timezoneId,
      if (cycleStart != null) 'cycle_start': cycleStart,
      if (inUseFrom != null) 'in_use_from': inUseFrom,
      if (inUseUntil != null) 'in_use_until': inUseUntil,
      if (createdAtUtcMicros != null)
        'created_at_utc_micros': createdAtUtcMicros,
      if (revision != null) 'revision': revision,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WorkSchedulesCompanion copyWith({
    Value<String>? id,
    Value<int>? version,
    Value<String>? employmentId,
    Value<String>? name,
    Value<String>? timezoneId,
    Value<String>? cycleStart,
    Value<String>? inUseFrom,
    Value<String?>? inUseUntil,
    Value<int>? createdAtUtcMicros,
    Value<int>? revision,
    Value<int>? rowid,
  }) {
    return WorkSchedulesCompanion(
      id: id ?? this.id,
      version: version ?? this.version,
      employmentId: employmentId ?? this.employmentId,
      name: name ?? this.name,
      timezoneId: timezoneId ?? this.timezoneId,
      cycleStart: cycleStart ?? this.cycleStart,
      inUseFrom: inUseFrom ?? this.inUseFrom,
      inUseUntil: inUseUntil ?? this.inUseUntil,
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
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (employmentId.present) {
      map['employment_id'] = Variable<String>(employmentId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (timezoneId.present) {
      map['timezone_id'] = Variable<String>(timezoneId.value);
    }
    if (cycleStart.present) {
      map['cycle_start'] = Variable<String>(cycleStart.value);
    }
    if (inUseFrom.present) {
      map['in_use_from'] = Variable<String>(inUseFrom.value);
    }
    if (inUseUntil.present) {
      map['in_use_until'] = Variable<String>(inUseUntil.value);
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
    return (StringBuffer('WorkSchedulesCompanion(')
          ..write('id: $id, ')
          ..write('version: $version, ')
          ..write('employmentId: $employmentId, ')
          ..write('name: $name, ')
          ..write('timezoneId: $timezoneId, ')
          ..write('cycleStart: $cycleStart, ')
          ..write('inUseFrom: $inUseFrom, ')
          ..write('inUseUntil: $inUseUntil, ')
          ..write('createdAtUtcMicros: $createdAtUtcMicros, ')
          ..write('revision: $revision, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $WorkScheduleShiftTypesTable extends WorkScheduleShiftTypes
    with TableInfo<$WorkScheduleShiftTypesTable, WorkScheduleShiftType> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WorkScheduleShiftTypesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _scheduleIdMeta = const VerificationMeta(
    'scheduleId',
  );
  @override
  late final GeneratedColumn<String> scheduleId = GeneratedColumn<String>(
    'schedule_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _scheduleVersionMeta = const VerificationMeta(
    'scheduleVersion',
  );
  @override
  late final GeneratedColumn<int> scheduleVersion = GeneratedColumn<int>(
    'schedule_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
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
  static const VerificationMeta _startMinuteMeta = const VerificationMeta(
    'startMinute',
  );
  @override
  late final GeneratedColumn<int> startMinute = GeneratedColumn<int>(
    'start_minute',
    aliasedName,
    false,
    check: () =>
        const CustomExpression<bool>('start_minute BETWEEN 0 AND 1439'),
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endMinuteMeta = const VerificationMeta(
    'endMinute',
  );
  @override
  late final GeneratedColumn<int> endMinute = GeneratedColumn<int>(
    'end_minute',
    aliasedName,
    false,
    check: () => const CustomExpression<bool>('end_minute BETWEEN 0 AND 1439'),
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endDayOffsetMeta = const VerificationMeta(
    'endDayOffset',
  );
  @override
  late final GeneratedColumn<int> endDayOffset = GeneratedColumn<int>(
    'end_day_offset',
    aliasedName,
    false,
    check: () => const CustomExpression<bool>('end_day_offset IN (0, 1)'),
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _breaksMeta = const VerificationMeta('breaks');
  @override
  late final GeneratedColumn<String> breaks = GeneratedColumn<String>(
    'breaks',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    scheduleId,
    scheduleVersion,
    id,
    position,
    name,
    startMinute,
    endMinute,
    endDayOffset,
    breaks,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'work_schedule_shift_types';
  @override
  VerificationContext validateIntegrity(
    Insertable<WorkScheduleShiftType> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('schedule_id')) {
      context.handle(
        _scheduleIdMeta,
        scheduleId.isAcceptableOrUnknown(data['schedule_id']!, _scheduleIdMeta),
      );
    } else if (isInserting) {
      context.missing(_scheduleIdMeta);
    }
    if (data.containsKey('schedule_version')) {
      context.handle(
        _scheduleVersionMeta,
        scheduleVersion.isAcceptableOrUnknown(
          data['schedule_version']!,
          _scheduleVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_scheduleVersionMeta);
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('start_minute')) {
      context.handle(
        _startMinuteMeta,
        startMinute.isAcceptableOrUnknown(
          data['start_minute']!,
          _startMinuteMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_startMinuteMeta);
    }
    if (data.containsKey('end_minute')) {
      context.handle(
        _endMinuteMeta,
        endMinute.isAcceptableOrUnknown(data['end_minute']!, _endMinuteMeta),
      );
    } else if (isInserting) {
      context.missing(_endMinuteMeta);
    }
    if (data.containsKey('end_day_offset')) {
      context.handle(
        _endDayOffsetMeta,
        endDayOffset.isAcceptableOrUnknown(
          data['end_day_offset']!,
          _endDayOffsetMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_endDayOffsetMeta);
    }
    if (data.containsKey('breaks')) {
      context.handle(
        _breaksMeta,
        breaks.isAcceptableOrUnknown(data['breaks']!, _breaksMeta),
      );
    } else if (isInserting) {
      context.missing(_breaksMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {scheduleId, scheduleVersion, id};
  @override
  WorkScheduleShiftType map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WorkScheduleShiftType(
      scheduleId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}schedule_id'],
      )!,
      scheduleVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}schedule_version'],
      )!,
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      startMinute: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}start_minute'],
      )!,
      endMinute: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}end_minute'],
      )!,
      endDayOffset: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}end_day_offset'],
      )!,
      breaks: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}breaks'],
      )!,
    );
  }

  @override
  $WorkScheduleShiftTypesTable createAlias(String alias) {
    return $WorkScheduleShiftTypesTable(attachedDatabase, alias);
  }
}

class WorkScheduleShiftType extends DataClass
    implements Insertable<WorkScheduleShiftType> {
  final String scheduleId;
  final int scheduleVersion;
  final String id;
  final int position;
  final String name;
  final int startMinute;
  final int endMinute;
  final int endDayOffset;

  /// "dayOffset:minuteOfDay:minutes" per break, joined by ";".
  final String breaks;
  const WorkScheduleShiftType({
    required this.scheduleId,
    required this.scheduleVersion,
    required this.id,
    required this.position,
    required this.name,
    required this.startMinute,
    required this.endMinute,
    required this.endDayOffset,
    required this.breaks,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['schedule_id'] = Variable<String>(scheduleId);
    map['schedule_version'] = Variable<int>(scheduleVersion);
    map['id'] = Variable<String>(id);
    map['position'] = Variable<int>(position);
    map['name'] = Variable<String>(name);
    map['start_minute'] = Variable<int>(startMinute);
    map['end_minute'] = Variable<int>(endMinute);
    map['end_day_offset'] = Variable<int>(endDayOffset);
    map['breaks'] = Variable<String>(breaks);
    return map;
  }

  WorkScheduleShiftTypesCompanion toCompanion(bool nullToAbsent) {
    return WorkScheduleShiftTypesCompanion(
      scheduleId: Value(scheduleId),
      scheduleVersion: Value(scheduleVersion),
      id: Value(id),
      position: Value(position),
      name: Value(name),
      startMinute: Value(startMinute),
      endMinute: Value(endMinute),
      endDayOffset: Value(endDayOffset),
      breaks: Value(breaks),
    );
  }

  factory WorkScheduleShiftType.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WorkScheduleShiftType(
      scheduleId: serializer.fromJson<String>(json['scheduleId']),
      scheduleVersion: serializer.fromJson<int>(json['scheduleVersion']),
      id: serializer.fromJson<String>(json['id']),
      position: serializer.fromJson<int>(json['position']),
      name: serializer.fromJson<String>(json['name']),
      startMinute: serializer.fromJson<int>(json['startMinute']),
      endMinute: serializer.fromJson<int>(json['endMinute']),
      endDayOffset: serializer.fromJson<int>(json['endDayOffset']),
      breaks: serializer.fromJson<String>(json['breaks']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'scheduleId': serializer.toJson<String>(scheduleId),
      'scheduleVersion': serializer.toJson<int>(scheduleVersion),
      'id': serializer.toJson<String>(id),
      'position': serializer.toJson<int>(position),
      'name': serializer.toJson<String>(name),
      'startMinute': serializer.toJson<int>(startMinute),
      'endMinute': serializer.toJson<int>(endMinute),
      'endDayOffset': serializer.toJson<int>(endDayOffset),
      'breaks': serializer.toJson<String>(breaks),
    };
  }

  WorkScheduleShiftType copyWith({
    String? scheduleId,
    int? scheduleVersion,
    String? id,
    int? position,
    String? name,
    int? startMinute,
    int? endMinute,
    int? endDayOffset,
    String? breaks,
  }) => WorkScheduleShiftType(
    scheduleId: scheduleId ?? this.scheduleId,
    scheduleVersion: scheduleVersion ?? this.scheduleVersion,
    id: id ?? this.id,
    position: position ?? this.position,
    name: name ?? this.name,
    startMinute: startMinute ?? this.startMinute,
    endMinute: endMinute ?? this.endMinute,
    endDayOffset: endDayOffset ?? this.endDayOffset,
    breaks: breaks ?? this.breaks,
  );
  WorkScheduleShiftType copyWithCompanion(
    WorkScheduleShiftTypesCompanion data,
  ) {
    return WorkScheduleShiftType(
      scheduleId: data.scheduleId.present
          ? data.scheduleId.value
          : this.scheduleId,
      scheduleVersion: data.scheduleVersion.present
          ? data.scheduleVersion.value
          : this.scheduleVersion,
      id: data.id.present ? data.id.value : this.id,
      position: data.position.present ? data.position.value : this.position,
      name: data.name.present ? data.name.value : this.name,
      startMinute: data.startMinute.present
          ? data.startMinute.value
          : this.startMinute,
      endMinute: data.endMinute.present ? data.endMinute.value : this.endMinute,
      endDayOffset: data.endDayOffset.present
          ? data.endDayOffset.value
          : this.endDayOffset,
      breaks: data.breaks.present ? data.breaks.value : this.breaks,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WorkScheduleShiftType(')
          ..write('scheduleId: $scheduleId, ')
          ..write('scheduleVersion: $scheduleVersion, ')
          ..write('id: $id, ')
          ..write('position: $position, ')
          ..write('name: $name, ')
          ..write('startMinute: $startMinute, ')
          ..write('endMinute: $endMinute, ')
          ..write('endDayOffset: $endDayOffset, ')
          ..write('breaks: $breaks')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    scheduleId,
    scheduleVersion,
    id,
    position,
    name,
    startMinute,
    endMinute,
    endDayOffset,
    breaks,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WorkScheduleShiftType &&
          other.scheduleId == this.scheduleId &&
          other.scheduleVersion == this.scheduleVersion &&
          other.id == this.id &&
          other.position == this.position &&
          other.name == this.name &&
          other.startMinute == this.startMinute &&
          other.endMinute == this.endMinute &&
          other.endDayOffset == this.endDayOffset &&
          other.breaks == this.breaks);
}

class WorkScheduleShiftTypesCompanion
    extends UpdateCompanion<WorkScheduleShiftType> {
  final Value<String> scheduleId;
  final Value<int> scheduleVersion;
  final Value<String> id;
  final Value<int> position;
  final Value<String> name;
  final Value<int> startMinute;
  final Value<int> endMinute;
  final Value<int> endDayOffset;
  final Value<String> breaks;
  final Value<int> rowid;
  const WorkScheduleShiftTypesCompanion({
    this.scheduleId = const Value.absent(),
    this.scheduleVersion = const Value.absent(),
    this.id = const Value.absent(),
    this.position = const Value.absent(),
    this.name = const Value.absent(),
    this.startMinute = const Value.absent(),
    this.endMinute = const Value.absent(),
    this.endDayOffset = const Value.absent(),
    this.breaks = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WorkScheduleShiftTypesCompanion.insert({
    required String scheduleId,
    required int scheduleVersion,
    required String id,
    required int position,
    required String name,
    required int startMinute,
    required int endMinute,
    required int endDayOffset,
    required String breaks,
    this.rowid = const Value.absent(),
  }) : scheduleId = Value(scheduleId),
       scheduleVersion = Value(scheduleVersion),
       id = Value(id),
       position = Value(position),
       name = Value(name),
       startMinute = Value(startMinute),
       endMinute = Value(endMinute),
       endDayOffset = Value(endDayOffset),
       breaks = Value(breaks);
  static Insertable<WorkScheduleShiftType> custom({
    Expression<String>? scheduleId,
    Expression<int>? scheduleVersion,
    Expression<String>? id,
    Expression<int>? position,
    Expression<String>? name,
    Expression<int>? startMinute,
    Expression<int>? endMinute,
    Expression<int>? endDayOffset,
    Expression<String>? breaks,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (scheduleId != null) 'schedule_id': scheduleId,
      if (scheduleVersion != null) 'schedule_version': scheduleVersion,
      if (id != null) 'id': id,
      if (position != null) 'position': position,
      if (name != null) 'name': name,
      if (startMinute != null) 'start_minute': startMinute,
      if (endMinute != null) 'end_minute': endMinute,
      if (endDayOffset != null) 'end_day_offset': endDayOffset,
      if (breaks != null) 'breaks': breaks,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WorkScheduleShiftTypesCompanion copyWith({
    Value<String>? scheduleId,
    Value<int>? scheduleVersion,
    Value<String>? id,
    Value<int>? position,
    Value<String>? name,
    Value<int>? startMinute,
    Value<int>? endMinute,
    Value<int>? endDayOffset,
    Value<String>? breaks,
    Value<int>? rowid,
  }) {
    return WorkScheduleShiftTypesCompanion(
      scheduleId: scheduleId ?? this.scheduleId,
      scheduleVersion: scheduleVersion ?? this.scheduleVersion,
      id: id ?? this.id,
      position: position ?? this.position,
      name: name ?? this.name,
      startMinute: startMinute ?? this.startMinute,
      endMinute: endMinute ?? this.endMinute,
      endDayOffset: endDayOffset ?? this.endDayOffset,
      breaks: breaks ?? this.breaks,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (scheduleId.present) {
      map['schedule_id'] = Variable<String>(scheduleId.value);
    }
    if (scheduleVersion.present) {
      map['schedule_version'] = Variable<int>(scheduleVersion.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (startMinute.present) {
      map['start_minute'] = Variable<int>(startMinute.value);
    }
    if (endMinute.present) {
      map['end_minute'] = Variable<int>(endMinute.value);
    }
    if (endDayOffset.present) {
      map['end_day_offset'] = Variable<int>(endDayOffset.value);
    }
    if (breaks.present) {
      map['breaks'] = Variable<String>(breaks.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WorkScheduleShiftTypesCompanion(')
          ..write('scheduleId: $scheduleId, ')
          ..write('scheduleVersion: $scheduleVersion, ')
          ..write('id: $id, ')
          ..write('position: $position, ')
          ..write('name: $name, ')
          ..write('startMinute: $startMinute, ')
          ..write('endMinute: $endMinute, ')
          ..write('endDayOffset: $endDayOffset, ')
          ..write('breaks: $breaks, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $WorkScheduleBlocksTable extends WorkScheduleBlocks
    with TableInfo<$WorkScheduleBlocksTable, WorkScheduleBlock> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WorkScheduleBlocksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _scheduleIdMeta = const VerificationMeta(
    'scheduleId',
  );
  @override
  late final GeneratedColumn<String> scheduleId = GeneratedColumn<String>(
    'schedule_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _scheduleVersionMeta = const VerificationMeta(
    'scheduleVersion',
  );
  @override
  late final GeneratedColumn<int> scheduleVersion = GeneratedColumn<int>(
    'schedule_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _countMeta = const VerificationMeta('count');
  @override
  late final GeneratedColumn<int> count = GeneratedColumn<int>(
    'count',
    aliasedName,
    false,
    check: () => const CustomExpression<bool>('count BETWEEN 1 AND 99'),
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _shiftTypeIdMeta = const VerificationMeta(
    'shiftTypeId',
  );
  @override
  late final GeneratedColumn<String> shiftTypeId = GeneratedColumn<String>(
    'shift_type_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    scheduleId,
    scheduleVersion,
    position,
    count,
    shiftTypeId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'work_schedule_blocks';
  @override
  VerificationContext validateIntegrity(
    Insertable<WorkScheduleBlock> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('schedule_id')) {
      context.handle(
        _scheduleIdMeta,
        scheduleId.isAcceptableOrUnknown(data['schedule_id']!, _scheduleIdMeta),
      );
    } else if (isInserting) {
      context.missing(_scheduleIdMeta);
    }
    if (data.containsKey('schedule_version')) {
      context.handle(
        _scheduleVersionMeta,
        scheduleVersion.isAcceptableOrUnknown(
          data['schedule_version']!,
          _scheduleVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_scheduleVersionMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    if (data.containsKey('count')) {
      context.handle(
        _countMeta,
        count.isAcceptableOrUnknown(data['count']!, _countMeta),
      );
    } else if (isInserting) {
      context.missing(_countMeta);
    }
    if (data.containsKey('shift_type_id')) {
      context.handle(
        _shiftTypeIdMeta,
        shiftTypeId.isAcceptableOrUnknown(
          data['shift_type_id']!,
          _shiftTypeIdMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {
    scheduleId,
    scheduleVersion,
    position,
  };
  @override
  WorkScheduleBlock map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WorkScheduleBlock(
      scheduleId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}schedule_id'],
      )!,
      scheduleVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}schedule_version'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
      count: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}count'],
      )!,
      shiftTypeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}shift_type_id'],
      ),
    );
  }

  @override
  $WorkScheduleBlocksTable createAlias(String alias) {
    return $WorkScheduleBlocksTable(attachedDatabase, alias);
  }
}

class WorkScheduleBlock extends DataClass
    implements Insertable<WorkScheduleBlock> {
  final String scheduleId;
  final int scheduleVersion;
  final int position;
  final int count;

  /// Null for Off.
  final String? shiftTypeId;
  const WorkScheduleBlock({
    required this.scheduleId,
    required this.scheduleVersion,
    required this.position,
    required this.count,
    this.shiftTypeId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['schedule_id'] = Variable<String>(scheduleId);
    map['schedule_version'] = Variable<int>(scheduleVersion);
    map['position'] = Variable<int>(position);
    map['count'] = Variable<int>(count);
    if (!nullToAbsent || shiftTypeId != null) {
      map['shift_type_id'] = Variable<String>(shiftTypeId);
    }
    return map;
  }

  WorkScheduleBlocksCompanion toCompanion(bool nullToAbsent) {
    return WorkScheduleBlocksCompanion(
      scheduleId: Value(scheduleId),
      scheduleVersion: Value(scheduleVersion),
      position: Value(position),
      count: Value(count),
      shiftTypeId: shiftTypeId == null && nullToAbsent
          ? const Value.absent()
          : Value(shiftTypeId),
    );
  }

  factory WorkScheduleBlock.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WorkScheduleBlock(
      scheduleId: serializer.fromJson<String>(json['scheduleId']),
      scheduleVersion: serializer.fromJson<int>(json['scheduleVersion']),
      position: serializer.fromJson<int>(json['position']),
      count: serializer.fromJson<int>(json['count']),
      shiftTypeId: serializer.fromJson<String?>(json['shiftTypeId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'scheduleId': serializer.toJson<String>(scheduleId),
      'scheduleVersion': serializer.toJson<int>(scheduleVersion),
      'position': serializer.toJson<int>(position),
      'count': serializer.toJson<int>(count),
      'shiftTypeId': serializer.toJson<String?>(shiftTypeId),
    };
  }

  WorkScheduleBlock copyWith({
    String? scheduleId,
    int? scheduleVersion,
    int? position,
    int? count,
    Value<String?> shiftTypeId = const Value.absent(),
  }) => WorkScheduleBlock(
    scheduleId: scheduleId ?? this.scheduleId,
    scheduleVersion: scheduleVersion ?? this.scheduleVersion,
    position: position ?? this.position,
    count: count ?? this.count,
    shiftTypeId: shiftTypeId.present ? shiftTypeId.value : this.shiftTypeId,
  );
  WorkScheduleBlock copyWithCompanion(WorkScheduleBlocksCompanion data) {
    return WorkScheduleBlock(
      scheduleId: data.scheduleId.present
          ? data.scheduleId.value
          : this.scheduleId,
      scheduleVersion: data.scheduleVersion.present
          ? data.scheduleVersion.value
          : this.scheduleVersion,
      position: data.position.present ? data.position.value : this.position,
      count: data.count.present ? data.count.value : this.count,
      shiftTypeId: data.shiftTypeId.present
          ? data.shiftTypeId.value
          : this.shiftTypeId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WorkScheduleBlock(')
          ..write('scheduleId: $scheduleId, ')
          ..write('scheduleVersion: $scheduleVersion, ')
          ..write('position: $position, ')
          ..write('count: $count, ')
          ..write('shiftTypeId: $shiftTypeId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(scheduleId, scheduleVersion, position, count, shiftTypeId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WorkScheduleBlock &&
          other.scheduleId == this.scheduleId &&
          other.scheduleVersion == this.scheduleVersion &&
          other.position == this.position &&
          other.count == this.count &&
          other.shiftTypeId == this.shiftTypeId);
}

class WorkScheduleBlocksCompanion extends UpdateCompanion<WorkScheduleBlock> {
  final Value<String> scheduleId;
  final Value<int> scheduleVersion;
  final Value<int> position;
  final Value<int> count;
  final Value<String?> shiftTypeId;
  final Value<int> rowid;
  const WorkScheduleBlocksCompanion({
    this.scheduleId = const Value.absent(),
    this.scheduleVersion = const Value.absent(),
    this.position = const Value.absent(),
    this.count = const Value.absent(),
    this.shiftTypeId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WorkScheduleBlocksCompanion.insert({
    required String scheduleId,
    required int scheduleVersion,
    required int position,
    required int count,
    this.shiftTypeId = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : scheduleId = Value(scheduleId),
       scheduleVersion = Value(scheduleVersion),
       position = Value(position),
       count = Value(count);
  static Insertable<WorkScheduleBlock> custom({
    Expression<String>? scheduleId,
    Expression<int>? scheduleVersion,
    Expression<int>? position,
    Expression<int>? count,
    Expression<String>? shiftTypeId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (scheduleId != null) 'schedule_id': scheduleId,
      if (scheduleVersion != null) 'schedule_version': scheduleVersion,
      if (position != null) 'position': position,
      if (count != null) 'count': count,
      if (shiftTypeId != null) 'shift_type_id': shiftTypeId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WorkScheduleBlocksCompanion copyWith({
    Value<String>? scheduleId,
    Value<int>? scheduleVersion,
    Value<int>? position,
    Value<int>? count,
    Value<String?>? shiftTypeId,
    Value<int>? rowid,
  }) {
    return WorkScheduleBlocksCompanion(
      scheduleId: scheduleId ?? this.scheduleId,
      scheduleVersion: scheduleVersion ?? this.scheduleVersion,
      position: position ?? this.position,
      count: count ?? this.count,
      shiftTypeId: shiftTypeId ?? this.shiftTypeId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (scheduleId.present) {
      map['schedule_id'] = Variable<String>(scheduleId.value);
    }
    if (scheduleVersion.present) {
      map['schedule_version'] = Variable<int>(scheduleVersion.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (count.present) {
      map['count'] = Variable<int>(count.value);
    }
    if (shiftTypeId.present) {
      map['shift_type_id'] = Variable<String>(shiftTypeId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WorkScheduleBlocksCompanion(')
          ..write('scheduleId: $scheduleId, ')
          ..write('scheduleVersion: $scheduleVersion, ')
          ..write('position: $position, ')
          ..write('count: $count, ')
          ..write('shiftTypeId: $shiftTypeId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $WorkDayExceptionsTable extends WorkDayExceptions
    with TableInfo<$WorkDayExceptionsTable, WorkDayException> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WorkDayExceptionsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<String> date = GeneratedColumn<String>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    check: () => const CustomExpression<bool>(
      "kind IN ('changed', 'cancelled', 'leave', 'extra')",
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startMinuteMeta = const VerificationMeta(
    'startMinute',
  );
  @override
  late final GeneratedColumn<int> startMinute = GeneratedColumn<int>(
    'start_minute',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _endMinuteMeta = const VerificationMeta(
    'endMinute',
  );
  @override
  late final GeneratedColumn<int> endMinute = GeneratedColumn<int>(
    'end_minute',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _endDayOffsetMeta = const VerificationMeta(
    'endDayOffset',
  );
  @override
  late final GeneratedColumn<int> endDayOffset = GeneratedColumn<int>(
    'end_day_offset',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _breaksMeta = const VerificationMeta('breaks');
  @override
  late final GeneratedColumn<String> breaks = GeneratedColumn<String>(
    'breaks',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _shiftTypeIdMeta = const VerificationMeta(
    'shiftTypeId',
  );
  @override
  late final GeneratedColumn<String> shiftTypeId = GeneratedColumn<String>(
    'shift_type_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _reasonMeta = const VerificationMeta('reason');
  @override
  late final GeneratedColumn<String> reason = GeneratedColumn<String>(
    'reason',
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
  static const VerificationMeta _leaveTypeMeta = const VerificationMeta(
    'leaveType',
  );
  @override
  late final GeneratedColumn<String> leaveType = GeneratedColumn<String>(
    'leave_type',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _illnessStartedOnMeta = const VerificationMeta(
    'illnessStartedOn',
  );
  @override
  late final GeneratedColumn<String> illnessStartedOn = GeneratedColumn<String>(
    'illness_started_on',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _countsAsOvertimeMeta = const VerificationMeta(
    'countsAsOvertime',
  );
  @override
  late final GeneratedColumn<bool> countsAsOvertime = GeneratedColumn<bool>(
    'counts_as_overtime',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("counts_as_overtime" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
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
    date,
    kind,
    startMinute,
    endMinute,
    endDayOffset,
    breaks,
    shiftTypeId,
    reason,
    note,
    leaveType,
    illnessStartedOn,
    countsAsOvertime,
    createdAtUtcMicros,
    updatedAtUtcMicros,
    revision,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'work_day_exceptions';
  @override
  VerificationContext validateIntegrity(
    Insertable<WorkDayException> instance, {
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
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('start_minute')) {
      context.handle(
        _startMinuteMeta,
        startMinute.isAcceptableOrUnknown(
          data['start_minute']!,
          _startMinuteMeta,
        ),
      );
    }
    if (data.containsKey('end_minute')) {
      context.handle(
        _endMinuteMeta,
        endMinute.isAcceptableOrUnknown(data['end_minute']!, _endMinuteMeta),
      );
    }
    if (data.containsKey('end_day_offset')) {
      context.handle(
        _endDayOffsetMeta,
        endDayOffset.isAcceptableOrUnknown(
          data['end_day_offset']!,
          _endDayOffsetMeta,
        ),
      );
    }
    if (data.containsKey('breaks')) {
      context.handle(
        _breaksMeta,
        breaks.isAcceptableOrUnknown(data['breaks']!, _breaksMeta),
      );
    }
    if (data.containsKey('shift_type_id')) {
      context.handle(
        _shiftTypeIdMeta,
        shiftTypeId.isAcceptableOrUnknown(
          data['shift_type_id']!,
          _shiftTypeIdMeta,
        ),
      );
    }
    if (data.containsKey('reason')) {
      context.handle(
        _reasonMeta,
        reason.isAcceptableOrUnknown(data['reason']!, _reasonMeta),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('leave_type')) {
      context.handle(
        _leaveTypeMeta,
        leaveType.isAcceptableOrUnknown(data['leave_type']!, _leaveTypeMeta),
      );
    }
    if (data.containsKey('illness_started_on')) {
      context.handle(
        _illnessStartedOnMeta,
        illnessStartedOn.isAcceptableOrUnknown(
          data['illness_started_on']!,
          _illnessStartedOnMeta,
        ),
      );
    }
    if (data.containsKey('counts_as_overtime')) {
      context.handle(
        _countsAsOvertimeMeta,
        countsAsOvertime.isAcceptableOrUnknown(
          data['counts_as_overtime']!,
          _countsAsOvertimeMeta,
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
  WorkDayException map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WorkDayException(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      employmentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}employment_id'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}date'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      startMinute: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}start_minute'],
      ),
      endMinute: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}end_minute'],
      ),
      endDayOffset: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}end_day_offset'],
      ),
      breaks: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}breaks'],
      ),
      shiftTypeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}shift_type_id'],
      ),
      reason: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reason'],
      ),
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      leaveType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}leave_type'],
      ),
      illnessStartedOn: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}illness_started_on'],
      ),
      countsAsOvertime: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}counts_as_overtime'],
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
  $WorkDayExceptionsTable createAlias(String alias) {
    return $WorkDayExceptionsTable(attachedDatabase, alias);
  }
}

class WorkDayException extends DataClass
    implements Insertable<WorkDayException> {
  final String id;
  final String employmentId;
  final String date;
  final String kind;
  final int? startMinute;
  final int? endMinute;
  final int? endDayOffset;
  final String? breaks;
  final String? shiftTypeId;
  final String? reason;
  final String? note;
  final String? leaveType;
  final String? illnessStartedOn;
  final bool countsAsOvertime;
  final int createdAtUtcMicros;
  final int updatedAtUtcMicros;
  final int revision;
  const WorkDayException({
    required this.id,
    required this.employmentId,
    required this.date,
    required this.kind,
    this.startMinute,
    this.endMinute,
    this.endDayOffset,
    this.breaks,
    this.shiftTypeId,
    this.reason,
    this.note,
    this.leaveType,
    this.illnessStartedOn,
    required this.countsAsOvertime,
    required this.createdAtUtcMicros,
    required this.updatedAtUtcMicros,
    required this.revision,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['employment_id'] = Variable<String>(employmentId);
    map['date'] = Variable<String>(date);
    map['kind'] = Variable<String>(kind);
    if (!nullToAbsent || startMinute != null) {
      map['start_minute'] = Variable<int>(startMinute);
    }
    if (!nullToAbsent || endMinute != null) {
      map['end_minute'] = Variable<int>(endMinute);
    }
    if (!nullToAbsent || endDayOffset != null) {
      map['end_day_offset'] = Variable<int>(endDayOffset);
    }
    if (!nullToAbsent || breaks != null) {
      map['breaks'] = Variable<String>(breaks);
    }
    if (!nullToAbsent || shiftTypeId != null) {
      map['shift_type_id'] = Variable<String>(shiftTypeId);
    }
    if (!nullToAbsent || reason != null) {
      map['reason'] = Variable<String>(reason);
    }
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    if (!nullToAbsent || leaveType != null) {
      map['leave_type'] = Variable<String>(leaveType);
    }
    if (!nullToAbsent || illnessStartedOn != null) {
      map['illness_started_on'] = Variable<String>(illnessStartedOn);
    }
    map['counts_as_overtime'] = Variable<bool>(countsAsOvertime);
    map['created_at_utc_micros'] = Variable<int>(createdAtUtcMicros);
    map['updated_at_utc_micros'] = Variable<int>(updatedAtUtcMicros);
    map['revision'] = Variable<int>(revision);
    return map;
  }

  WorkDayExceptionsCompanion toCompanion(bool nullToAbsent) {
    return WorkDayExceptionsCompanion(
      id: Value(id),
      employmentId: Value(employmentId),
      date: Value(date),
      kind: Value(kind),
      startMinute: startMinute == null && nullToAbsent
          ? const Value.absent()
          : Value(startMinute),
      endMinute: endMinute == null && nullToAbsent
          ? const Value.absent()
          : Value(endMinute),
      endDayOffset: endDayOffset == null && nullToAbsent
          ? const Value.absent()
          : Value(endDayOffset),
      breaks: breaks == null && nullToAbsent
          ? const Value.absent()
          : Value(breaks),
      shiftTypeId: shiftTypeId == null && nullToAbsent
          ? const Value.absent()
          : Value(shiftTypeId),
      reason: reason == null && nullToAbsent
          ? const Value.absent()
          : Value(reason),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      leaveType: leaveType == null && nullToAbsent
          ? const Value.absent()
          : Value(leaveType),
      illnessStartedOn: illnessStartedOn == null && nullToAbsent
          ? const Value.absent()
          : Value(illnessStartedOn),
      countsAsOvertime: Value(countsAsOvertime),
      createdAtUtcMicros: Value(createdAtUtcMicros),
      updatedAtUtcMicros: Value(updatedAtUtcMicros),
      revision: Value(revision),
    );
  }

  factory WorkDayException.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WorkDayException(
      id: serializer.fromJson<String>(json['id']),
      employmentId: serializer.fromJson<String>(json['employmentId']),
      date: serializer.fromJson<String>(json['date']),
      kind: serializer.fromJson<String>(json['kind']),
      startMinute: serializer.fromJson<int?>(json['startMinute']),
      endMinute: serializer.fromJson<int?>(json['endMinute']),
      endDayOffset: serializer.fromJson<int?>(json['endDayOffset']),
      breaks: serializer.fromJson<String?>(json['breaks']),
      shiftTypeId: serializer.fromJson<String?>(json['shiftTypeId']),
      reason: serializer.fromJson<String?>(json['reason']),
      note: serializer.fromJson<String?>(json['note']),
      leaveType: serializer.fromJson<String?>(json['leaveType']),
      illnessStartedOn: serializer.fromJson<String?>(json['illnessStartedOn']),
      countsAsOvertime: serializer.fromJson<bool>(json['countsAsOvertime']),
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
      'date': serializer.toJson<String>(date),
      'kind': serializer.toJson<String>(kind),
      'startMinute': serializer.toJson<int?>(startMinute),
      'endMinute': serializer.toJson<int?>(endMinute),
      'endDayOffset': serializer.toJson<int?>(endDayOffset),
      'breaks': serializer.toJson<String?>(breaks),
      'shiftTypeId': serializer.toJson<String?>(shiftTypeId),
      'reason': serializer.toJson<String?>(reason),
      'note': serializer.toJson<String?>(note),
      'leaveType': serializer.toJson<String?>(leaveType),
      'illnessStartedOn': serializer.toJson<String?>(illnessStartedOn),
      'countsAsOvertime': serializer.toJson<bool>(countsAsOvertime),
      'createdAtUtcMicros': serializer.toJson<int>(createdAtUtcMicros),
      'updatedAtUtcMicros': serializer.toJson<int>(updatedAtUtcMicros),
      'revision': serializer.toJson<int>(revision),
    };
  }

  WorkDayException copyWith({
    String? id,
    String? employmentId,
    String? date,
    String? kind,
    Value<int?> startMinute = const Value.absent(),
    Value<int?> endMinute = const Value.absent(),
    Value<int?> endDayOffset = const Value.absent(),
    Value<String?> breaks = const Value.absent(),
    Value<String?> shiftTypeId = const Value.absent(),
    Value<String?> reason = const Value.absent(),
    Value<String?> note = const Value.absent(),
    Value<String?> leaveType = const Value.absent(),
    Value<String?> illnessStartedOn = const Value.absent(),
    bool? countsAsOvertime,
    int? createdAtUtcMicros,
    int? updatedAtUtcMicros,
    int? revision,
  }) => WorkDayException(
    id: id ?? this.id,
    employmentId: employmentId ?? this.employmentId,
    date: date ?? this.date,
    kind: kind ?? this.kind,
    startMinute: startMinute.present ? startMinute.value : this.startMinute,
    endMinute: endMinute.present ? endMinute.value : this.endMinute,
    endDayOffset: endDayOffset.present ? endDayOffset.value : this.endDayOffset,
    breaks: breaks.present ? breaks.value : this.breaks,
    shiftTypeId: shiftTypeId.present ? shiftTypeId.value : this.shiftTypeId,
    reason: reason.present ? reason.value : this.reason,
    note: note.present ? note.value : this.note,
    leaveType: leaveType.present ? leaveType.value : this.leaveType,
    illnessStartedOn: illnessStartedOn.present
        ? illnessStartedOn.value
        : this.illnessStartedOn,
    countsAsOvertime: countsAsOvertime ?? this.countsAsOvertime,
    createdAtUtcMicros: createdAtUtcMicros ?? this.createdAtUtcMicros,
    updatedAtUtcMicros: updatedAtUtcMicros ?? this.updatedAtUtcMicros,
    revision: revision ?? this.revision,
  );
  WorkDayException copyWithCompanion(WorkDayExceptionsCompanion data) {
    return WorkDayException(
      id: data.id.present ? data.id.value : this.id,
      employmentId: data.employmentId.present
          ? data.employmentId.value
          : this.employmentId,
      date: data.date.present ? data.date.value : this.date,
      kind: data.kind.present ? data.kind.value : this.kind,
      startMinute: data.startMinute.present
          ? data.startMinute.value
          : this.startMinute,
      endMinute: data.endMinute.present ? data.endMinute.value : this.endMinute,
      endDayOffset: data.endDayOffset.present
          ? data.endDayOffset.value
          : this.endDayOffset,
      breaks: data.breaks.present ? data.breaks.value : this.breaks,
      shiftTypeId: data.shiftTypeId.present
          ? data.shiftTypeId.value
          : this.shiftTypeId,
      reason: data.reason.present ? data.reason.value : this.reason,
      note: data.note.present ? data.note.value : this.note,
      leaveType: data.leaveType.present ? data.leaveType.value : this.leaveType,
      illnessStartedOn: data.illnessStartedOn.present
          ? data.illnessStartedOn.value
          : this.illnessStartedOn,
      countsAsOvertime: data.countsAsOvertime.present
          ? data.countsAsOvertime.value
          : this.countsAsOvertime,
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
    return (StringBuffer('WorkDayException(')
          ..write('id: $id, ')
          ..write('employmentId: $employmentId, ')
          ..write('date: $date, ')
          ..write('kind: $kind, ')
          ..write('startMinute: $startMinute, ')
          ..write('endMinute: $endMinute, ')
          ..write('endDayOffset: $endDayOffset, ')
          ..write('breaks: $breaks, ')
          ..write('shiftTypeId: $shiftTypeId, ')
          ..write('reason: $reason, ')
          ..write('note: $note, ')
          ..write('leaveType: $leaveType, ')
          ..write('illnessStartedOn: $illnessStartedOn, ')
          ..write('countsAsOvertime: $countsAsOvertime, ')
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
    date,
    kind,
    startMinute,
    endMinute,
    endDayOffset,
    breaks,
    shiftTypeId,
    reason,
    note,
    leaveType,
    illnessStartedOn,
    countsAsOvertime,
    createdAtUtcMicros,
    updatedAtUtcMicros,
    revision,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WorkDayException &&
          other.id == this.id &&
          other.employmentId == this.employmentId &&
          other.date == this.date &&
          other.kind == this.kind &&
          other.startMinute == this.startMinute &&
          other.endMinute == this.endMinute &&
          other.endDayOffset == this.endDayOffset &&
          other.breaks == this.breaks &&
          other.shiftTypeId == this.shiftTypeId &&
          other.reason == this.reason &&
          other.note == this.note &&
          other.leaveType == this.leaveType &&
          other.illnessStartedOn == this.illnessStartedOn &&
          other.countsAsOvertime == this.countsAsOvertime &&
          other.createdAtUtcMicros == this.createdAtUtcMicros &&
          other.updatedAtUtcMicros == this.updatedAtUtcMicros &&
          other.revision == this.revision);
}

class WorkDayExceptionsCompanion extends UpdateCompanion<WorkDayException> {
  final Value<String> id;
  final Value<String> employmentId;
  final Value<String> date;
  final Value<String> kind;
  final Value<int?> startMinute;
  final Value<int?> endMinute;
  final Value<int?> endDayOffset;
  final Value<String?> breaks;
  final Value<String?> shiftTypeId;
  final Value<String?> reason;
  final Value<String?> note;
  final Value<String?> leaveType;
  final Value<String?> illnessStartedOn;
  final Value<bool> countsAsOvertime;
  final Value<int> createdAtUtcMicros;
  final Value<int> updatedAtUtcMicros;
  final Value<int> revision;
  final Value<int> rowid;
  const WorkDayExceptionsCompanion({
    this.id = const Value.absent(),
    this.employmentId = const Value.absent(),
    this.date = const Value.absent(),
    this.kind = const Value.absent(),
    this.startMinute = const Value.absent(),
    this.endMinute = const Value.absent(),
    this.endDayOffset = const Value.absent(),
    this.breaks = const Value.absent(),
    this.shiftTypeId = const Value.absent(),
    this.reason = const Value.absent(),
    this.note = const Value.absent(),
    this.leaveType = const Value.absent(),
    this.illnessStartedOn = const Value.absent(),
    this.countsAsOvertime = const Value.absent(),
    this.createdAtUtcMicros = const Value.absent(),
    this.updatedAtUtcMicros = const Value.absent(),
    this.revision = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WorkDayExceptionsCompanion.insert({
    required String id,
    required String employmentId,
    required String date,
    required String kind,
    this.startMinute = const Value.absent(),
    this.endMinute = const Value.absent(),
    this.endDayOffset = const Value.absent(),
    this.breaks = const Value.absent(),
    this.shiftTypeId = const Value.absent(),
    this.reason = const Value.absent(),
    this.note = const Value.absent(),
    this.leaveType = const Value.absent(),
    this.illnessStartedOn = const Value.absent(),
    this.countsAsOvertime = const Value.absent(),
    required int createdAtUtcMicros,
    required int updatedAtUtcMicros,
    required int revision,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       employmentId = Value(employmentId),
       date = Value(date),
       kind = Value(kind),
       createdAtUtcMicros = Value(createdAtUtcMicros),
       updatedAtUtcMicros = Value(updatedAtUtcMicros),
       revision = Value(revision);
  static Insertable<WorkDayException> custom({
    Expression<String>? id,
    Expression<String>? employmentId,
    Expression<String>? date,
    Expression<String>? kind,
    Expression<int>? startMinute,
    Expression<int>? endMinute,
    Expression<int>? endDayOffset,
    Expression<String>? breaks,
    Expression<String>? shiftTypeId,
    Expression<String>? reason,
    Expression<String>? note,
    Expression<String>? leaveType,
    Expression<String>? illnessStartedOn,
    Expression<bool>? countsAsOvertime,
    Expression<int>? createdAtUtcMicros,
    Expression<int>? updatedAtUtcMicros,
    Expression<int>? revision,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (employmentId != null) 'employment_id': employmentId,
      if (date != null) 'date': date,
      if (kind != null) 'kind': kind,
      if (startMinute != null) 'start_minute': startMinute,
      if (endMinute != null) 'end_minute': endMinute,
      if (endDayOffset != null) 'end_day_offset': endDayOffset,
      if (breaks != null) 'breaks': breaks,
      if (shiftTypeId != null) 'shift_type_id': shiftTypeId,
      if (reason != null) 'reason': reason,
      if (note != null) 'note': note,
      if (leaveType != null) 'leave_type': leaveType,
      if (illnessStartedOn != null) 'illness_started_on': illnessStartedOn,
      if (countsAsOvertime != null) 'counts_as_overtime': countsAsOvertime,
      if (createdAtUtcMicros != null)
        'created_at_utc_micros': createdAtUtcMicros,
      if (updatedAtUtcMicros != null)
        'updated_at_utc_micros': updatedAtUtcMicros,
      if (revision != null) 'revision': revision,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WorkDayExceptionsCompanion copyWith({
    Value<String>? id,
    Value<String>? employmentId,
    Value<String>? date,
    Value<String>? kind,
    Value<int?>? startMinute,
    Value<int?>? endMinute,
    Value<int?>? endDayOffset,
    Value<String?>? breaks,
    Value<String?>? shiftTypeId,
    Value<String?>? reason,
    Value<String?>? note,
    Value<String?>? leaveType,
    Value<String?>? illnessStartedOn,
    Value<bool>? countsAsOvertime,
    Value<int>? createdAtUtcMicros,
    Value<int>? updatedAtUtcMicros,
    Value<int>? revision,
    Value<int>? rowid,
  }) {
    return WorkDayExceptionsCompanion(
      id: id ?? this.id,
      employmentId: employmentId ?? this.employmentId,
      date: date ?? this.date,
      kind: kind ?? this.kind,
      startMinute: startMinute ?? this.startMinute,
      endMinute: endMinute ?? this.endMinute,
      endDayOffset: endDayOffset ?? this.endDayOffset,
      breaks: breaks ?? this.breaks,
      shiftTypeId: shiftTypeId ?? this.shiftTypeId,
      reason: reason ?? this.reason,
      note: note ?? this.note,
      leaveType: leaveType ?? this.leaveType,
      illnessStartedOn: illnessStartedOn ?? this.illnessStartedOn,
      countsAsOvertime: countsAsOvertime ?? this.countsAsOvertime,
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
    if (date.present) {
      map['date'] = Variable<String>(date.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (startMinute.present) {
      map['start_minute'] = Variable<int>(startMinute.value);
    }
    if (endMinute.present) {
      map['end_minute'] = Variable<int>(endMinute.value);
    }
    if (endDayOffset.present) {
      map['end_day_offset'] = Variable<int>(endDayOffset.value);
    }
    if (breaks.present) {
      map['breaks'] = Variable<String>(breaks.value);
    }
    if (shiftTypeId.present) {
      map['shift_type_id'] = Variable<String>(shiftTypeId.value);
    }
    if (reason.present) {
      map['reason'] = Variable<String>(reason.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (leaveType.present) {
      map['leave_type'] = Variable<String>(leaveType.value);
    }
    if (illnessStartedOn.present) {
      map['illness_started_on'] = Variable<String>(illnessStartedOn.value);
    }
    if (countsAsOvertime.present) {
      map['counts_as_overtime'] = Variable<bool>(countsAsOvertime.value);
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
    return (StringBuffer('WorkDayExceptionsCompanion(')
          ..write('id: $id, ')
          ..write('employmentId: $employmentId, ')
          ..write('date: $date, ')
          ..write('kind: $kind, ')
          ..write('startMinute: $startMinute, ')
          ..write('endMinute: $endMinute, ')
          ..write('endDayOffset: $endDayOffset, ')
          ..write('breaks: $breaks, ')
          ..write('shiftTypeId: $shiftTypeId, ')
          ..write('reason: $reason, ')
          ..write('note: $note, ')
          ..write('leaveType: $leaveType, ')
          ..write('illnessStartedOn: $illnessStartedOn, ')
          ..write('countsAsOvertime: $countsAsOvertime, ')
          ..write('createdAtUtcMicros: $createdAtUtcMicros, ')
          ..write('updatedAtUtcMicros: $updatedAtUtcMicros, ')
          ..write('revision: $revision, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $WorkLeaveRecordsTable extends WorkLeaveRecords
    with TableInfo<$WorkLeaveRecordsTable, WorkLeaveRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WorkLeaveRecordsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<String> date = GeneratedColumn<String>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _leaveTypeMeta = const VerificationMeta(
    'leaveType',
  );
  @override
  late final GeneratedColumn<String> leaveType = GeneratedColumn<String>(
    'leave_type',
    aliasedName,
    false,
    check: () =>
        const CustomExpression<bool>("leave_type IN ('vacation', 'sick')"),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _illnessStartedOnMeta = const VerificationMeta(
    'illnessStartedOn',
  );
  @override
  late final GeneratedColumn<String> illnessStartedOn = GeneratedColumn<String>(
    'illness_started_on',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _paidMinutesMeta = const VerificationMeta(
    'paidMinutes',
  );
  @override
  late final GeneratedColumn<int> paidMinutes = GeneratedColumn<int>(
    'paid_minutes',
    aliasedName,
    false,
    check: () => const CustomExpression<bool>('paid_minutes > 0'),
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _agreementIdMeta = const VerificationMeta(
    'agreementId',
  );
  @override
  late final GeneratedColumn<String> agreementId = GeneratedColumn<String>(
    'agreement_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES pay_agreements (id) ON DELETE RESTRICT',
    ),
  );
  static const VerificationMeta _scheduleIdMeta = const VerificationMeta(
    'scheduleId',
  );
  @override
  late final GeneratedColumn<String> scheduleId = GeneratedColumn<String>(
    'schedule_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _scheduleVersionMeta = const VerificationMeta(
    'scheduleVersion',
  );
  @override
  late final GeneratedColumn<int> scheduleVersion = GeneratedColumn<int>(
    'schedule_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _stateMeta = const VerificationMeta('state');
  @override
  late final GeneratedColumn<String> state = GeneratedColumn<String>(
    'state',
    aliasedName,
    false,
    check: () =>
        const CustomExpression<bool>("state IN ('confirmed', 'voided')"),
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
  static const VerificationMeta _replacementLeaveIdMeta =
      const VerificationMeta('replacementLeaveId');
  @override
  late final GeneratedColumn<String> replacementLeaveId =
      GeneratedColumn<String>(
        'replacement_leave_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES work_leave_records (id) ON DELETE RESTRICT',
        ),
      );
  static const VerificationMeta _replacedLeaveIdMeta = const VerificationMeta(
    'replacedLeaveId',
  );
  @override
  late final GeneratedColumn<String> replacedLeaveId = GeneratedColumn<String>(
    'replaced_leave_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES work_leave_records (id) ON DELETE RESTRICT',
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
    date,
    leaveType,
    illnessStartedOn,
    paidMinutes,
    agreementId,
    scheduleId,
    scheduleVersion,
    state,
    voidReason,
    replacementLeaveId,
    replacedLeaveId,
    createdAtUtcMicros,
    updatedAtUtcMicros,
    revision,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'work_leave_records';
  @override
  VerificationContext validateIntegrity(
    Insertable<WorkLeaveRecord> instance, {
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
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('leave_type')) {
      context.handle(
        _leaveTypeMeta,
        leaveType.isAcceptableOrUnknown(data['leave_type']!, _leaveTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_leaveTypeMeta);
    }
    if (data.containsKey('illness_started_on')) {
      context.handle(
        _illnessStartedOnMeta,
        illnessStartedOn.isAcceptableOrUnknown(
          data['illness_started_on']!,
          _illnessStartedOnMeta,
        ),
      );
    }
    if (data.containsKey('paid_minutes')) {
      context.handle(
        _paidMinutesMeta,
        paidMinutes.isAcceptableOrUnknown(
          data['paid_minutes']!,
          _paidMinutesMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_paidMinutesMeta);
    }
    if (data.containsKey('agreement_id')) {
      context.handle(
        _agreementIdMeta,
        agreementId.isAcceptableOrUnknown(
          data['agreement_id']!,
          _agreementIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_agreementIdMeta);
    }
    if (data.containsKey('schedule_id')) {
      context.handle(
        _scheduleIdMeta,
        scheduleId.isAcceptableOrUnknown(data['schedule_id']!, _scheduleIdMeta),
      );
    } else if (isInserting) {
      context.missing(_scheduleIdMeta);
    }
    if (data.containsKey('schedule_version')) {
      context.handle(
        _scheduleVersionMeta,
        scheduleVersion.isAcceptableOrUnknown(
          data['schedule_version']!,
          _scheduleVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_scheduleVersionMeta);
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
    if (data.containsKey('replacement_leave_id')) {
      context.handle(
        _replacementLeaveIdMeta,
        replacementLeaveId.isAcceptableOrUnknown(
          data['replacement_leave_id']!,
          _replacementLeaveIdMeta,
        ),
      );
    }
    if (data.containsKey('replaced_leave_id')) {
      context.handle(
        _replacedLeaveIdMeta,
        replacedLeaveId.isAcceptableOrUnknown(
          data['replaced_leave_id']!,
          _replacedLeaveIdMeta,
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
  WorkLeaveRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WorkLeaveRecord(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      employmentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}employment_id'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}date'],
      )!,
      leaveType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}leave_type'],
      )!,
      illnessStartedOn: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}illness_started_on'],
      ),
      paidMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}paid_minutes'],
      )!,
      agreementId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}agreement_id'],
      )!,
      scheduleId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}schedule_id'],
      )!,
      scheduleVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}schedule_version'],
      )!,
      state: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}state'],
      )!,
      voidReason: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}void_reason'],
      ),
      replacementLeaveId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}replacement_leave_id'],
      ),
      replacedLeaveId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}replaced_leave_id'],
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
  $WorkLeaveRecordsTable createAlias(String alias) {
    return $WorkLeaveRecordsTable(attachedDatabase, alias);
  }
}

class WorkLeaveRecord extends DataClass implements Insertable<WorkLeaveRecord> {
  final String id;
  final String employmentId;
  final String date;
  final String leaveType;
  final String? illnessStartedOn;
  final int paidMinutes;
  final String agreementId;
  final String scheduleId;
  final int scheduleVersion;
  final String state;
  final String? voidReason;
  final String? replacementLeaveId;
  final String? replacedLeaveId;
  final int createdAtUtcMicros;
  final int updatedAtUtcMicros;
  final int revision;
  const WorkLeaveRecord({
    required this.id,
    required this.employmentId,
    required this.date,
    required this.leaveType,
    this.illnessStartedOn,
    required this.paidMinutes,
    required this.agreementId,
    required this.scheduleId,
    required this.scheduleVersion,
    required this.state,
    this.voidReason,
    this.replacementLeaveId,
    this.replacedLeaveId,
    required this.createdAtUtcMicros,
    required this.updatedAtUtcMicros,
    required this.revision,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['employment_id'] = Variable<String>(employmentId);
    map['date'] = Variable<String>(date);
    map['leave_type'] = Variable<String>(leaveType);
    if (!nullToAbsent || illnessStartedOn != null) {
      map['illness_started_on'] = Variable<String>(illnessStartedOn);
    }
    map['paid_minutes'] = Variable<int>(paidMinutes);
    map['agreement_id'] = Variable<String>(agreementId);
    map['schedule_id'] = Variable<String>(scheduleId);
    map['schedule_version'] = Variable<int>(scheduleVersion);
    map['state'] = Variable<String>(state);
    if (!nullToAbsent || voidReason != null) {
      map['void_reason'] = Variable<String>(voidReason);
    }
    if (!nullToAbsent || replacementLeaveId != null) {
      map['replacement_leave_id'] = Variable<String>(replacementLeaveId);
    }
    if (!nullToAbsent || replacedLeaveId != null) {
      map['replaced_leave_id'] = Variable<String>(replacedLeaveId);
    }
    map['created_at_utc_micros'] = Variable<int>(createdAtUtcMicros);
    map['updated_at_utc_micros'] = Variable<int>(updatedAtUtcMicros);
    map['revision'] = Variable<int>(revision);
    return map;
  }

  WorkLeaveRecordsCompanion toCompanion(bool nullToAbsent) {
    return WorkLeaveRecordsCompanion(
      id: Value(id),
      employmentId: Value(employmentId),
      date: Value(date),
      leaveType: Value(leaveType),
      illnessStartedOn: illnessStartedOn == null && nullToAbsent
          ? const Value.absent()
          : Value(illnessStartedOn),
      paidMinutes: Value(paidMinutes),
      agreementId: Value(agreementId),
      scheduleId: Value(scheduleId),
      scheduleVersion: Value(scheduleVersion),
      state: Value(state),
      voidReason: voidReason == null && nullToAbsent
          ? const Value.absent()
          : Value(voidReason),
      replacementLeaveId: replacementLeaveId == null && nullToAbsent
          ? const Value.absent()
          : Value(replacementLeaveId),
      replacedLeaveId: replacedLeaveId == null && nullToAbsent
          ? const Value.absent()
          : Value(replacedLeaveId),
      createdAtUtcMicros: Value(createdAtUtcMicros),
      updatedAtUtcMicros: Value(updatedAtUtcMicros),
      revision: Value(revision),
    );
  }

  factory WorkLeaveRecord.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WorkLeaveRecord(
      id: serializer.fromJson<String>(json['id']),
      employmentId: serializer.fromJson<String>(json['employmentId']),
      date: serializer.fromJson<String>(json['date']),
      leaveType: serializer.fromJson<String>(json['leaveType']),
      illnessStartedOn: serializer.fromJson<String?>(json['illnessStartedOn']),
      paidMinutes: serializer.fromJson<int>(json['paidMinutes']),
      agreementId: serializer.fromJson<String>(json['agreementId']),
      scheduleId: serializer.fromJson<String>(json['scheduleId']),
      scheduleVersion: serializer.fromJson<int>(json['scheduleVersion']),
      state: serializer.fromJson<String>(json['state']),
      voidReason: serializer.fromJson<String?>(json['voidReason']),
      replacementLeaveId: serializer.fromJson<String?>(
        json['replacementLeaveId'],
      ),
      replacedLeaveId: serializer.fromJson<String?>(json['replacedLeaveId']),
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
      'date': serializer.toJson<String>(date),
      'leaveType': serializer.toJson<String>(leaveType),
      'illnessStartedOn': serializer.toJson<String?>(illnessStartedOn),
      'paidMinutes': serializer.toJson<int>(paidMinutes),
      'agreementId': serializer.toJson<String>(agreementId),
      'scheduleId': serializer.toJson<String>(scheduleId),
      'scheduleVersion': serializer.toJson<int>(scheduleVersion),
      'state': serializer.toJson<String>(state),
      'voidReason': serializer.toJson<String?>(voidReason),
      'replacementLeaveId': serializer.toJson<String?>(replacementLeaveId),
      'replacedLeaveId': serializer.toJson<String?>(replacedLeaveId),
      'createdAtUtcMicros': serializer.toJson<int>(createdAtUtcMicros),
      'updatedAtUtcMicros': serializer.toJson<int>(updatedAtUtcMicros),
      'revision': serializer.toJson<int>(revision),
    };
  }

  WorkLeaveRecord copyWith({
    String? id,
    String? employmentId,
    String? date,
    String? leaveType,
    Value<String?> illnessStartedOn = const Value.absent(),
    int? paidMinutes,
    String? agreementId,
    String? scheduleId,
    int? scheduleVersion,
    String? state,
    Value<String?> voidReason = const Value.absent(),
    Value<String?> replacementLeaveId = const Value.absent(),
    Value<String?> replacedLeaveId = const Value.absent(),
    int? createdAtUtcMicros,
    int? updatedAtUtcMicros,
    int? revision,
  }) => WorkLeaveRecord(
    id: id ?? this.id,
    employmentId: employmentId ?? this.employmentId,
    date: date ?? this.date,
    leaveType: leaveType ?? this.leaveType,
    illnessStartedOn: illnessStartedOn.present
        ? illnessStartedOn.value
        : this.illnessStartedOn,
    paidMinutes: paidMinutes ?? this.paidMinutes,
    agreementId: agreementId ?? this.agreementId,
    scheduleId: scheduleId ?? this.scheduleId,
    scheduleVersion: scheduleVersion ?? this.scheduleVersion,
    state: state ?? this.state,
    voidReason: voidReason.present ? voidReason.value : this.voidReason,
    replacementLeaveId: replacementLeaveId.present
        ? replacementLeaveId.value
        : this.replacementLeaveId,
    replacedLeaveId: replacedLeaveId.present
        ? replacedLeaveId.value
        : this.replacedLeaveId,
    createdAtUtcMicros: createdAtUtcMicros ?? this.createdAtUtcMicros,
    updatedAtUtcMicros: updatedAtUtcMicros ?? this.updatedAtUtcMicros,
    revision: revision ?? this.revision,
  );
  WorkLeaveRecord copyWithCompanion(WorkLeaveRecordsCompanion data) {
    return WorkLeaveRecord(
      id: data.id.present ? data.id.value : this.id,
      employmentId: data.employmentId.present
          ? data.employmentId.value
          : this.employmentId,
      date: data.date.present ? data.date.value : this.date,
      leaveType: data.leaveType.present ? data.leaveType.value : this.leaveType,
      illnessStartedOn: data.illnessStartedOn.present
          ? data.illnessStartedOn.value
          : this.illnessStartedOn,
      paidMinutes: data.paidMinutes.present
          ? data.paidMinutes.value
          : this.paidMinutes,
      agreementId: data.agreementId.present
          ? data.agreementId.value
          : this.agreementId,
      scheduleId: data.scheduleId.present
          ? data.scheduleId.value
          : this.scheduleId,
      scheduleVersion: data.scheduleVersion.present
          ? data.scheduleVersion.value
          : this.scheduleVersion,
      state: data.state.present ? data.state.value : this.state,
      voidReason: data.voidReason.present
          ? data.voidReason.value
          : this.voidReason,
      replacementLeaveId: data.replacementLeaveId.present
          ? data.replacementLeaveId.value
          : this.replacementLeaveId,
      replacedLeaveId: data.replacedLeaveId.present
          ? data.replacedLeaveId.value
          : this.replacedLeaveId,
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
    return (StringBuffer('WorkLeaveRecord(')
          ..write('id: $id, ')
          ..write('employmentId: $employmentId, ')
          ..write('date: $date, ')
          ..write('leaveType: $leaveType, ')
          ..write('illnessStartedOn: $illnessStartedOn, ')
          ..write('paidMinutes: $paidMinutes, ')
          ..write('agreementId: $agreementId, ')
          ..write('scheduleId: $scheduleId, ')
          ..write('scheduleVersion: $scheduleVersion, ')
          ..write('state: $state, ')
          ..write('voidReason: $voidReason, ')
          ..write('replacementLeaveId: $replacementLeaveId, ')
          ..write('replacedLeaveId: $replacedLeaveId, ')
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
    date,
    leaveType,
    illnessStartedOn,
    paidMinutes,
    agreementId,
    scheduleId,
    scheduleVersion,
    state,
    voidReason,
    replacementLeaveId,
    replacedLeaveId,
    createdAtUtcMicros,
    updatedAtUtcMicros,
    revision,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WorkLeaveRecord &&
          other.id == this.id &&
          other.employmentId == this.employmentId &&
          other.date == this.date &&
          other.leaveType == this.leaveType &&
          other.illnessStartedOn == this.illnessStartedOn &&
          other.paidMinutes == this.paidMinutes &&
          other.agreementId == this.agreementId &&
          other.scheduleId == this.scheduleId &&
          other.scheduleVersion == this.scheduleVersion &&
          other.state == this.state &&
          other.voidReason == this.voidReason &&
          other.replacementLeaveId == this.replacementLeaveId &&
          other.replacedLeaveId == this.replacedLeaveId &&
          other.createdAtUtcMicros == this.createdAtUtcMicros &&
          other.updatedAtUtcMicros == this.updatedAtUtcMicros &&
          other.revision == this.revision);
}

class WorkLeaveRecordsCompanion extends UpdateCompanion<WorkLeaveRecord> {
  final Value<String> id;
  final Value<String> employmentId;
  final Value<String> date;
  final Value<String> leaveType;
  final Value<String?> illnessStartedOn;
  final Value<int> paidMinutes;
  final Value<String> agreementId;
  final Value<String> scheduleId;
  final Value<int> scheduleVersion;
  final Value<String> state;
  final Value<String?> voidReason;
  final Value<String?> replacementLeaveId;
  final Value<String?> replacedLeaveId;
  final Value<int> createdAtUtcMicros;
  final Value<int> updatedAtUtcMicros;
  final Value<int> revision;
  final Value<int> rowid;
  const WorkLeaveRecordsCompanion({
    this.id = const Value.absent(),
    this.employmentId = const Value.absent(),
    this.date = const Value.absent(),
    this.leaveType = const Value.absent(),
    this.illnessStartedOn = const Value.absent(),
    this.paidMinutes = const Value.absent(),
    this.agreementId = const Value.absent(),
    this.scheduleId = const Value.absent(),
    this.scheduleVersion = const Value.absent(),
    this.state = const Value.absent(),
    this.voidReason = const Value.absent(),
    this.replacementLeaveId = const Value.absent(),
    this.replacedLeaveId = const Value.absent(),
    this.createdAtUtcMicros = const Value.absent(),
    this.updatedAtUtcMicros = const Value.absent(),
    this.revision = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WorkLeaveRecordsCompanion.insert({
    required String id,
    required String employmentId,
    required String date,
    required String leaveType,
    this.illnessStartedOn = const Value.absent(),
    required int paidMinutes,
    required String agreementId,
    required String scheduleId,
    required int scheduleVersion,
    required String state,
    this.voidReason = const Value.absent(),
    this.replacementLeaveId = const Value.absent(),
    this.replacedLeaveId = const Value.absent(),
    required int createdAtUtcMicros,
    required int updatedAtUtcMicros,
    required int revision,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       employmentId = Value(employmentId),
       date = Value(date),
       leaveType = Value(leaveType),
       paidMinutes = Value(paidMinutes),
       agreementId = Value(agreementId),
       scheduleId = Value(scheduleId),
       scheduleVersion = Value(scheduleVersion),
       state = Value(state),
       createdAtUtcMicros = Value(createdAtUtcMicros),
       updatedAtUtcMicros = Value(updatedAtUtcMicros),
       revision = Value(revision);
  static Insertable<WorkLeaveRecord> custom({
    Expression<String>? id,
    Expression<String>? employmentId,
    Expression<String>? date,
    Expression<String>? leaveType,
    Expression<String>? illnessStartedOn,
    Expression<int>? paidMinutes,
    Expression<String>? agreementId,
    Expression<String>? scheduleId,
    Expression<int>? scheduleVersion,
    Expression<String>? state,
    Expression<String>? voidReason,
    Expression<String>? replacementLeaveId,
    Expression<String>? replacedLeaveId,
    Expression<int>? createdAtUtcMicros,
    Expression<int>? updatedAtUtcMicros,
    Expression<int>? revision,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (employmentId != null) 'employment_id': employmentId,
      if (date != null) 'date': date,
      if (leaveType != null) 'leave_type': leaveType,
      if (illnessStartedOn != null) 'illness_started_on': illnessStartedOn,
      if (paidMinutes != null) 'paid_minutes': paidMinutes,
      if (agreementId != null) 'agreement_id': agreementId,
      if (scheduleId != null) 'schedule_id': scheduleId,
      if (scheduleVersion != null) 'schedule_version': scheduleVersion,
      if (state != null) 'state': state,
      if (voidReason != null) 'void_reason': voidReason,
      if (replacementLeaveId != null)
        'replacement_leave_id': replacementLeaveId,
      if (replacedLeaveId != null) 'replaced_leave_id': replacedLeaveId,
      if (createdAtUtcMicros != null)
        'created_at_utc_micros': createdAtUtcMicros,
      if (updatedAtUtcMicros != null)
        'updated_at_utc_micros': updatedAtUtcMicros,
      if (revision != null) 'revision': revision,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WorkLeaveRecordsCompanion copyWith({
    Value<String>? id,
    Value<String>? employmentId,
    Value<String>? date,
    Value<String>? leaveType,
    Value<String?>? illnessStartedOn,
    Value<int>? paidMinutes,
    Value<String>? agreementId,
    Value<String>? scheduleId,
    Value<int>? scheduleVersion,
    Value<String>? state,
    Value<String?>? voidReason,
    Value<String?>? replacementLeaveId,
    Value<String?>? replacedLeaveId,
    Value<int>? createdAtUtcMicros,
    Value<int>? updatedAtUtcMicros,
    Value<int>? revision,
    Value<int>? rowid,
  }) {
    return WorkLeaveRecordsCompanion(
      id: id ?? this.id,
      employmentId: employmentId ?? this.employmentId,
      date: date ?? this.date,
      leaveType: leaveType ?? this.leaveType,
      illnessStartedOn: illnessStartedOn ?? this.illnessStartedOn,
      paidMinutes: paidMinutes ?? this.paidMinutes,
      agreementId: agreementId ?? this.agreementId,
      scheduleId: scheduleId ?? this.scheduleId,
      scheduleVersion: scheduleVersion ?? this.scheduleVersion,
      state: state ?? this.state,
      voidReason: voidReason ?? this.voidReason,
      replacementLeaveId: replacementLeaveId ?? this.replacementLeaveId,
      replacedLeaveId: replacedLeaveId ?? this.replacedLeaveId,
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
    if (date.present) {
      map['date'] = Variable<String>(date.value);
    }
    if (leaveType.present) {
      map['leave_type'] = Variable<String>(leaveType.value);
    }
    if (illnessStartedOn.present) {
      map['illness_started_on'] = Variable<String>(illnessStartedOn.value);
    }
    if (paidMinutes.present) {
      map['paid_minutes'] = Variable<int>(paidMinutes.value);
    }
    if (agreementId.present) {
      map['agreement_id'] = Variable<String>(agreementId.value);
    }
    if (scheduleId.present) {
      map['schedule_id'] = Variable<String>(scheduleId.value);
    }
    if (scheduleVersion.present) {
      map['schedule_version'] = Variable<int>(scheduleVersion.value);
    }
    if (state.present) {
      map['state'] = Variable<String>(state.value);
    }
    if (voidReason.present) {
      map['void_reason'] = Variable<String>(voidReason.value);
    }
    if (replacementLeaveId.present) {
      map['replacement_leave_id'] = Variable<String>(replacementLeaveId.value);
    }
    if (replacedLeaveId.present) {
      map['replaced_leave_id'] = Variable<String>(replacedLeaveId.value);
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
    return (StringBuffer('WorkLeaveRecordsCompanion(')
          ..write('id: $id, ')
          ..write('employmentId: $employmentId, ')
          ..write('date: $date, ')
          ..write('leaveType: $leaveType, ')
          ..write('illnessStartedOn: $illnessStartedOn, ')
          ..write('paidMinutes: $paidMinutes, ')
          ..write('agreementId: $agreementId, ')
          ..write('scheduleId: $scheduleId, ')
          ..write('scheduleVersion: $scheduleVersion, ')
          ..write('state: $state, ')
          ..write('voidReason: $voidReason, ')
          ..write('replacementLeaveId: $replacementLeaveId, ')
          ..write('replacedLeaveId: $replacedLeaveId, ')
          ..write('createdAtUtcMicros: $createdAtUtcMicros, ')
          ..write('updatedAtUtcMicros: $updatedAtUtcMicros, ')
          ..write('revision: $revision, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RecordEventsTable extends RecordEvents
    with TableInfo<$RecordEventsTable, RecordEventRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RecordEventsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _recordKindMeta = const VerificationMeta(
    'recordKind',
  );
  @override
  late final GeneratedColumn<String> recordKind = GeneratedColumn<String>(
    'record_kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _recordIdMeta = const VerificationMeta(
    'recordId',
  );
  @override
  late final GeneratedColumn<String> recordId = GeneratedColumn<String>(
    'record_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _atUtcMicrosMeta = const VerificationMeta(
    'atUtcMicros',
  );
  @override
  late final GeneratedColumn<int> atUtcMicros = GeneratedColumn<int>(
    'at_utc_micros',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    check: () => const CustomExpression<bool>(
      "kind IN ('created', 'changed', 'finalized', 'voided', 'replaced', "
      "'reviewed')",
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _changesJsonMeta = const VerificationMeta(
    'changesJson',
  );
  @override
  late final GeneratedColumn<String> changesJson = GeneratedColumn<String>(
    'changes_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _reasonMeta = const VerificationMeta('reason');
  @override
  late final GeneratedColumn<String> reason = GeneratedColumn<String>(
    'reason',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _revisionAfterMeta = const VerificationMeta(
    'revisionAfter',
  );
  @override
  late final GeneratedColumn<int> revisionAfter = GeneratedColumn<int>(
    'revision_after',
    aliasedName,
    false,
    check: () => const CustomExpression<bool>('revision_after >= 0'),
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    recordKind,
    recordId,
    atUtcMicros,
    kind,
    changesJson,
    reason,
    revisionAfter,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'record_events';
  @override
  VerificationContext validateIntegrity(
    Insertable<RecordEventRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('record_kind')) {
      context.handle(
        _recordKindMeta,
        recordKind.isAcceptableOrUnknown(data['record_kind']!, _recordKindMeta),
      );
    } else if (isInserting) {
      context.missing(_recordKindMeta);
    }
    if (data.containsKey('record_id')) {
      context.handle(
        _recordIdMeta,
        recordId.isAcceptableOrUnknown(data['record_id']!, _recordIdMeta),
      );
    } else if (isInserting) {
      context.missing(_recordIdMeta);
    }
    if (data.containsKey('at_utc_micros')) {
      context.handle(
        _atUtcMicrosMeta,
        atUtcMicros.isAcceptableOrUnknown(
          data['at_utc_micros']!,
          _atUtcMicrosMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_atUtcMicrosMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('changes_json')) {
      context.handle(
        _changesJsonMeta,
        changesJson.isAcceptableOrUnknown(
          data['changes_json']!,
          _changesJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_changesJsonMeta);
    }
    if (data.containsKey('reason')) {
      context.handle(
        _reasonMeta,
        reason.isAcceptableOrUnknown(data['reason']!, _reasonMeta),
      );
    }
    if (data.containsKey('revision_after')) {
      context.handle(
        _revisionAfterMeta,
        revisionAfter.isAcceptableOrUnknown(
          data['revision_after']!,
          _revisionAfterMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_revisionAfterMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RecordEventRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RecordEventRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      recordKind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}record_kind'],
      )!,
      recordId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}record_id'],
      )!,
      atUtcMicros: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}at_utc_micros'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      changesJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}changes_json'],
      )!,
      reason: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reason'],
      ),
      revisionAfter: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}revision_after'],
      )!,
    );
  }

  @override
  $RecordEventsTable createAlias(String alias) {
    return $RecordEventsTable(attachedDatabase, alias);
  }
}

class RecordEventRow extends DataClass implements Insertable<RecordEventRow> {
  final int id;
  final String recordKind;
  final String recordId;
  final int atUtcMicros;
  final String kind;
  final String changesJson;
  final String? reason;
  final int revisionAfter;
  const RecordEventRow({
    required this.id,
    required this.recordKind,
    required this.recordId,
    required this.atUtcMicros,
    required this.kind,
    required this.changesJson,
    this.reason,
    required this.revisionAfter,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['record_kind'] = Variable<String>(recordKind);
    map['record_id'] = Variable<String>(recordId);
    map['at_utc_micros'] = Variable<int>(atUtcMicros);
    map['kind'] = Variable<String>(kind);
    map['changes_json'] = Variable<String>(changesJson);
    if (!nullToAbsent || reason != null) {
      map['reason'] = Variable<String>(reason);
    }
    map['revision_after'] = Variable<int>(revisionAfter);
    return map;
  }

  RecordEventsCompanion toCompanion(bool nullToAbsent) {
    return RecordEventsCompanion(
      id: Value(id),
      recordKind: Value(recordKind),
      recordId: Value(recordId),
      atUtcMicros: Value(atUtcMicros),
      kind: Value(kind),
      changesJson: Value(changesJson),
      reason: reason == null && nullToAbsent
          ? const Value.absent()
          : Value(reason),
      revisionAfter: Value(revisionAfter),
    );
  }

  factory RecordEventRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RecordEventRow(
      id: serializer.fromJson<int>(json['id']),
      recordKind: serializer.fromJson<String>(json['recordKind']),
      recordId: serializer.fromJson<String>(json['recordId']),
      atUtcMicros: serializer.fromJson<int>(json['atUtcMicros']),
      kind: serializer.fromJson<String>(json['kind']),
      changesJson: serializer.fromJson<String>(json['changesJson']),
      reason: serializer.fromJson<String?>(json['reason']),
      revisionAfter: serializer.fromJson<int>(json['revisionAfter']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'recordKind': serializer.toJson<String>(recordKind),
      'recordId': serializer.toJson<String>(recordId),
      'atUtcMicros': serializer.toJson<int>(atUtcMicros),
      'kind': serializer.toJson<String>(kind),
      'changesJson': serializer.toJson<String>(changesJson),
      'reason': serializer.toJson<String?>(reason),
      'revisionAfter': serializer.toJson<int>(revisionAfter),
    };
  }

  RecordEventRow copyWith({
    int? id,
    String? recordKind,
    String? recordId,
    int? atUtcMicros,
    String? kind,
    String? changesJson,
    Value<String?> reason = const Value.absent(),
    int? revisionAfter,
  }) => RecordEventRow(
    id: id ?? this.id,
    recordKind: recordKind ?? this.recordKind,
    recordId: recordId ?? this.recordId,
    atUtcMicros: atUtcMicros ?? this.atUtcMicros,
    kind: kind ?? this.kind,
    changesJson: changesJson ?? this.changesJson,
    reason: reason.present ? reason.value : this.reason,
    revisionAfter: revisionAfter ?? this.revisionAfter,
  );
  RecordEventRow copyWithCompanion(RecordEventsCompanion data) {
    return RecordEventRow(
      id: data.id.present ? data.id.value : this.id,
      recordKind: data.recordKind.present
          ? data.recordKind.value
          : this.recordKind,
      recordId: data.recordId.present ? data.recordId.value : this.recordId,
      atUtcMicros: data.atUtcMicros.present
          ? data.atUtcMicros.value
          : this.atUtcMicros,
      kind: data.kind.present ? data.kind.value : this.kind,
      changesJson: data.changesJson.present
          ? data.changesJson.value
          : this.changesJson,
      reason: data.reason.present ? data.reason.value : this.reason,
      revisionAfter: data.revisionAfter.present
          ? data.revisionAfter.value
          : this.revisionAfter,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RecordEventRow(')
          ..write('id: $id, ')
          ..write('recordKind: $recordKind, ')
          ..write('recordId: $recordId, ')
          ..write('atUtcMicros: $atUtcMicros, ')
          ..write('kind: $kind, ')
          ..write('changesJson: $changesJson, ')
          ..write('reason: $reason, ')
          ..write('revisionAfter: $revisionAfter')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    recordKind,
    recordId,
    atUtcMicros,
    kind,
    changesJson,
    reason,
    revisionAfter,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RecordEventRow &&
          other.id == this.id &&
          other.recordKind == this.recordKind &&
          other.recordId == this.recordId &&
          other.atUtcMicros == this.atUtcMicros &&
          other.kind == this.kind &&
          other.changesJson == this.changesJson &&
          other.reason == this.reason &&
          other.revisionAfter == this.revisionAfter);
}

class RecordEventsCompanion extends UpdateCompanion<RecordEventRow> {
  final Value<int> id;
  final Value<String> recordKind;
  final Value<String> recordId;
  final Value<int> atUtcMicros;
  final Value<String> kind;
  final Value<String> changesJson;
  final Value<String?> reason;
  final Value<int> revisionAfter;
  const RecordEventsCompanion({
    this.id = const Value.absent(),
    this.recordKind = const Value.absent(),
    this.recordId = const Value.absent(),
    this.atUtcMicros = const Value.absent(),
    this.kind = const Value.absent(),
    this.changesJson = const Value.absent(),
    this.reason = const Value.absent(),
    this.revisionAfter = const Value.absent(),
  });
  RecordEventsCompanion.insert({
    this.id = const Value.absent(),
    required String recordKind,
    required String recordId,
    required int atUtcMicros,
    required String kind,
    required String changesJson,
    this.reason = const Value.absent(),
    required int revisionAfter,
  }) : recordKind = Value(recordKind),
       recordId = Value(recordId),
       atUtcMicros = Value(atUtcMicros),
       kind = Value(kind),
       changesJson = Value(changesJson),
       revisionAfter = Value(revisionAfter);
  static Insertable<RecordEventRow> custom({
    Expression<int>? id,
    Expression<String>? recordKind,
    Expression<String>? recordId,
    Expression<int>? atUtcMicros,
    Expression<String>? kind,
    Expression<String>? changesJson,
    Expression<String>? reason,
    Expression<int>? revisionAfter,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (recordKind != null) 'record_kind': recordKind,
      if (recordId != null) 'record_id': recordId,
      if (atUtcMicros != null) 'at_utc_micros': atUtcMicros,
      if (kind != null) 'kind': kind,
      if (changesJson != null) 'changes_json': changesJson,
      if (reason != null) 'reason': reason,
      if (revisionAfter != null) 'revision_after': revisionAfter,
    });
  }

  RecordEventsCompanion copyWith({
    Value<int>? id,
    Value<String>? recordKind,
    Value<String>? recordId,
    Value<int>? atUtcMicros,
    Value<String>? kind,
    Value<String>? changesJson,
    Value<String?>? reason,
    Value<int>? revisionAfter,
  }) {
    return RecordEventsCompanion(
      id: id ?? this.id,
      recordKind: recordKind ?? this.recordKind,
      recordId: recordId ?? this.recordId,
      atUtcMicros: atUtcMicros ?? this.atUtcMicros,
      kind: kind ?? this.kind,
      changesJson: changesJson ?? this.changesJson,
      reason: reason ?? this.reason,
      revisionAfter: revisionAfter ?? this.revisionAfter,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (recordKind.present) {
      map['record_kind'] = Variable<String>(recordKind.value);
    }
    if (recordId.present) {
      map['record_id'] = Variable<String>(recordId.value);
    }
    if (atUtcMicros.present) {
      map['at_utc_micros'] = Variable<int>(atUtcMicros.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (changesJson.present) {
      map['changes_json'] = Variable<String>(changesJson.value);
    }
    if (reason.present) {
      map['reason'] = Variable<String>(reason.value);
    }
    if (revisionAfter.present) {
      map['revision_after'] = Variable<int>(revisionAfter.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RecordEventsCompanion(')
          ..write('id: $id, ')
          ..write('recordKind: $recordKind, ')
          ..write('recordId: $recordId, ')
          ..write('atUtcMicros: $atUtcMicros, ')
          ..write('kind: $kind, ')
          ..write('changesJson: $changesJson, ')
          ..write('reason: $reason, ')
          ..write('revisionAfter: $revisionAfter')
          ..write(')'))
        .toString();
  }
}

class $DesksTable extends Desks with TableInfo<$DesksTable, DeskRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DesksTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _starterKeyMeta = const VerificationMeta(
    'starterKey',
  );
  @override
  late final GeneratedColumn<String> starterKey = GeneratedColumn<String>(
    'starter_key',
    aliasedName,
    true,
    check: () => const CustomExpression<bool>(
      'starter_key IS NULL OR starter_key IN '
      "('today', 'weeklyReview', 'monthClose')",
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _layoutMeta = const VerificationMeta('layout');
  @override
  late final GeneratedColumn<String> layout = GeneratedColumn<String>(
    'layout',
    aliasedName,
    false,
    check: () => const CustomExpression<bool>(
      "layout IN ('single', 'twoColumns', 'mainAndSide')",
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
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
    starterKey,
    layout,
    position,
    revision,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'desks';
  @override
  VerificationContext validateIntegrity(
    Insertable<DeskRow> instance, {
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
    if (data.containsKey('starter_key')) {
      context.handle(
        _starterKeyMeta,
        starterKey.isAcceptableOrUnknown(data['starter_key']!, _starterKeyMeta),
      );
    }
    if (data.containsKey('layout')) {
      context.handle(
        _layoutMeta,
        layout.isAcceptableOrUnknown(data['layout']!, _layoutMeta),
      );
    } else if (isInserting) {
      context.missing(_layoutMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
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
  DeskRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DeskRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      starterKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}starter_key'],
      ),
      layout: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}layout'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
      revision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}revision'],
      )!,
    );
  }

  @override
  $DesksTable createAlias(String alias) {
    return $DesksTable(attachedDatabase, alias);
  }
}

class DeskRow extends DataClass implements Insertable<DeskRow> {
  final String id;
  final String name;
  final String? starterKey;
  final String layout;
  final int position;
  final int revision;
  const DeskRow({
    required this.id,
    required this.name,
    this.starterKey,
    required this.layout,
    required this.position,
    required this.revision,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || starterKey != null) {
      map['starter_key'] = Variable<String>(starterKey);
    }
    map['layout'] = Variable<String>(layout);
    map['position'] = Variable<int>(position);
    map['revision'] = Variable<int>(revision);
    return map;
  }

  DesksCompanion toCompanion(bool nullToAbsent) {
    return DesksCompanion(
      id: Value(id),
      name: Value(name),
      starterKey: starterKey == null && nullToAbsent
          ? const Value.absent()
          : Value(starterKey),
      layout: Value(layout),
      position: Value(position),
      revision: Value(revision),
    );
  }

  factory DeskRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DeskRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      starterKey: serializer.fromJson<String?>(json['starterKey']),
      layout: serializer.fromJson<String>(json['layout']),
      position: serializer.fromJson<int>(json['position']),
      revision: serializer.fromJson<int>(json['revision']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'starterKey': serializer.toJson<String?>(starterKey),
      'layout': serializer.toJson<String>(layout),
      'position': serializer.toJson<int>(position),
      'revision': serializer.toJson<int>(revision),
    };
  }

  DeskRow copyWith({
    String? id,
    String? name,
    Value<String?> starterKey = const Value.absent(),
    String? layout,
    int? position,
    int? revision,
  }) => DeskRow(
    id: id ?? this.id,
    name: name ?? this.name,
    starterKey: starterKey.present ? starterKey.value : this.starterKey,
    layout: layout ?? this.layout,
    position: position ?? this.position,
    revision: revision ?? this.revision,
  );
  DeskRow copyWithCompanion(DesksCompanion data) {
    return DeskRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      starterKey: data.starterKey.present
          ? data.starterKey.value
          : this.starterKey,
      layout: data.layout.present ? data.layout.value : this.layout,
      position: data.position.present ? data.position.value : this.position,
      revision: data.revision.present ? data.revision.value : this.revision,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DeskRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('starterKey: $starterKey, ')
          ..write('layout: $layout, ')
          ..write('position: $position, ')
          ..write('revision: $revision')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, name, starterKey, layout, position, revision);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DeskRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.starterKey == this.starterKey &&
          other.layout == this.layout &&
          other.position == this.position &&
          other.revision == this.revision);
}

class DesksCompanion extends UpdateCompanion<DeskRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<String?> starterKey;
  final Value<String> layout;
  final Value<int> position;
  final Value<int> revision;
  final Value<int> rowid;
  const DesksCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.starterKey = const Value.absent(),
    this.layout = const Value.absent(),
    this.position = const Value.absent(),
    this.revision = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DesksCompanion.insert({
    required String id,
    required String name,
    this.starterKey = const Value.absent(),
    required String layout,
    required int position,
    required int revision,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       layout = Value(layout),
       position = Value(position),
       revision = Value(revision);
  static Insertable<DeskRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? starterKey,
    Expression<String>? layout,
    Expression<int>? position,
    Expression<int>? revision,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (starterKey != null) 'starter_key': starterKey,
      if (layout != null) 'layout': layout,
      if (position != null) 'position': position,
      if (revision != null) 'revision': revision,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DesksCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String?>? starterKey,
    Value<String>? layout,
    Value<int>? position,
    Value<int>? revision,
    Value<int>? rowid,
  }) {
    return DesksCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      starterKey: starterKey ?? this.starterKey,
      layout: layout ?? this.layout,
      position: position ?? this.position,
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
    if (starterKey.present) {
      map['starter_key'] = Variable<String>(starterKey.value);
    }
    if (layout.present) {
      map['layout'] = Variable<String>(layout.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
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
    return (StringBuffer('DesksCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('starterKey: $starterKey, ')
          ..write('layout: $layout, ')
          ..write('position: $position, ')
          ..write('revision: $revision, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SavedViewsTable extends SavedViews
    with TableInfo<$SavedViewsTable, SavedViewRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SavedViewsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _sheetRefMeta = const VerificationMeta(
    'sheetRef',
  );
  @override
  late final GeneratedColumn<String> sheetRef = GeneratedColumn<String>(
    'sheet_ref',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _filtersJsonMeta = const VerificationMeta(
    'filtersJson',
  );
  @override
  late final GeneratedColumn<String> filtersJson = GeneratedColumn<String>(
    'filters_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sortJsonMeta = const VerificationMeta(
    'sortJson',
  );
  @override
  late final GeneratedColumn<String> sortJson = GeneratedColumn<String>(
    'sort_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _columnsJsonMeta = const VerificationMeta(
    'columnsJson',
  );
  @override
  late final GeneratedColumn<String> columnsJson = GeneratedColumn<String>(
    'columns_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
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
    sheetRef,
    filtersJson,
    sortJson,
    columnsJson,
    position,
    revision,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'saved_views';
  @override
  VerificationContext validateIntegrity(
    Insertable<SavedViewRow> instance, {
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
    if (data.containsKey('sheet_ref')) {
      context.handle(
        _sheetRefMeta,
        sheetRef.isAcceptableOrUnknown(data['sheet_ref']!, _sheetRefMeta),
      );
    } else if (isInserting) {
      context.missing(_sheetRefMeta);
    }
    if (data.containsKey('filters_json')) {
      context.handle(
        _filtersJsonMeta,
        filtersJson.isAcceptableOrUnknown(
          data['filters_json']!,
          _filtersJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_filtersJsonMeta);
    }
    if (data.containsKey('sort_json')) {
      context.handle(
        _sortJsonMeta,
        sortJson.isAcceptableOrUnknown(data['sort_json']!, _sortJsonMeta),
      );
    }
    if (data.containsKey('columns_json')) {
      context.handle(
        _columnsJsonMeta,
        columnsJson.isAcceptableOrUnknown(
          data['columns_json']!,
          _columnsJsonMeta,
        ),
      );
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
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
  SavedViewRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SavedViewRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      sheetRef: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sheet_ref'],
      )!,
      filtersJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}filters_json'],
      )!,
      sortJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sort_json'],
      ),
      columnsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}columns_json'],
      ),
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
      revision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}revision'],
      )!,
    );
  }

  @override
  $SavedViewsTable createAlias(String alias) {
    return $SavedViewsTable(attachedDatabase, alias);
  }
}

class SavedViewRow extends DataClass implements Insertable<SavedViewRow> {
  final String id;
  final String name;
  final String sheetRef;
  final String filtersJson;
  final String? sortJson;
  final String? columnsJson;
  final int position;
  final int revision;
  const SavedViewRow({
    required this.id,
    required this.name,
    required this.sheetRef,
    required this.filtersJson,
    this.sortJson,
    this.columnsJson,
    required this.position,
    required this.revision,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['sheet_ref'] = Variable<String>(sheetRef);
    map['filters_json'] = Variable<String>(filtersJson);
    if (!nullToAbsent || sortJson != null) {
      map['sort_json'] = Variable<String>(sortJson);
    }
    if (!nullToAbsent || columnsJson != null) {
      map['columns_json'] = Variable<String>(columnsJson);
    }
    map['position'] = Variable<int>(position);
    map['revision'] = Variable<int>(revision);
    return map;
  }

  SavedViewsCompanion toCompanion(bool nullToAbsent) {
    return SavedViewsCompanion(
      id: Value(id),
      name: Value(name),
      sheetRef: Value(sheetRef),
      filtersJson: Value(filtersJson),
      sortJson: sortJson == null && nullToAbsent
          ? const Value.absent()
          : Value(sortJson),
      columnsJson: columnsJson == null && nullToAbsent
          ? const Value.absent()
          : Value(columnsJson),
      position: Value(position),
      revision: Value(revision),
    );
  }

  factory SavedViewRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SavedViewRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      sheetRef: serializer.fromJson<String>(json['sheetRef']),
      filtersJson: serializer.fromJson<String>(json['filtersJson']),
      sortJson: serializer.fromJson<String?>(json['sortJson']),
      columnsJson: serializer.fromJson<String?>(json['columnsJson']),
      position: serializer.fromJson<int>(json['position']),
      revision: serializer.fromJson<int>(json['revision']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'sheetRef': serializer.toJson<String>(sheetRef),
      'filtersJson': serializer.toJson<String>(filtersJson),
      'sortJson': serializer.toJson<String?>(sortJson),
      'columnsJson': serializer.toJson<String?>(columnsJson),
      'position': serializer.toJson<int>(position),
      'revision': serializer.toJson<int>(revision),
    };
  }

  SavedViewRow copyWith({
    String? id,
    String? name,
    String? sheetRef,
    String? filtersJson,
    Value<String?> sortJson = const Value.absent(),
    Value<String?> columnsJson = const Value.absent(),
    int? position,
    int? revision,
  }) => SavedViewRow(
    id: id ?? this.id,
    name: name ?? this.name,
    sheetRef: sheetRef ?? this.sheetRef,
    filtersJson: filtersJson ?? this.filtersJson,
    sortJson: sortJson.present ? sortJson.value : this.sortJson,
    columnsJson: columnsJson.present ? columnsJson.value : this.columnsJson,
    position: position ?? this.position,
    revision: revision ?? this.revision,
  );
  SavedViewRow copyWithCompanion(SavedViewsCompanion data) {
    return SavedViewRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      sheetRef: data.sheetRef.present ? data.sheetRef.value : this.sheetRef,
      filtersJson: data.filtersJson.present
          ? data.filtersJson.value
          : this.filtersJson,
      sortJson: data.sortJson.present ? data.sortJson.value : this.sortJson,
      columnsJson: data.columnsJson.present
          ? data.columnsJson.value
          : this.columnsJson,
      position: data.position.present ? data.position.value : this.position,
      revision: data.revision.present ? data.revision.value : this.revision,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SavedViewRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('sheetRef: $sheetRef, ')
          ..write('filtersJson: $filtersJson, ')
          ..write('sortJson: $sortJson, ')
          ..write('columnsJson: $columnsJson, ')
          ..write('position: $position, ')
          ..write('revision: $revision')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    sheetRef,
    filtersJson,
    sortJson,
    columnsJson,
    position,
    revision,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SavedViewRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.sheetRef == this.sheetRef &&
          other.filtersJson == this.filtersJson &&
          other.sortJson == this.sortJson &&
          other.columnsJson == this.columnsJson &&
          other.position == this.position &&
          other.revision == this.revision);
}

class SavedViewsCompanion extends UpdateCompanion<SavedViewRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> sheetRef;
  final Value<String> filtersJson;
  final Value<String?> sortJson;
  final Value<String?> columnsJson;
  final Value<int> position;
  final Value<int> revision;
  final Value<int> rowid;
  const SavedViewsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.sheetRef = const Value.absent(),
    this.filtersJson = const Value.absent(),
    this.sortJson = const Value.absent(),
    this.columnsJson = const Value.absent(),
    this.position = const Value.absent(),
    this.revision = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SavedViewsCompanion.insert({
    required String id,
    required String name,
    required String sheetRef,
    required String filtersJson,
    this.sortJson = const Value.absent(),
    this.columnsJson = const Value.absent(),
    required int position,
    required int revision,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       sheetRef = Value(sheetRef),
       filtersJson = Value(filtersJson),
       position = Value(position),
       revision = Value(revision);
  static Insertable<SavedViewRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? sheetRef,
    Expression<String>? filtersJson,
    Expression<String>? sortJson,
    Expression<String>? columnsJson,
    Expression<int>? position,
    Expression<int>? revision,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (sheetRef != null) 'sheet_ref': sheetRef,
      if (filtersJson != null) 'filters_json': filtersJson,
      if (sortJson != null) 'sort_json': sortJson,
      if (columnsJson != null) 'columns_json': columnsJson,
      if (position != null) 'position': position,
      if (revision != null) 'revision': revision,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SavedViewsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? sheetRef,
    Value<String>? filtersJson,
    Value<String?>? sortJson,
    Value<String?>? columnsJson,
    Value<int>? position,
    Value<int>? revision,
    Value<int>? rowid,
  }) {
    return SavedViewsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      sheetRef: sheetRef ?? this.sheetRef,
      filtersJson: filtersJson ?? this.filtersJson,
      sortJson: sortJson ?? this.sortJson,
      columnsJson: columnsJson ?? this.columnsJson,
      position: position ?? this.position,
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
    if (sheetRef.present) {
      map['sheet_ref'] = Variable<String>(sheetRef.value);
    }
    if (filtersJson.present) {
      map['filters_json'] = Variable<String>(filtersJson.value);
    }
    if (sortJson.present) {
      map['sort_json'] = Variable<String>(sortJson.value);
    }
    if (columnsJson.present) {
      map['columns_json'] = Variable<String>(columnsJson.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
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
    return (StringBuffer('SavedViewsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('sheetRef: $sheetRef, ')
          ..write('filtersJson: $filtersJson, ')
          ..write('sortJson: $sortJson, ')
          ..write('columnsJson: $columnsJson, ')
          ..write('position: $position, ')
          ..write('revision: $revision, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DeskTilesTable extends DeskTiles
    with TableInfo<$DeskTilesTable, DeskTileRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DeskTilesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deskIdMeta = const VerificationMeta('deskId');
  @override
  late final GeneratedColumn<String> deskId = GeneratedColumn<String>(
    'desk_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES desks (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sheetRefMeta = const VerificationMeta(
    'sheetRef',
  );
  @override
  late final GeneratedColumn<String> sheetRef = GeneratedColumn<String>(
    'sheet_ref',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _viewIdMeta = const VerificationMeta('viewId');
  @override
  late final GeneratedColumn<String> viewId = GeneratedColumn<String>(
    'view_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES saved_views (id) ON DELETE CASCADE',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    deskId,
    position,
    sheetRef,
    viewId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'desk_tiles';
  @override
  VerificationContext validateIntegrity(
    Insertable<DeskTileRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('desk_id')) {
      context.handle(
        _deskIdMeta,
        deskId.isAcceptableOrUnknown(data['desk_id']!, _deskIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deskIdMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    if (data.containsKey('sheet_ref')) {
      context.handle(
        _sheetRefMeta,
        sheetRef.isAcceptableOrUnknown(data['sheet_ref']!, _sheetRefMeta),
      );
    } else if (isInserting) {
      context.missing(_sheetRefMeta);
    }
    if (data.containsKey('view_id')) {
      context.handle(
        _viewIdMeta,
        viewId.isAcceptableOrUnknown(data['view_id']!, _viewIdMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DeskTileRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DeskTileRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      deskId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}desk_id'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
      sheetRef: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sheet_ref'],
      )!,
      viewId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}view_id'],
      ),
    );
  }

  @override
  $DeskTilesTable createAlias(String alias) {
    return $DeskTilesTable(attachedDatabase, alias);
  }
}

class DeskTileRow extends DataClass implements Insertable<DeskTileRow> {
  final String id;
  final String deskId;
  final int position;

  /// A stable sheet key such as `work.shifts.week`.
  final String sheetRef;
  final String? viewId;
  const DeskTileRow({
    required this.id,
    required this.deskId,
    required this.position,
    required this.sheetRef,
    this.viewId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['desk_id'] = Variable<String>(deskId);
    map['position'] = Variable<int>(position);
    map['sheet_ref'] = Variable<String>(sheetRef);
    if (!nullToAbsent || viewId != null) {
      map['view_id'] = Variable<String>(viewId);
    }
    return map;
  }

  DeskTilesCompanion toCompanion(bool nullToAbsent) {
    return DeskTilesCompanion(
      id: Value(id),
      deskId: Value(deskId),
      position: Value(position),
      sheetRef: Value(sheetRef),
      viewId: viewId == null && nullToAbsent
          ? const Value.absent()
          : Value(viewId),
    );
  }

  factory DeskTileRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DeskTileRow(
      id: serializer.fromJson<String>(json['id']),
      deskId: serializer.fromJson<String>(json['deskId']),
      position: serializer.fromJson<int>(json['position']),
      sheetRef: serializer.fromJson<String>(json['sheetRef']),
      viewId: serializer.fromJson<String?>(json['viewId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'deskId': serializer.toJson<String>(deskId),
      'position': serializer.toJson<int>(position),
      'sheetRef': serializer.toJson<String>(sheetRef),
      'viewId': serializer.toJson<String?>(viewId),
    };
  }

  DeskTileRow copyWith({
    String? id,
    String? deskId,
    int? position,
    String? sheetRef,
    Value<String?> viewId = const Value.absent(),
  }) => DeskTileRow(
    id: id ?? this.id,
    deskId: deskId ?? this.deskId,
    position: position ?? this.position,
    sheetRef: sheetRef ?? this.sheetRef,
    viewId: viewId.present ? viewId.value : this.viewId,
  );
  DeskTileRow copyWithCompanion(DeskTilesCompanion data) {
    return DeskTileRow(
      id: data.id.present ? data.id.value : this.id,
      deskId: data.deskId.present ? data.deskId.value : this.deskId,
      position: data.position.present ? data.position.value : this.position,
      sheetRef: data.sheetRef.present ? data.sheetRef.value : this.sheetRef,
      viewId: data.viewId.present ? data.viewId.value : this.viewId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DeskTileRow(')
          ..write('id: $id, ')
          ..write('deskId: $deskId, ')
          ..write('position: $position, ')
          ..write('sheetRef: $sheetRef, ')
          ..write('viewId: $viewId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, deskId, position, sheetRef, viewId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DeskTileRow &&
          other.id == this.id &&
          other.deskId == this.deskId &&
          other.position == this.position &&
          other.sheetRef == this.sheetRef &&
          other.viewId == this.viewId);
}

class DeskTilesCompanion extends UpdateCompanion<DeskTileRow> {
  final Value<String> id;
  final Value<String> deskId;
  final Value<int> position;
  final Value<String> sheetRef;
  final Value<String?> viewId;
  final Value<int> rowid;
  const DeskTilesCompanion({
    this.id = const Value.absent(),
    this.deskId = const Value.absent(),
    this.position = const Value.absent(),
    this.sheetRef = const Value.absent(),
    this.viewId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DeskTilesCompanion.insert({
    required String id,
    required String deskId,
    required int position,
    required String sheetRef,
    this.viewId = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       deskId = Value(deskId),
       position = Value(position),
       sheetRef = Value(sheetRef);
  static Insertable<DeskTileRow> custom({
    Expression<String>? id,
    Expression<String>? deskId,
    Expression<int>? position,
    Expression<String>? sheetRef,
    Expression<String>? viewId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (deskId != null) 'desk_id': deskId,
      if (position != null) 'position': position,
      if (sheetRef != null) 'sheet_ref': sheetRef,
      if (viewId != null) 'view_id': viewId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DeskTilesCompanion copyWith({
    Value<String>? id,
    Value<String>? deskId,
    Value<int>? position,
    Value<String>? sheetRef,
    Value<String?>? viewId,
    Value<int>? rowid,
  }) {
    return DeskTilesCompanion(
      id: id ?? this.id,
      deskId: deskId ?? this.deskId,
      position: position ?? this.position,
      sheetRef: sheetRef ?? this.sheetRef,
      viewId: viewId ?? this.viewId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (deskId.present) {
      map['desk_id'] = Variable<String>(deskId.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (sheetRef.present) {
      map['sheet_ref'] = Variable<String>(sheetRef.value);
    }
    if (viewId.present) {
      map['view_id'] = Variable<String>(viewId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DeskTilesCompanion(')
          ..write('id: $id, ')
          ..write('deskId: $deskId, ')
          ..write('position: $position, ')
          ..write('sheetRef: $sheetRef, ')
          ..write('viewId: $viewId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PreferencesTable extends Preferences
    with TableInfo<$PreferencesTable, PreferenceRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PreferencesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    check: () => const CustomExpression<bool>("key IN ('appearance')"),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'preferences';
  @override
  VerificationContext validateIntegrity(
    Insertable<PreferenceRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  PreferenceRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PreferenceRow(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $PreferencesTable createAlias(String alias) {
    return $PreferencesTable(attachedDatabase, alias);
  }
}

class PreferenceRow extends DataClass implements Insertable<PreferenceRow> {
  final String key;
  final String value;
  const PreferenceRow({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  PreferencesCompanion toCompanion(bool nullToAbsent) {
    return PreferencesCompanion(key: Value(key), value: Value(value));
  }

  factory PreferenceRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PreferenceRow(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  PreferenceRow copyWith({String? key, String? value}) =>
      PreferenceRow(key: key ?? this.key, value: value ?? this.value);
  PreferenceRow copyWithCompanion(PreferencesCompanion data) {
    return PreferenceRow(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PreferenceRow(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PreferenceRow &&
          other.key == this.key &&
          other.value == this.value);
}

class PreferencesCompanion extends UpdateCompanion<PreferenceRow> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const PreferencesCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PreferencesCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<PreferenceRow> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PreferencesCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return PreferencesCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PreferencesCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
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
  late final $WorkSchedulesTable workSchedules = $WorkSchedulesTable(this);
  late final $WorkScheduleShiftTypesTable workScheduleShiftTypes =
      $WorkScheduleShiftTypesTable(this);
  late final $WorkScheduleBlocksTable workScheduleBlocks =
      $WorkScheduleBlocksTable(this);
  late final $WorkDayExceptionsTable workDayExceptions =
      $WorkDayExceptionsTable(this);
  late final $WorkLeaveRecordsTable workLeaveRecords = $WorkLeaveRecordsTable(
    this,
  );
  late final $RecordEventsTable recordEvents = $RecordEventsTable(this);
  late final $DesksTable desks = $DesksTable(this);
  late final $SavedViewsTable savedViews = $SavedViewsTable(this);
  late final $DeskTilesTable deskTiles = $DeskTilesTable(this);
  late final $PreferencesTable preferences = $PreferencesTable(this);
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
    workSchedules,
    workScheduleShiftTypes,
    workScheduleBlocks,
    workDayExceptions,
    workLeaveRecords,
    recordEvents,
    desks,
    savedViews,
    deskTiles,
    preferences,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'desks',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('desk_tiles', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'saved_views',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('desk_tiles', kind: UpdateKind.delete)],
    ),
  ]);
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

  static MultiTypedResultKey<$WorkSchedulesTable, List<WorkSchedule>>
  _workSchedulesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.workSchedules,
    aliasName: 'employments__id__work_schedules__employment_id',
  );

  $$WorkSchedulesTableProcessedTableManager get workSchedulesRefs {
    final manager = $$WorkSchedulesTableTableManager(
      $_db,
      $_db.workSchedules,
    ).filter((f) => f.employmentId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_workSchedulesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$WorkDayExceptionsTable, List<WorkDayException>>
  _workDayExceptionsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.workDayExceptions,
        aliasName: 'employments__id__work_day_exceptions__employment_id',
      );

  $$WorkDayExceptionsTableProcessedTableManager get workDayExceptionsRefs {
    final manager = $$WorkDayExceptionsTableTableManager(
      $_db,
      $_db.workDayExceptions,
    ).filter((f) => f.employmentId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _workDayExceptionsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$WorkLeaveRecordsTable, List<WorkLeaveRecord>>
  _workLeaveRecordsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.workLeaveRecords,
    aliasName: 'employments__id__work_leave_records__employment_id',
  );

  $$WorkLeaveRecordsTableProcessedTableManager get workLeaveRecordsRefs {
    final manager = $$WorkLeaveRecordsTableTableManager(
      $_db,
      $_db.workLeaveRecords,
    ).filter((f) => f.employmentId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _workLeaveRecordsRefsTable($_db),
    );
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

  Expression<bool> workSchedulesRefs(
    Expression<bool> Function($$WorkSchedulesTableFilterComposer f) f,
  ) {
    final $$WorkSchedulesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.workSchedules,
      getReferencedColumn: (t) => t.employmentId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkSchedulesTableFilterComposer(
            $db: $db,
            $table: $db.workSchedules,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> workDayExceptionsRefs(
    Expression<bool> Function($$WorkDayExceptionsTableFilterComposer f) f,
  ) {
    final $$WorkDayExceptionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.workDayExceptions,
      getReferencedColumn: (t) => t.employmentId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkDayExceptionsTableFilterComposer(
            $db: $db,
            $table: $db.workDayExceptions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> workLeaveRecordsRefs(
    Expression<bool> Function($$WorkLeaveRecordsTableFilterComposer f) f,
  ) {
    final $$WorkLeaveRecordsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.workLeaveRecords,
      getReferencedColumn: (t) => t.employmentId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkLeaveRecordsTableFilterComposer(
            $db: $db,
            $table: $db.workLeaveRecords,
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

  Expression<T> workSchedulesRefs<T extends Object>(
    Expression<T> Function($$WorkSchedulesTableAnnotationComposer a) f,
  ) {
    final $$WorkSchedulesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.workSchedules,
      getReferencedColumn: (t) => t.employmentId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkSchedulesTableAnnotationComposer(
            $db: $db,
            $table: $db.workSchedules,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> workDayExceptionsRefs<T extends Object>(
    Expression<T> Function($$WorkDayExceptionsTableAnnotationComposer a) f,
  ) {
    final $$WorkDayExceptionsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.workDayExceptions,
          getReferencedColumn: (t) => t.employmentId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$WorkDayExceptionsTableAnnotationComposer(
                $db: $db,
                $table: $db.workDayExceptions,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> workLeaveRecordsRefs<T extends Object>(
    Expression<T> Function($$WorkLeaveRecordsTableAnnotationComposer a) f,
  ) {
    final $$WorkLeaveRecordsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.workLeaveRecords,
      getReferencedColumn: (t) => t.employmentId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkLeaveRecordsTableAnnotationComposer(
            $db: $db,
            $table: $db.workLeaveRecords,
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
            bool workSchedulesRefs,
            bool workDayExceptionsRefs,
            bool workLeaveRecordsRefs,
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
                workSchedulesRefs = false,
                workDayExceptionsRefs = false,
                workLeaveRecordsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (payAgreementsRefs) db.payAgreements,
                    if (workShiftsRefs) db.workShifts,
                    if (payPeriodsRefs) db.payPeriods,
                    if (workSchedulesRefs) db.workSchedules,
                    if (workDayExceptionsRefs) db.workDayExceptions,
                    if (workLeaveRecordsRefs) db.workLeaveRecords,
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
                      if (workSchedulesRefs)
                        await $_getPrefetchedData<
                          Employment,
                          $EmploymentsTable,
                          WorkSchedule
                        >(
                          currentTable: table,
                          referencedTable: $$EmploymentsTableReferences
                              ._workSchedulesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$EmploymentsTableReferences(
                                db,
                                table,
                                p0,
                              ).workSchedulesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.employmentId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (workDayExceptionsRefs)
                        await $_getPrefetchedData<
                          Employment,
                          $EmploymentsTable,
                          WorkDayException
                        >(
                          currentTable: table,
                          referencedTable: $$EmploymentsTableReferences
                              ._workDayExceptionsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$EmploymentsTableReferences(
                                db,
                                table,
                                p0,
                              ).workDayExceptionsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.employmentId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (workLeaveRecordsRefs)
                        await $_getPrefetchedData<
                          Employment,
                          $EmploymentsTable,
                          WorkLeaveRecord
                        >(
                          currentTable: table,
                          referencedTable: $$EmploymentsTableReferences
                              ._workLeaveRecordsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$EmploymentsTableReferences(
                                db,
                                table,
                                p0,
                              ).workLeaveRecordsRefs,
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
        bool workSchedulesRefs,
        bool workDayExceptionsRefs,
        bool workLeaveRecordsRefs,
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
      required bool nightEnabled,
      required int nightStartMinute,
      required int nightEndMinute,
      required int nightMultiplierNumerator,
      required int nightMultiplierDenominator,
      required String holidayCalendar,
      required int holidayMultiplierNumerator,
      required int holidayMultiplierDenominator,
      required String premiumStacking,
      Value<String?> label,
      Value<String?> note,
      required int createdAtUtcMicros,
      required int revision,
      Value<int> vacationPayNumerator,
      Value<int> vacationPayDenominator,
      Value<int> sickPayNumerator,
      Value<int> sickPayDenominator,
      Value<int> sickEmployerDays,
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
      Value<bool> nightEnabled,
      Value<int> nightStartMinute,
      Value<int> nightEndMinute,
      Value<int> nightMultiplierNumerator,
      Value<int> nightMultiplierDenominator,
      Value<String> holidayCalendar,
      Value<int> holidayMultiplierNumerator,
      Value<int> holidayMultiplierDenominator,
      Value<String> premiumStacking,
      Value<String?> label,
      Value<String?> note,
      Value<int> createdAtUtcMicros,
      Value<int> revision,
      Value<int> vacationPayNumerator,
      Value<int> vacationPayDenominator,
      Value<int> sickPayNumerator,
      Value<int> sickPayDenominator,
      Value<int> sickEmployerDays,
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

  static MultiTypedResultKey<$WorkLeaveRecordsTable, List<WorkLeaveRecord>>
  _workLeaveRecordsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.workLeaveRecords,
    aliasName: 'pay_agreements__id__work_leave_records__agreement_id',
  );

  $$WorkLeaveRecordsTableProcessedTableManager get workLeaveRecordsRefs {
    final manager = $$WorkLeaveRecordsTableTableManager(
      $_db,
      $_db.workLeaveRecords,
    ).filter((f) => f.agreementId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _workLeaveRecordsRefsTable($_db),
    );
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

  ColumnFilters<bool> get nightEnabled => $composableBuilder(
    column: $table.nightEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get nightStartMinute => $composableBuilder(
    column: $table.nightStartMinute,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get nightEndMinute => $composableBuilder(
    column: $table.nightEndMinute,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get nightMultiplierNumerator => $composableBuilder(
    column: $table.nightMultiplierNumerator,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get nightMultiplierDenominator => $composableBuilder(
    column: $table.nightMultiplierDenominator,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get holidayCalendar => $composableBuilder(
    column: $table.holidayCalendar,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get holidayMultiplierNumerator => $composableBuilder(
    column: $table.holidayMultiplierNumerator,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get holidayMultiplierDenominator => $composableBuilder(
    column: $table.holidayMultiplierDenominator,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get premiumStacking => $composableBuilder(
    column: $table.premiumStacking,
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

  ColumnFilters<int> get vacationPayNumerator => $composableBuilder(
    column: $table.vacationPayNumerator,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get vacationPayDenominator => $composableBuilder(
    column: $table.vacationPayDenominator,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sickPayNumerator => $composableBuilder(
    column: $table.sickPayNumerator,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sickPayDenominator => $composableBuilder(
    column: $table.sickPayDenominator,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sickEmployerDays => $composableBuilder(
    column: $table.sickEmployerDays,
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

  Expression<bool> workLeaveRecordsRefs(
    Expression<bool> Function($$WorkLeaveRecordsTableFilterComposer f) f,
  ) {
    final $$WorkLeaveRecordsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.workLeaveRecords,
      getReferencedColumn: (t) => t.agreementId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkLeaveRecordsTableFilterComposer(
            $db: $db,
            $table: $db.workLeaveRecords,
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

  ColumnOrderings<bool> get nightEnabled => $composableBuilder(
    column: $table.nightEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get nightStartMinute => $composableBuilder(
    column: $table.nightStartMinute,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get nightEndMinute => $composableBuilder(
    column: $table.nightEndMinute,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get nightMultiplierNumerator => $composableBuilder(
    column: $table.nightMultiplierNumerator,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get nightMultiplierDenominator => $composableBuilder(
    column: $table.nightMultiplierDenominator,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get holidayCalendar => $composableBuilder(
    column: $table.holidayCalendar,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get holidayMultiplierNumerator => $composableBuilder(
    column: $table.holidayMultiplierNumerator,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get holidayMultiplierDenominator => $composableBuilder(
    column: $table.holidayMultiplierDenominator,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get premiumStacking => $composableBuilder(
    column: $table.premiumStacking,
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

  ColumnOrderings<int> get vacationPayNumerator => $composableBuilder(
    column: $table.vacationPayNumerator,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get vacationPayDenominator => $composableBuilder(
    column: $table.vacationPayDenominator,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sickPayNumerator => $composableBuilder(
    column: $table.sickPayNumerator,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sickPayDenominator => $composableBuilder(
    column: $table.sickPayDenominator,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sickEmployerDays => $composableBuilder(
    column: $table.sickEmployerDays,
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

  GeneratedColumn<bool> get nightEnabled => $composableBuilder(
    column: $table.nightEnabled,
    builder: (column) => column,
  );

  GeneratedColumn<int> get nightStartMinute => $composableBuilder(
    column: $table.nightStartMinute,
    builder: (column) => column,
  );

  GeneratedColumn<int> get nightEndMinute => $composableBuilder(
    column: $table.nightEndMinute,
    builder: (column) => column,
  );

  GeneratedColumn<int> get nightMultiplierNumerator => $composableBuilder(
    column: $table.nightMultiplierNumerator,
    builder: (column) => column,
  );

  GeneratedColumn<int> get nightMultiplierDenominator => $composableBuilder(
    column: $table.nightMultiplierDenominator,
    builder: (column) => column,
  );

  GeneratedColumn<String> get holidayCalendar => $composableBuilder(
    column: $table.holidayCalendar,
    builder: (column) => column,
  );

  GeneratedColumn<int> get holidayMultiplierNumerator => $composableBuilder(
    column: $table.holidayMultiplierNumerator,
    builder: (column) => column,
  );

  GeneratedColumn<int> get holidayMultiplierDenominator => $composableBuilder(
    column: $table.holidayMultiplierDenominator,
    builder: (column) => column,
  );

  GeneratedColumn<String> get premiumStacking => $composableBuilder(
    column: $table.premiumStacking,
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

  GeneratedColumn<int> get vacationPayNumerator => $composableBuilder(
    column: $table.vacationPayNumerator,
    builder: (column) => column,
  );

  GeneratedColumn<int> get vacationPayDenominator => $composableBuilder(
    column: $table.vacationPayDenominator,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sickPayNumerator => $composableBuilder(
    column: $table.sickPayNumerator,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sickPayDenominator => $composableBuilder(
    column: $table.sickPayDenominator,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sickEmployerDays => $composableBuilder(
    column: $table.sickEmployerDays,
    builder: (column) => column,
  );

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

  Expression<T> workLeaveRecordsRefs<T extends Object>(
    Expression<T> Function($$WorkLeaveRecordsTableAnnotationComposer a) f,
  ) {
    final $$WorkLeaveRecordsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.workLeaveRecords,
      getReferencedColumn: (t) => t.agreementId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkLeaveRecordsTableAnnotationComposer(
            $db: $db,
            $table: $db.workLeaveRecords,
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
          PrefetchHooks Function({
            bool employmentId,
            bool workShiftsRefs,
            bool workLeaveRecordsRefs,
          })
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
                Value<bool> nightEnabled = const Value.absent(),
                Value<int> nightStartMinute = const Value.absent(),
                Value<int> nightEndMinute = const Value.absent(),
                Value<int> nightMultiplierNumerator = const Value.absent(),
                Value<int> nightMultiplierDenominator = const Value.absent(),
                Value<String> holidayCalendar = const Value.absent(),
                Value<int> holidayMultiplierNumerator = const Value.absent(),
                Value<int> holidayMultiplierDenominator = const Value.absent(),
                Value<String> premiumStacking = const Value.absent(),
                Value<String?> label = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<int> createdAtUtcMicros = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<int> vacationPayNumerator = const Value.absent(),
                Value<int> vacationPayDenominator = const Value.absent(),
                Value<int> sickPayNumerator = const Value.absent(),
                Value<int> sickPayDenominator = const Value.absent(),
                Value<int> sickEmployerDays = const Value.absent(),
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
                nightEnabled: nightEnabled,
                nightStartMinute: nightStartMinute,
                nightEndMinute: nightEndMinute,
                nightMultiplierNumerator: nightMultiplierNumerator,
                nightMultiplierDenominator: nightMultiplierDenominator,
                holidayCalendar: holidayCalendar,
                holidayMultiplierNumerator: holidayMultiplierNumerator,
                holidayMultiplierDenominator: holidayMultiplierDenominator,
                premiumStacking: premiumStacking,
                label: label,
                note: note,
                createdAtUtcMicros: createdAtUtcMicros,
                revision: revision,
                vacationPayNumerator: vacationPayNumerator,
                vacationPayDenominator: vacationPayDenominator,
                sickPayNumerator: sickPayNumerator,
                sickPayDenominator: sickPayDenominator,
                sickEmployerDays: sickEmployerDays,
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
                required bool nightEnabled,
                required int nightStartMinute,
                required int nightEndMinute,
                required int nightMultiplierNumerator,
                required int nightMultiplierDenominator,
                required String holidayCalendar,
                required int holidayMultiplierNumerator,
                required int holidayMultiplierDenominator,
                required String premiumStacking,
                Value<String?> label = const Value.absent(),
                Value<String?> note = const Value.absent(),
                required int createdAtUtcMicros,
                required int revision,
                Value<int> vacationPayNumerator = const Value.absent(),
                Value<int> vacationPayDenominator = const Value.absent(),
                Value<int> sickPayNumerator = const Value.absent(),
                Value<int> sickPayDenominator = const Value.absent(),
                Value<int> sickEmployerDays = const Value.absent(),
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
                nightEnabled: nightEnabled,
                nightStartMinute: nightStartMinute,
                nightEndMinute: nightEndMinute,
                nightMultiplierNumerator: nightMultiplierNumerator,
                nightMultiplierDenominator: nightMultiplierDenominator,
                holidayCalendar: holidayCalendar,
                holidayMultiplierNumerator: holidayMultiplierNumerator,
                holidayMultiplierDenominator: holidayMultiplierDenominator,
                premiumStacking: premiumStacking,
                label: label,
                note: note,
                createdAtUtcMicros: createdAtUtcMicros,
                revision: revision,
                vacationPayNumerator: vacationPayNumerator,
                vacationPayDenominator: vacationPayDenominator,
                sickPayNumerator: sickPayNumerator,
                sickPayDenominator: sickPayDenominator,
                sickEmployerDays: sickEmployerDays,
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
              ({
                employmentId = false,
                workShiftsRefs = false,
                workLeaveRecordsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (workShiftsRefs) db.workShifts,
                    if (workLeaveRecordsRefs) db.workLeaveRecords,
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
                      if (workLeaveRecordsRefs)
                        await $_getPrefetchedData<
                          PayAgreement,
                          $PayAgreementsTable,
                          WorkLeaveRecord
                        >(
                          currentTable: table,
                          referencedTable: $$PayAgreementsTableReferences
                              ._workLeaveRecordsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$PayAgreementsTableReferences(
                                db,
                                table,
                                p0,
                              ).workLeaveRecordsRefs,
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
      PrefetchHooks Function({
        bool employmentId,
        bool workShiftsRefs,
        bool workLeaveRecordsRefs,
      })
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
  Value<String?> note,
  Value<String?> voidReason,
  Value<String?> replacementShiftId,
  Value<String?> replacedShiftId,
  required int createdAtUtcMicros,
  required int updatedAtUtcMicros,
  required int revision,
  Value<String?> scheduleId,
  Value<int?> scheduleVersion,
  Value<String?> plannedDate,
  Value<int?> plannedStartUtcMicros,
  Value<int?> plannedEndUtcMicros,
  Value<bool> isExtra,
  Value<bool> extraCountsAsOvertime,
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
  Value<String?> note,
  Value<String?> voidReason,
  Value<String?> replacementShiftId,
  Value<String?> replacedShiftId,
  Value<int> createdAtUtcMicros,
  Value<int> updatedAtUtcMicros,
  Value<int> revision,
  Value<String?> scheduleId,
  Value<int?> scheduleVersion,
  Value<String?> plannedDate,
  Value<int?> plannedStartUtcMicros,
  Value<int?> plannedEndUtcMicros,
  Value<bool> isExtra,
  Value<bool> extraCountsAsOvertime,
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

  ColumnFilters<String> get scheduleId => $composableBuilder(
    column: $table.scheduleId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get scheduleVersion => $composableBuilder(
    column: $table.scheduleVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get plannedDate => $composableBuilder(
    column: $table.plannedDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get plannedStartUtcMicros => $composableBuilder(
    column: $table.plannedStartUtcMicros,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get plannedEndUtcMicros => $composableBuilder(
    column: $table.plannedEndUtcMicros,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isExtra => $composableBuilder(
    column: $table.isExtra,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get extraCountsAsOvertime => $composableBuilder(
    column: $table.extraCountsAsOvertime,
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

  ColumnOrderings<String> get scheduleId => $composableBuilder(
    column: $table.scheduleId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get scheduleVersion => $composableBuilder(
    column: $table.scheduleVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get plannedDate => $composableBuilder(
    column: $table.plannedDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get plannedStartUtcMicros => $composableBuilder(
    column: $table.plannedStartUtcMicros,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get plannedEndUtcMicros => $composableBuilder(
    column: $table.plannedEndUtcMicros,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isExtra => $composableBuilder(
    column: $table.isExtra,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get extraCountsAsOvertime => $composableBuilder(
    column: $table.extraCountsAsOvertime,
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

  GeneratedColumn<String> get scheduleId => $composableBuilder(
    column: $table.scheduleId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get scheduleVersion => $composableBuilder(
    column: $table.scheduleVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get plannedDate => $composableBuilder(
    column: $table.plannedDate,
    builder: (column) => column,
  );

  GeneratedColumn<int> get plannedStartUtcMicros => $composableBuilder(
    column: $table.plannedStartUtcMicros,
    builder: (column) => column,
  );

  GeneratedColumn<int> get plannedEndUtcMicros => $composableBuilder(
    column: $table.plannedEndUtcMicros,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isExtra =>
      $composableBuilder(column: $table.isExtra, builder: (column) => column);

  GeneratedColumn<bool> get extraCountsAsOvertime => $composableBuilder(
    column: $table.extraCountsAsOvertime,
    builder: (column) => column,
  );

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
                Value<String?> note = const Value.absent(),
                Value<String?> voidReason = const Value.absent(),
                Value<String?> replacementShiftId = const Value.absent(),
                Value<String?> replacedShiftId = const Value.absent(),
                Value<int> createdAtUtcMicros = const Value.absent(),
                Value<int> updatedAtUtcMicros = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<String?> scheduleId = const Value.absent(),
                Value<int?> scheduleVersion = const Value.absent(),
                Value<String?> plannedDate = const Value.absent(),
                Value<int?> plannedStartUtcMicros = const Value.absent(),
                Value<int?> plannedEndUtcMicros = const Value.absent(),
                Value<bool> isExtra = const Value.absent(),
                Value<bool> extraCountsAsOvertime = const Value.absent(),
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
                note: note,
                voidReason: voidReason,
                replacementShiftId: replacementShiftId,
                replacedShiftId: replacedShiftId,
                createdAtUtcMicros: createdAtUtcMicros,
                updatedAtUtcMicros: updatedAtUtcMicros,
                revision: revision,
                scheduleId: scheduleId,
                scheduleVersion: scheduleVersion,
                plannedDate: plannedDate,
                plannedStartUtcMicros: plannedStartUtcMicros,
                plannedEndUtcMicros: plannedEndUtcMicros,
                isExtra: isExtra,
                extraCountsAsOvertime: extraCountsAsOvertime,
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
                Value<String?> note = const Value.absent(),
                Value<String?> voidReason = const Value.absent(),
                Value<String?> replacementShiftId = const Value.absent(),
                Value<String?> replacedShiftId = const Value.absent(),
                required int createdAtUtcMicros,
                required int updatedAtUtcMicros,
                required int revision,
                Value<String?> scheduleId = const Value.absent(),
                Value<int?> scheduleVersion = const Value.absent(),
                Value<String?> plannedDate = const Value.absent(),
                Value<int?> plannedStartUtcMicros = const Value.absent(),
                Value<int?> plannedEndUtcMicros = const Value.absent(),
                Value<bool> isExtra = const Value.absent(),
                Value<bool> extraCountsAsOvertime = const Value.absent(),
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
                note: note,
                voidReason: voidReason,
                replacementShiftId: replacementShiftId,
                replacedShiftId: replacedShiftId,
                createdAtUtcMicros: createdAtUtcMicros,
                updatedAtUtcMicros: updatedAtUtcMicros,
                revision: revision,
                scheduleId: scheduleId,
                scheduleVersion: scheduleVersion,
                plannedDate: plannedDate,
                plannedStartUtcMicros: plannedStartUtcMicros,
                plannedEndUtcMicros: plannedEndUtcMicros,
                isExtra: isExtra,
                extraCountsAsOvertime: extraCountsAsOvertime,
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
typedef $$WorkSchedulesTableCreateCompanionBuilder =
    WorkSchedulesCompanion Function({
      required String id,
      required int version,
      required String employmentId,
      required String name,
      required String timezoneId,
      required String cycleStart,
      required String inUseFrom,
      Value<String?> inUseUntil,
      required int createdAtUtcMicros,
      required int revision,
      Value<int> rowid,
    });
typedef $$WorkSchedulesTableUpdateCompanionBuilder =
    WorkSchedulesCompanion Function({
      Value<String> id,
      Value<int> version,
      Value<String> employmentId,
      Value<String> name,
      Value<String> timezoneId,
      Value<String> cycleStart,
      Value<String> inUseFrom,
      Value<String?> inUseUntil,
      Value<int> createdAtUtcMicros,
      Value<int> revision,
      Value<int> rowid,
    });

final class $$WorkSchedulesTableReferences
    extends BaseReferences<_$AppDatabase, $WorkSchedulesTable, WorkSchedule> {
  $$WorkSchedulesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $EmploymentsTable _employmentIdTable(_$AppDatabase db) => db
      .employments
      .createAlias('work_schedules__employment_id__employments__id');

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
}

class $$WorkSchedulesTableFilterComposer
    extends Composer<_$AppDatabase, $WorkSchedulesTable> {
  $$WorkSchedulesTableFilterComposer({
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

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get timezoneId => $composableBuilder(
    column: $table.timezoneId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cycleStart => $composableBuilder(
    column: $table.cycleStart,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get inUseFrom => $composableBuilder(
    column: $table.inUseFrom,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get inUseUntil => $composableBuilder(
    column: $table.inUseUntil,
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
}

class $$WorkSchedulesTableOrderingComposer
    extends Composer<_$AppDatabase, $WorkSchedulesTable> {
  $$WorkSchedulesTableOrderingComposer({
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

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get timezoneId => $composableBuilder(
    column: $table.timezoneId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cycleStart => $composableBuilder(
    column: $table.cycleStart,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get inUseFrom => $composableBuilder(
    column: $table.inUseFrom,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get inUseUntil => $composableBuilder(
    column: $table.inUseUntil,
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

class $$WorkSchedulesTableAnnotationComposer
    extends Composer<_$AppDatabase, $WorkSchedulesTable> {
  $$WorkSchedulesTableAnnotationComposer({
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

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get timezoneId => $composableBuilder(
    column: $table.timezoneId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get cycleStart => $composableBuilder(
    column: $table.cycleStart,
    builder: (column) => column,
  );

  GeneratedColumn<String> get inUseFrom =>
      $composableBuilder(column: $table.inUseFrom, builder: (column) => column);

  GeneratedColumn<String> get inUseUntil => $composableBuilder(
    column: $table.inUseUntil,
    builder: (column) => column,
  );

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
}

class $$WorkSchedulesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WorkSchedulesTable,
          WorkSchedule,
          $$WorkSchedulesTableFilterComposer,
          $$WorkSchedulesTableOrderingComposer,
          $$WorkSchedulesTableAnnotationComposer,
          $$WorkSchedulesTableCreateCompanionBuilder,
          $$WorkSchedulesTableUpdateCompanionBuilder,
          (WorkSchedule, $$WorkSchedulesTableReferences),
          WorkSchedule,
          PrefetchHooks Function({bool employmentId})
        > {
  $$WorkSchedulesTableTableManager(_$AppDatabase db, $WorkSchedulesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WorkSchedulesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WorkSchedulesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WorkSchedulesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<String> employmentId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> timezoneId = const Value.absent(),
                Value<String> cycleStart = const Value.absent(),
                Value<String> inUseFrom = const Value.absent(),
                Value<String?> inUseUntil = const Value.absent(),
                Value<int> createdAtUtcMicros = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WorkSchedulesCompanion(
                id: id,
                version: version,
                employmentId: employmentId,
                name: name,
                timezoneId: timezoneId,
                cycleStart: cycleStart,
                inUseFrom: inUseFrom,
                inUseUntil: inUseUntil,
                createdAtUtcMicros: createdAtUtcMicros,
                revision: revision,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required int version,
                required String employmentId,
                required String name,
                required String timezoneId,
                required String cycleStart,
                required String inUseFrom,
                Value<String?> inUseUntil = const Value.absent(),
                required int createdAtUtcMicros,
                required int revision,
                Value<int> rowid = const Value.absent(),
              }) => WorkSchedulesCompanion.insert(
                id: id,
                version: version,
                employmentId: employmentId,
                name: name,
                timezoneId: timezoneId,
                cycleStart: cycleStart,
                inUseFrom: inUseFrom,
                inUseUntil: inUseUntil,
                createdAtUtcMicros: createdAtUtcMicros,
                revision: revision,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$WorkSchedulesTable, WorkSchedule>(table),
                  $$WorkSchedulesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({employmentId = false}) {
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
                    if (employmentId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.employmentId,
                        referencedTable: $$WorkSchedulesTableReferences
                            ._employmentIdTable(db),
                        referencedColumn: $$WorkSchedulesTableReferences
                            ._employmentIdTable(db)
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

typedef $$WorkSchedulesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WorkSchedulesTable,
      WorkSchedule,
      $$WorkSchedulesTableFilterComposer,
      $$WorkSchedulesTableOrderingComposer,
      $$WorkSchedulesTableAnnotationComposer,
      $$WorkSchedulesTableCreateCompanionBuilder,
      $$WorkSchedulesTableUpdateCompanionBuilder,
      (WorkSchedule, $$WorkSchedulesTableReferences),
      WorkSchedule,
      PrefetchHooks Function({bool employmentId})
    >;
typedef $$WorkScheduleShiftTypesTableCreateCompanionBuilder =
    WorkScheduleShiftTypesCompanion Function({
      required String scheduleId,
      required int scheduleVersion,
      required String id,
      required int position,
      required String name,
      required int startMinute,
      required int endMinute,
      required int endDayOffset,
      required String breaks,
      Value<int> rowid,
    });
typedef $$WorkScheduleShiftTypesTableUpdateCompanionBuilder =
    WorkScheduleShiftTypesCompanion Function({
      Value<String> scheduleId,
      Value<int> scheduleVersion,
      Value<String> id,
      Value<int> position,
      Value<String> name,
      Value<int> startMinute,
      Value<int> endMinute,
      Value<int> endDayOffset,
      Value<String> breaks,
      Value<int> rowid,
    });

class $$WorkScheduleShiftTypesTableFilterComposer
    extends Composer<_$AppDatabase, $WorkScheduleShiftTypesTable> {
  $$WorkScheduleShiftTypesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get scheduleId => $composableBuilder(
    column: $table.scheduleId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get scheduleVersion => $composableBuilder(
    column: $table.scheduleVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startMinute => $composableBuilder(
    column: $table.startMinute,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get endMinute => $composableBuilder(
    column: $table.endMinute,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get endDayOffset => $composableBuilder(
    column: $table.endDayOffset,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get breaks => $composableBuilder(
    column: $table.breaks,
    builder: (column) => ColumnFilters(column),
  );
}

class $$WorkScheduleShiftTypesTableOrderingComposer
    extends Composer<_$AppDatabase, $WorkScheduleShiftTypesTable> {
  $$WorkScheduleShiftTypesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get scheduleId => $composableBuilder(
    column: $table.scheduleId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get scheduleVersion => $composableBuilder(
    column: $table.scheduleVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startMinute => $composableBuilder(
    column: $table.startMinute,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get endMinute => $composableBuilder(
    column: $table.endMinute,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get endDayOffset => $composableBuilder(
    column: $table.endDayOffset,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get breaks => $composableBuilder(
    column: $table.breaks,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$WorkScheduleShiftTypesTableAnnotationComposer
    extends Composer<_$AppDatabase, $WorkScheduleShiftTypesTable> {
  $$WorkScheduleShiftTypesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get scheduleId => $composableBuilder(
    column: $table.scheduleId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get scheduleVersion => $composableBuilder(
    column: $table.scheduleVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get startMinute => $composableBuilder(
    column: $table.startMinute,
    builder: (column) => column,
  );

  GeneratedColumn<int> get endMinute =>
      $composableBuilder(column: $table.endMinute, builder: (column) => column);

  GeneratedColumn<int> get endDayOffset => $composableBuilder(
    column: $table.endDayOffset,
    builder: (column) => column,
  );

  GeneratedColumn<String> get breaks =>
      $composableBuilder(column: $table.breaks, builder: (column) => column);
}

class $$WorkScheduleShiftTypesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WorkScheduleShiftTypesTable,
          WorkScheduleShiftType,
          $$WorkScheduleShiftTypesTableFilterComposer,
          $$WorkScheduleShiftTypesTableOrderingComposer,
          $$WorkScheduleShiftTypesTableAnnotationComposer,
          $$WorkScheduleShiftTypesTableCreateCompanionBuilder,
          $$WorkScheduleShiftTypesTableUpdateCompanionBuilder,
          (
            WorkScheduleShiftType,
            BaseReferences<
              _$AppDatabase,
              $WorkScheduleShiftTypesTable,
              WorkScheduleShiftType
            >,
          ),
          WorkScheduleShiftType,
          PrefetchHooks Function()
        > {
  $$WorkScheduleShiftTypesTableTableManager(
    _$AppDatabase db,
    $WorkScheduleShiftTypesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WorkScheduleShiftTypesTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$WorkScheduleShiftTypesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$WorkScheduleShiftTypesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> scheduleId = const Value.absent(),
                Value<int> scheduleVersion = const Value.absent(),
                Value<String> id = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> startMinute = const Value.absent(),
                Value<int> endMinute = const Value.absent(),
                Value<int> endDayOffset = const Value.absent(),
                Value<String> breaks = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WorkScheduleShiftTypesCompanion(
                scheduleId: scheduleId,
                scheduleVersion: scheduleVersion,
                id: id,
                position: position,
                name: name,
                startMinute: startMinute,
                endMinute: endMinute,
                endDayOffset: endDayOffset,
                breaks: breaks,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String scheduleId,
                required int scheduleVersion,
                required String id,
                required int position,
                required String name,
                required int startMinute,
                required int endMinute,
                required int endDayOffset,
                required String breaks,
                Value<int> rowid = const Value.absent(),
              }) => WorkScheduleShiftTypesCompanion.insert(
                scheduleId: scheduleId,
                scheduleVersion: scheduleVersion,
                id: id,
                position: position,
                name: name,
                startMinute: startMinute,
                endMinute: endMinute,
                endDayOffset: endDayOffset,
                breaks: breaks,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<
                    $WorkScheduleShiftTypesTable,
                    WorkScheduleShiftType
                  >(table),
                  BaseReferences<
                    _$AppDatabase,
                    $WorkScheduleShiftTypesTable,
                    WorkScheduleShiftType
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$WorkScheduleShiftTypesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WorkScheduleShiftTypesTable,
      WorkScheduleShiftType,
      $$WorkScheduleShiftTypesTableFilterComposer,
      $$WorkScheduleShiftTypesTableOrderingComposer,
      $$WorkScheduleShiftTypesTableAnnotationComposer,
      $$WorkScheduleShiftTypesTableCreateCompanionBuilder,
      $$WorkScheduleShiftTypesTableUpdateCompanionBuilder,
      (
        WorkScheduleShiftType,
        BaseReferences<
          _$AppDatabase,
          $WorkScheduleShiftTypesTable,
          WorkScheduleShiftType
        >,
      ),
      WorkScheduleShiftType,
      PrefetchHooks Function()
    >;
typedef $$WorkScheduleBlocksTableCreateCompanionBuilder =
    WorkScheduleBlocksCompanion Function({
      required String scheduleId,
      required int scheduleVersion,
      required int position,
      required int count,
      Value<String?> shiftTypeId,
      Value<int> rowid,
    });
typedef $$WorkScheduleBlocksTableUpdateCompanionBuilder =
    WorkScheduleBlocksCompanion Function({
      Value<String> scheduleId,
      Value<int> scheduleVersion,
      Value<int> position,
      Value<int> count,
      Value<String?> shiftTypeId,
      Value<int> rowid,
    });

class $$WorkScheduleBlocksTableFilterComposer
    extends Composer<_$AppDatabase, $WorkScheduleBlocksTable> {
  $$WorkScheduleBlocksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get scheduleId => $composableBuilder(
    column: $table.scheduleId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get scheduleVersion => $composableBuilder(
    column: $table.scheduleVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get count => $composableBuilder(
    column: $table.count,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get shiftTypeId => $composableBuilder(
    column: $table.shiftTypeId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$WorkScheduleBlocksTableOrderingComposer
    extends Composer<_$AppDatabase, $WorkScheduleBlocksTable> {
  $$WorkScheduleBlocksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get scheduleId => $composableBuilder(
    column: $table.scheduleId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get scheduleVersion => $composableBuilder(
    column: $table.scheduleVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get count => $composableBuilder(
    column: $table.count,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get shiftTypeId => $composableBuilder(
    column: $table.shiftTypeId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$WorkScheduleBlocksTableAnnotationComposer
    extends Composer<_$AppDatabase, $WorkScheduleBlocksTable> {
  $$WorkScheduleBlocksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get scheduleId => $composableBuilder(
    column: $table.scheduleId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get scheduleVersion => $composableBuilder(
    column: $table.scheduleVersion,
    builder: (column) => column,
  );

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<int> get count =>
      $composableBuilder(column: $table.count, builder: (column) => column);

  GeneratedColumn<String> get shiftTypeId => $composableBuilder(
    column: $table.shiftTypeId,
    builder: (column) => column,
  );
}

class $$WorkScheduleBlocksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WorkScheduleBlocksTable,
          WorkScheduleBlock,
          $$WorkScheduleBlocksTableFilterComposer,
          $$WorkScheduleBlocksTableOrderingComposer,
          $$WorkScheduleBlocksTableAnnotationComposer,
          $$WorkScheduleBlocksTableCreateCompanionBuilder,
          $$WorkScheduleBlocksTableUpdateCompanionBuilder,
          (
            WorkScheduleBlock,
            BaseReferences<
              _$AppDatabase,
              $WorkScheduleBlocksTable,
              WorkScheduleBlock
            >,
          ),
          WorkScheduleBlock,
          PrefetchHooks Function()
        > {
  $$WorkScheduleBlocksTableTableManager(
    _$AppDatabase db,
    $WorkScheduleBlocksTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WorkScheduleBlocksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WorkScheduleBlocksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WorkScheduleBlocksTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> scheduleId = const Value.absent(),
                Value<int> scheduleVersion = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<int> count = const Value.absent(),
                Value<String?> shiftTypeId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WorkScheduleBlocksCompanion(
                scheduleId: scheduleId,
                scheduleVersion: scheduleVersion,
                position: position,
                count: count,
                shiftTypeId: shiftTypeId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String scheduleId,
                required int scheduleVersion,
                required int position,
                required int count,
                Value<String?> shiftTypeId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WorkScheduleBlocksCompanion.insert(
                scheduleId: scheduleId,
                scheduleVersion: scheduleVersion,
                position: position,
                count: count,
                shiftTypeId: shiftTypeId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$WorkScheduleBlocksTable, WorkScheduleBlock>(
                    table,
                  ),
                  BaseReferences<
                    _$AppDatabase,
                    $WorkScheduleBlocksTable,
                    WorkScheduleBlock
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$WorkScheduleBlocksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WorkScheduleBlocksTable,
      WorkScheduleBlock,
      $$WorkScheduleBlocksTableFilterComposer,
      $$WorkScheduleBlocksTableOrderingComposer,
      $$WorkScheduleBlocksTableAnnotationComposer,
      $$WorkScheduleBlocksTableCreateCompanionBuilder,
      $$WorkScheduleBlocksTableUpdateCompanionBuilder,
      (
        WorkScheduleBlock,
        BaseReferences<
          _$AppDatabase,
          $WorkScheduleBlocksTable,
          WorkScheduleBlock
        >,
      ),
      WorkScheduleBlock,
      PrefetchHooks Function()
    >;
typedef $$WorkDayExceptionsTableCreateCompanionBuilder =
    WorkDayExceptionsCompanion Function({
      required String id,
      required String employmentId,
      required String date,
      required String kind,
      Value<int?> startMinute,
      Value<int?> endMinute,
      Value<int?> endDayOffset,
      Value<String?> breaks,
      Value<String?> shiftTypeId,
      Value<String?> reason,
      Value<String?> note,
      Value<String?> leaveType,
      Value<String?> illnessStartedOn,
      Value<bool> countsAsOvertime,
      required int createdAtUtcMicros,
      required int updatedAtUtcMicros,
      required int revision,
      Value<int> rowid,
    });
typedef $$WorkDayExceptionsTableUpdateCompanionBuilder =
    WorkDayExceptionsCompanion Function({
      Value<String> id,
      Value<String> employmentId,
      Value<String> date,
      Value<String> kind,
      Value<int?> startMinute,
      Value<int?> endMinute,
      Value<int?> endDayOffset,
      Value<String?> breaks,
      Value<String?> shiftTypeId,
      Value<String?> reason,
      Value<String?> note,
      Value<String?> leaveType,
      Value<String?> illnessStartedOn,
      Value<bool> countsAsOvertime,
      Value<int> createdAtUtcMicros,
      Value<int> updatedAtUtcMicros,
      Value<int> revision,
      Value<int> rowid,
    });

final class $$WorkDayExceptionsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $WorkDayExceptionsTable,
          WorkDayException
        > {
  $$WorkDayExceptionsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $EmploymentsTable _employmentIdTable(_$AppDatabase db) => db
      .employments
      .createAlias('work_day_exceptions__employment_id__employments__id');

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
}

class $$WorkDayExceptionsTableFilterComposer
    extends Composer<_$AppDatabase, $WorkDayExceptionsTable> {
  $$WorkDayExceptionsTableFilterComposer({
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

  ColumnFilters<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startMinute => $composableBuilder(
    column: $table.startMinute,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get endMinute => $composableBuilder(
    column: $table.endMinute,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get endDayOffset => $composableBuilder(
    column: $table.endDayOffset,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get breaks => $composableBuilder(
    column: $table.breaks,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get shiftTypeId => $composableBuilder(
    column: $table.shiftTypeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reason => $composableBuilder(
    column: $table.reason,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get leaveType => $composableBuilder(
    column: $table.leaveType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get illnessStartedOn => $composableBuilder(
    column: $table.illnessStartedOn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get countsAsOvertime => $composableBuilder(
    column: $table.countsAsOvertime,
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
}

class $$WorkDayExceptionsTableOrderingComposer
    extends Composer<_$AppDatabase, $WorkDayExceptionsTable> {
  $$WorkDayExceptionsTableOrderingComposer({
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

  ColumnOrderings<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startMinute => $composableBuilder(
    column: $table.startMinute,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get endMinute => $composableBuilder(
    column: $table.endMinute,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get endDayOffset => $composableBuilder(
    column: $table.endDayOffset,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get breaks => $composableBuilder(
    column: $table.breaks,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get shiftTypeId => $composableBuilder(
    column: $table.shiftTypeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reason => $composableBuilder(
    column: $table.reason,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get leaveType => $composableBuilder(
    column: $table.leaveType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get illnessStartedOn => $composableBuilder(
    column: $table.illnessStartedOn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get countsAsOvertime => $composableBuilder(
    column: $table.countsAsOvertime,
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

class $$WorkDayExceptionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $WorkDayExceptionsTable> {
  $$WorkDayExceptionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<int> get startMinute => $composableBuilder(
    column: $table.startMinute,
    builder: (column) => column,
  );

  GeneratedColumn<int> get endMinute =>
      $composableBuilder(column: $table.endMinute, builder: (column) => column);

  GeneratedColumn<int> get endDayOffset => $composableBuilder(
    column: $table.endDayOffset,
    builder: (column) => column,
  );

  GeneratedColumn<String> get breaks =>
      $composableBuilder(column: $table.breaks, builder: (column) => column);

  GeneratedColumn<String> get shiftTypeId => $composableBuilder(
    column: $table.shiftTypeId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get reason =>
      $composableBuilder(column: $table.reason, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<String> get leaveType =>
      $composableBuilder(column: $table.leaveType, builder: (column) => column);

  GeneratedColumn<String> get illnessStartedOn => $composableBuilder(
    column: $table.illnessStartedOn,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get countsAsOvertime => $composableBuilder(
    column: $table.countsAsOvertime,
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
}

class $$WorkDayExceptionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WorkDayExceptionsTable,
          WorkDayException,
          $$WorkDayExceptionsTableFilterComposer,
          $$WorkDayExceptionsTableOrderingComposer,
          $$WorkDayExceptionsTableAnnotationComposer,
          $$WorkDayExceptionsTableCreateCompanionBuilder,
          $$WorkDayExceptionsTableUpdateCompanionBuilder,
          (WorkDayException, $$WorkDayExceptionsTableReferences),
          WorkDayException,
          PrefetchHooks Function({bool employmentId})
        > {
  $$WorkDayExceptionsTableTableManager(
    _$AppDatabase db,
    $WorkDayExceptionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WorkDayExceptionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WorkDayExceptionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WorkDayExceptionsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> employmentId = const Value.absent(),
                Value<String> date = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<int?> startMinute = const Value.absent(),
                Value<int?> endMinute = const Value.absent(),
                Value<int?> endDayOffset = const Value.absent(),
                Value<String?> breaks = const Value.absent(),
                Value<String?> shiftTypeId = const Value.absent(),
                Value<String?> reason = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<String?> leaveType = const Value.absent(),
                Value<String?> illnessStartedOn = const Value.absent(),
                Value<bool> countsAsOvertime = const Value.absent(),
                Value<int> createdAtUtcMicros = const Value.absent(),
                Value<int> updatedAtUtcMicros = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WorkDayExceptionsCompanion(
                id: id,
                employmentId: employmentId,
                date: date,
                kind: kind,
                startMinute: startMinute,
                endMinute: endMinute,
                endDayOffset: endDayOffset,
                breaks: breaks,
                shiftTypeId: shiftTypeId,
                reason: reason,
                note: note,
                leaveType: leaveType,
                illnessStartedOn: illnessStartedOn,
                countsAsOvertime: countsAsOvertime,
                createdAtUtcMicros: createdAtUtcMicros,
                updatedAtUtcMicros: updatedAtUtcMicros,
                revision: revision,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String employmentId,
                required String date,
                required String kind,
                Value<int?> startMinute = const Value.absent(),
                Value<int?> endMinute = const Value.absent(),
                Value<int?> endDayOffset = const Value.absent(),
                Value<String?> breaks = const Value.absent(),
                Value<String?> shiftTypeId = const Value.absent(),
                Value<String?> reason = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<String?> leaveType = const Value.absent(),
                Value<String?> illnessStartedOn = const Value.absent(),
                Value<bool> countsAsOvertime = const Value.absent(),
                required int createdAtUtcMicros,
                required int updatedAtUtcMicros,
                required int revision,
                Value<int> rowid = const Value.absent(),
              }) => WorkDayExceptionsCompanion.insert(
                id: id,
                employmentId: employmentId,
                date: date,
                kind: kind,
                startMinute: startMinute,
                endMinute: endMinute,
                endDayOffset: endDayOffset,
                breaks: breaks,
                shiftTypeId: shiftTypeId,
                reason: reason,
                note: note,
                leaveType: leaveType,
                illnessStartedOn: illnessStartedOn,
                countsAsOvertime: countsAsOvertime,
                createdAtUtcMicros: createdAtUtcMicros,
                updatedAtUtcMicros: updatedAtUtcMicros,
                revision: revision,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$WorkDayExceptionsTable, WorkDayException>(table),
                  $$WorkDayExceptionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({employmentId = false}) {
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
                    if (employmentId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.employmentId,
                        referencedTable: $$WorkDayExceptionsTableReferences
                            ._employmentIdTable(db),
                        referencedColumn: $$WorkDayExceptionsTableReferences
                            ._employmentIdTable(db)
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

typedef $$WorkDayExceptionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WorkDayExceptionsTable,
      WorkDayException,
      $$WorkDayExceptionsTableFilterComposer,
      $$WorkDayExceptionsTableOrderingComposer,
      $$WorkDayExceptionsTableAnnotationComposer,
      $$WorkDayExceptionsTableCreateCompanionBuilder,
      $$WorkDayExceptionsTableUpdateCompanionBuilder,
      (WorkDayException, $$WorkDayExceptionsTableReferences),
      WorkDayException,
      PrefetchHooks Function({bool employmentId})
    >;
typedef $$WorkLeaveRecordsTableCreateCompanionBuilder =
    WorkLeaveRecordsCompanion Function({
      required String id,
      required String employmentId,
      required String date,
      required String leaveType,
      Value<String?> illnessStartedOn,
      required int paidMinutes,
      required String agreementId,
      required String scheduleId,
      required int scheduleVersion,
      required String state,
      Value<String?> voidReason,
      Value<String?> replacementLeaveId,
      Value<String?> replacedLeaveId,
      required int createdAtUtcMicros,
      required int updatedAtUtcMicros,
      required int revision,
      Value<int> rowid,
    });
typedef $$WorkLeaveRecordsTableUpdateCompanionBuilder =
    WorkLeaveRecordsCompanion Function({
      Value<String> id,
      Value<String> employmentId,
      Value<String> date,
      Value<String> leaveType,
      Value<String?> illnessStartedOn,
      Value<int> paidMinutes,
      Value<String> agreementId,
      Value<String> scheduleId,
      Value<int> scheduleVersion,
      Value<String> state,
      Value<String?> voidReason,
      Value<String?> replacementLeaveId,
      Value<String?> replacedLeaveId,
      Value<int> createdAtUtcMicros,
      Value<int> updatedAtUtcMicros,
      Value<int> revision,
      Value<int> rowid,
    });

final class $$WorkLeaveRecordsTableReferences
    extends
        BaseReferences<_$AppDatabase, $WorkLeaveRecordsTable, WorkLeaveRecord> {
  $$WorkLeaveRecordsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $EmploymentsTable _employmentIdTable(_$AppDatabase db) => db
      .employments
      .createAlias('work_leave_records__employment_id__employments__id');

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
      .createAlias('work_leave_records__agreement_id__pay_agreements__id');

  $$PayAgreementsTableProcessedTableManager get agreementId {
    final $_column = $_itemColumn<String>('agreement_id')!;

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

  static $WorkLeaveRecordsTable _replacementLeaveIdTable(_$AppDatabase db) =>
      db.workLeaveRecords.createAlias(
        'work_leave_records__replacement_leave_id__work_leave_records__id',
      );

  $$WorkLeaveRecordsTableProcessedTableManager? get replacementLeaveId {
    final $_column = $_itemColumn<String>('replacement_leave_id');
    if ($_column == null) return null;
    final manager = $$WorkLeaveRecordsTableTableManager(
      $_db,
      $_db.workLeaveRecords,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_replacementLeaveIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $WorkLeaveRecordsTable _replacedLeaveIdTable(_$AppDatabase db) =>
      db.workLeaveRecords.createAlias(
        'work_leave_records__replaced_leave_id__work_leave_records__id',
      );

  $$WorkLeaveRecordsTableProcessedTableManager? get replacedLeaveId {
    final $_column = $_itemColumn<String>('replaced_leave_id');
    if ($_column == null) return null;
    final manager = $$WorkLeaveRecordsTableTableManager(
      $_db,
      $_db.workLeaveRecords,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_replacedLeaveIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$WorkLeaveRecordsTableFilterComposer
    extends Composer<_$AppDatabase, $WorkLeaveRecordsTable> {
  $$WorkLeaveRecordsTableFilterComposer({
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

  ColumnFilters<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get leaveType => $composableBuilder(
    column: $table.leaveType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get illnessStartedOn => $composableBuilder(
    column: $table.illnessStartedOn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get paidMinutes => $composableBuilder(
    column: $table.paidMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get scheduleId => $composableBuilder(
    column: $table.scheduleId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get scheduleVersion => $composableBuilder(
    column: $table.scheduleVersion,
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

  $$WorkLeaveRecordsTableFilterComposer get replacementLeaveId {
    final $$WorkLeaveRecordsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.replacementLeaveId,
      referencedTable: $db.workLeaveRecords,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkLeaveRecordsTableFilterComposer(
            $db: $db,
            $table: $db.workLeaveRecords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$WorkLeaveRecordsTableFilterComposer get replacedLeaveId {
    final $$WorkLeaveRecordsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.replacedLeaveId,
      referencedTable: $db.workLeaveRecords,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkLeaveRecordsTableFilterComposer(
            $db: $db,
            $table: $db.workLeaveRecords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$WorkLeaveRecordsTableOrderingComposer
    extends Composer<_$AppDatabase, $WorkLeaveRecordsTable> {
  $$WorkLeaveRecordsTableOrderingComposer({
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

  ColumnOrderings<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get leaveType => $composableBuilder(
    column: $table.leaveType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get illnessStartedOn => $composableBuilder(
    column: $table.illnessStartedOn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get paidMinutes => $composableBuilder(
    column: $table.paidMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scheduleId => $composableBuilder(
    column: $table.scheduleId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get scheduleVersion => $composableBuilder(
    column: $table.scheduleVersion,
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

  $$WorkLeaveRecordsTableOrderingComposer get replacementLeaveId {
    final $$WorkLeaveRecordsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.replacementLeaveId,
      referencedTable: $db.workLeaveRecords,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkLeaveRecordsTableOrderingComposer(
            $db: $db,
            $table: $db.workLeaveRecords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$WorkLeaveRecordsTableOrderingComposer get replacedLeaveId {
    final $$WorkLeaveRecordsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.replacedLeaveId,
      referencedTable: $db.workLeaveRecords,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkLeaveRecordsTableOrderingComposer(
            $db: $db,
            $table: $db.workLeaveRecords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$WorkLeaveRecordsTableAnnotationComposer
    extends Composer<_$AppDatabase, $WorkLeaveRecordsTable> {
  $$WorkLeaveRecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<String> get leaveType =>
      $composableBuilder(column: $table.leaveType, builder: (column) => column);

  GeneratedColumn<String> get illnessStartedOn => $composableBuilder(
    column: $table.illnessStartedOn,
    builder: (column) => column,
  );

  GeneratedColumn<int> get paidMinutes => $composableBuilder(
    column: $table.paidMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<String> get scheduleId => $composableBuilder(
    column: $table.scheduleId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get scheduleVersion => $composableBuilder(
    column: $table.scheduleVersion,
    builder: (column) => column,
  );

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

  $$WorkLeaveRecordsTableAnnotationComposer get replacementLeaveId {
    final $$WorkLeaveRecordsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.replacementLeaveId,
      referencedTable: $db.workLeaveRecords,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkLeaveRecordsTableAnnotationComposer(
            $db: $db,
            $table: $db.workLeaveRecords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$WorkLeaveRecordsTableAnnotationComposer get replacedLeaveId {
    final $$WorkLeaveRecordsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.replacedLeaveId,
      referencedTable: $db.workLeaveRecords,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkLeaveRecordsTableAnnotationComposer(
            $db: $db,
            $table: $db.workLeaveRecords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$WorkLeaveRecordsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WorkLeaveRecordsTable,
          WorkLeaveRecord,
          $$WorkLeaveRecordsTableFilterComposer,
          $$WorkLeaveRecordsTableOrderingComposer,
          $$WorkLeaveRecordsTableAnnotationComposer,
          $$WorkLeaveRecordsTableCreateCompanionBuilder,
          $$WorkLeaveRecordsTableUpdateCompanionBuilder,
          (WorkLeaveRecord, $$WorkLeaveRecordsTableReferences),
          WorkLeaveRecord,
          PrefetchHooks Function({
            bool employmentId,
            bool agreementId,
            bool replacementLeaveId,
            bool replacedLeaveId,
          })
        > {
  $$WorkLeaveRecordsTableTableManager(
    _$AppDatabase db,
    $WorkLeaveRecordsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WorkLeaveRecordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WorkLeaveRecordsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WorkLeaveRecordsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> employmentId = const Value.absent(),
                Value<String> date = const Value.absent(),
                Value<String> leaveType = const Value.absent(),
                Value<String?> illnessStartedOn = const Value.absent(),
                Value<int> paidMinutes = const Value.absent(),
                Value<String> agreementId = const Value.absent(),
                Value<String> scheduleId = const Value.absent(),
                Value<int> scheduleVersion = const Value.absent(),
                Value<String> state = const Value.absent(),
                Value<String?> voidReason = const Value.absent(),
                Value<String?> replacementLeaveId = const Value.absent(),
                Value<String?> replacedLeaveId = const Value.absent(),
                Value<int> createdAtUtcMicros = const Value.absent(),
                Value<int> updatedAtUtcMicros = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WorkLeaveRecordsCompanion(
                id: id,
                employmentId: employmentId,
                date: date,
                leaveType: leaveType,
                illnessStartedOn: illnessStartedOn,
                paidMinutes: paidMinutes,
                agreementId: agreementId,
                scheduleId: scheduleId,
                scheduleVersion: scheduleVersion,
                state: state,
                voidReason: voidReason,
                replacementLeaveId: replacementLeaveId,
                replacedLeaveId: replacedLeaveId,
                createdAtUtcMicros: createdAtUtcMicros,
                updatedAtUtcMicros: updatedAtUtcMicros,
                revision: revision,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String employmentId,
                required String date,
                required String leaveType,
                Value<String?> illnessStartedOn = const Value.absent(),
                required int paidMinutes,
                required String agreementId,
                required String scheduleId,
                required int scheduleVersion,
                required String state,
                Value<String?> voidReason = const Value.absent(),
                Value<String?> replacementLeaveId = const Value.absent(),
                Value<String?> replacedLeaveId = const Value.absent(),
                required int createdAtUtcMicros,
                required int updatedAtUtcMicros,
                required int revision,
                Value<int> rowid = const Value.absent(),
              }) => WorkLeaveRecordsCompanion.insert(
                id: id,
                employmentId: employmentId,
                date: date,
                leaveType: leaveType,
                illnessStartedOn: illnessStartedOn,
                paidMinutes: paidMinutes,
                agreementId: agreementId,
                scheduleId: scheduleId,
                scheduleVersion: scheduleVersion,
                state: state,
                voidReason: voidReason,
                replacementLeaveId: replacementLeaveId,
                replacedLeaveId: replacedLeaveId,
                createdAtUtcMicros: createdAtUtcMicros,
                updatedAtUtcMicros: updatedAtUtcMicros,
                revision: revision,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$WorkLeaveRecordsTable, WorkLeaveRecord>(table),
                  $$WorkLeaveRecordsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                employmentId = false,
                agreementId = false,
                replacementLeaveId = false,
                replacedLeaveId = false,
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
                        if (employmentId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.employmentId,
                            referencedTable: $$WorkLeaveRecordsTableReferences
                                ._employmentIdTable(db),
                            referencedColumn: $$WorkLeaveRecordsTableReferences
                                ._employmentIdTable(db)
                                .id,
                          ) as T;
                        }
                        if (agreementId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.agreementId,
                            referencedTable: $$WorkLeaveRecordsTableReferences
                                ._agreementIdTable(db),
                            referencedColumn: $$WorkLeaveRecordsTableReferences
                                ._agreementIdTable(db)
                                .id,
                          ) as T;
                        }
                        if (replacementLeaveId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.replacementLeaveId,
                            referencedTable: $$WorkLeaveRecordsTableReferences
                                ._replacementLeaveIdTable(db),
                            referencedColumn: $$WorkLeaveRecordsTableReferences
                                ._replacementLeaveIdTable(db)
                                .id,
                          ) as T;
                        }
                        if (replacedLeaveId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.replacedLeaveId,
                            referencedTable: $$WorkLeaveRecordsTableReferences
                                ._replacedLeaveIdTable(db),
                            referencedColumn: $$WorkLeaveRecordsTableReferences
                                ._replacedLeaveIdTable(db)
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

typedef $$WorkLeaveRecordsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WorkLeaveRecordsTable,
      WorkLeaveRecord,
      $$WorkLeaveRecordsTableFilterComposer,
      $$WorkLeaveRecordsTableOrderingComposer,
      $$WorkLeaveRecordsTableAnnotationComposer,
      $$WorkLeaveRecordsTableCreateCompanionBuilder,
      $$WorkLeaveRecordsTableUpdateCompanionBuilder,
      (WorkLeaveRecord, $$WorkLeaveRecordsTableReferences),
      WorkLeaveRecord,
      PrefetchHooks Function({
        bool employmentId,
        bool agreementId,
        bool replacementLeaveId,
        bool replacedLeaveId,
      })
    >;
typedef $$RecordEventsTableCreateCompanionBuilder =
    RecordEventsCompanion Function({
      Value<int> id,
      required String recordKind,
      required String recordId,
      required int atUtcMicros,
      required String kind,
      required String changesJson,
      Value<String?> reason,
      required int revisionAfter,
    });
typedef $$RecordEventsTableUpdateCompanionBuilder =
    RecordEventsCompanion Function({
      Value<int> id,
      Value<String> recordKind,
      Value<String> recordId,
      Value<int> atUtcMicros,
      Value<String> kind,
      Value<String> changesJson,
      Value<String?> reason,
      Value<int> revisionAfter,
    });

class $$RecordEventsTableFilterComposer
    extends Composer<_$AppDatabase, $RecordEventsTable> {
  $$RecordEventsTableFilterComposer({
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

  ColumnFilters<String> get recordKind => $composableBuilder(
    column: $table.recordKind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get recordId => $composableBuilder(
    column: $table.recordId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get atUtcMicros => $composableBuilder(
    column: $table.atUtcMicros,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get changesJson => $composableBuilder(
    column: $table.changesJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reason => $composableBuilder(
    column: $table.reason,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get revisionAfter => $composableBuilder(
    column: $table.revisionAfter,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RecordEventsTableOrderingComposer
    extends Composer<_$AppDatabase, $RecordEventsTable> {
  $$RecordEventsTableOrderingComposer({
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

  ColumnOrderings<String> get recordKind => $composableBuilder(
    column: $table.recordKind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recordId => $composableBuilder(
    column: $table.recordId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get atUtcMicros => $composableBuilder(
    column: $table.atUtcMicros,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get changesJson => $composableBuilder(
    column: $table.changesJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reason => $composableBuilder(
    column: $table.reason,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get revisionAfter => $composableBuilder(
    column: $table.revisionAfter,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RecordEventsTableAnnotationComposer
    extends Composer<_$AppDatabase, $RecordEventsTable> {
  $$RecordEventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get recordKind => $composableBuilder(
    column: $table.recordKind,
    builder: (column) => column,
  );

  GeneratedColumn<String> get recordId =>
      $composableBuilder(column: $table.recordId, builder: (column) => column);

  GeneratedColumn<int> get atUtcMicros => $composableBuilder(
    column: $table.atUtcMicros,
    builder: (column) => column,
  );

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get changesJson => $composableBuilder(
    column: $table.changesJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get reason =>
      $composableBuilder(column: $table.reason, builder: (column) => column);

  GeneratedColumn<int> get revisionAfter => $composableBuilder(
    column: $table.revisionAfter,
    builder: (column) => column,
  );
}

class $$RecordEventsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RecordEventsTable,
          RecordEventRow,
          $$RecordEventsTableFilterComposer,
          $$RecordEventsTableOrderingComposer,
          $$RecordEventsTableAnnotationComposer,
          $$RecordEventsTableCreateCompanionBuilder,
          $$RecordEventsTableUpdateCompanionBuilder,
          (
            RecordEventRow,
            BaseReferences<_$AppDatabase, $RecordEventsTable, RecordEventRow>,
          ),
          RecordEventRow,
          PrefetchHooks Function()
        > {
  $$RecordEventsTableTableManager(_$AppDatabase db, $RecordEventsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RecordEventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RecordEventsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RecordEventsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> recordKind = const Value.absent(),
                Value<String> recordId = const Value.absent(),
                Value<int> atUtcMicros = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> changesJson = const Value.absent(),
                Value<String?> reason = const Value.absent(),
                Value<int> revisionAfter = const Value.absent(),
              }) => RecordEventsCompanion(
                id: id,
                recordKind: recordKind,
                recordId: recordId,
                atUtcMicros: atUtcMicros,
                kind: kind,
                changesJson: changesJson,
                reason: reason,
                revisionAfter: revisionAfter,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String recordKind,
                required String recordId,
                required int atUtcMicros,
                required String kind,
                required String changesJson,
                Value<String?> reason = const Value.absent(),
                required int revisionAfter,
              }) => RecordEventsCompanion.insert(
                id: id,
                recordKind: recordKind,
                recordId: recordId,
                atUtcMicros: atUtcMicros,
                kind: kind,
                changesJson: changesJson,
                reason: reason,
                revisionAfter: revisionAfter,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$RecordEventsTable, RecordEventRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $RecordEventsTable,
                    RecordEventRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RecordEventsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RecordEventsTable,
      RecordEventRow,
      $$RecordEventsTableFilterComposer,
      $$RecordEventsTableOrderingComposer,
      $$RecordEventsTableAnnotationComposer,
      $$RecordEventsTableCreateCompanionBuilder,
      $$RecordEventsTableUpdateCompanionBuilder,
      (
        RecordEventRow,
        BaseReferences<_$AppDatabase, $RecordEventsTable, RecordEventRow>,
      ),
      RecordEventRow,
      PrefetchHooks Function()
    >;
typedef $$DesksTableCreateCompanionBuilder = DesksCompanion Function({
  required String id,
  required String name,
  Value<String?> starterKey,
  required String layout,
  required int position,
  required int revision,
  Value<int> rowid,
});
typedef $$DesksTableUpdateCompanionBuilder = DesksCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<String?> starterKey,
  Value<String> layout,
  Value<int> position,
  Value<int> revision,
  Value<int> rowid,
});

final class $$DesksTableReferences
    extends BaseReferences<_$AppDatabase, $DesksTable, DeskRow> {
  $$DesksTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$DeskTilesTable, List<DeskTileRow>>
  _deskTilesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.deskTiles,
    aliasName: 'desks__id__desk_tiles__desk_id',
  );

  $$DeskTilesTableProcessedTableManager get deskTilesRefs {
    final manager = $$DeskTilesTableTableManager(
      $_db,
      $_db.deskTiles,
    ).filter((f) => f.deskId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_deskTilesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$DesksTableFilterComposer extends Composer<_$AppDatabase, $DesksTable> {
  $$DesksTableFilterComposer({
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

  ColumnFilters<String> get starterKey => $composableBuilder(
    column: $table.starterKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get layout => $composableBuilder(
    column: $table.layout,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> deskTilesRefs(
    Expression<bool> Function($$DeskTilesTableFilterComposer f) f,
  ) {
    final $$DeskTilesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.deskTiles,
      getReferencedColumn: (t) => t.deskId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DeskTilesTableFilterComposer(
            $db: $db,
            $table: $db.deskTiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$DesksTableOrderingComposer
    extends Composer<_$AppDatabase, $DesksTable> {
  $$DesksTableOrderingComposer({
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

  ColumnOrderings<String> get starterKey => $composableBuilder(
    column: $table.starterKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get layout => $composableBuilder(
    column: $table.layout,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DesksTableAnnotationComposer
    extends Composer<_$AppDatabase, $DesksTable> {
  $$DesksTableAnnotationComposer({
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

  GeneratedColumn<String> get starterKey => $composableBuilder(
    column: $table.starterKey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get layout =>
      $composableBuilder(column: $table.layout, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<int> get revision =>
      $composableBuilder(column: $table.revision, builder: (column) => column);

  Expression<T> deskTilesRefs<T extends Object>(
    Expression<T> Function($$DeskTilesTableAnnotationComposer a) f,
  ) {
    final $$DeskTilesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.deskTiles,
      getReferencedColumn: (t) => t.deskId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DeskTilesTableAnnotationComposer(
            $db: $db,
            $table: $db.deskTiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$DesksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DesksTable,
          DeskRow,
          $$DesksTableFilterComposer,
          $$DesksTableOrderingComposer,
          $$DesksTableAnnotationComposer,
          $$DesksTableCreateCompanionBuilder,
          $$DesksTableUpdateCompanionBuilder,
          (DeskRow, $$DesksTableReferences),
          DeskRow,
          PrefetchHooks Function({bool deskTilesRefs})
        > {
  $$DesksTableTableManager(_$AppDatabase db, $DesksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DesksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DesksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DesksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> starterKey = const Value.absent(),
                Value<String> layout = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DesksCompanion(
                id: id,
                name: name,
                starterKey: starterKey,
                layout: layout,
                position: position,
                revision: revision,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<String?> starterKey = const Value.absent(),
                required String layout,
                required int position,
                required int revision,
                Value<int> rowid = const Value.absent(),
              }) => DesksCompanion.insert(
                id: id,
                name: name,
                starterKey: starterKey,
                layout: layout,
                position: position,
                revision: revision,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$DesksTable, DeskRow>(table),
                  $$DesksTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({deskTilesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (deskTilesRefs) db.deskTiles],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (deskTilesRefs)
                    await $_getPrefetchedData<
                      DeskRow,
                      $DesksTable,
                      DeskTileRow
                    >(
                      currentTable: table,
                      referencedTable: $$DesksTableReferences
                          ._deskTilesRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$DesksTableReferences(db, table, p0).deskTilesRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.deskId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$DesksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DesksTable,
      DeskRow,
      $$DesksTableFilterComposer,
      $$DesksTableOrderingComposer,
      $$DesksTableAnnotationComposer,
      $$DesksTableCreateCompanionBuilder,
      $$DesksTableUpdateCompanionBuilder,
      (DeskRow, $$DesksTableReferences),
      DeskRow,
      PrefetchHooks Function({bool deskTilesRefs})
    >;
typedef $$SavedViewsTableCreateCompanionBuilder = SavedViewsCompanion Function({
  required String id,
  required String name,
  required String sheetRef,
  required String filtersJson,
  Value<String?> sortJson,
  Value<String?> columnsJson,
  required int position,
  required int revision,
  Value<int> rowid,
});
typedef $$SavedViewsTableUpdateCompanionBuilder = SavedViewsCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<String> sheetRef,
  Value<String> filtersJson,
  Value<String?> sortJson,
  Value<String?> columnsJson,
  Value<int> position,
  Value<int> revision,
  Value<int> rowid,
});

final class $$SavedViewsTableReferences
    extends BaseReferences<_$AppDatabase, $SavedViewsTable, SavedViewRow> {
  $$SavedViewsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$DeskTilesTable, List<DeskTileRow>>
  _deskTilesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.deskTiles,
    aliasName: 'saved_views__id__desk_tiles__view_id',
  );

  $$DeskTilesTableProcessedTableManager get deskTilesRefs {
    final manager = $$DeskTilesTableTableManager(
      $_db,
      $_db.deskTiles,
    ).filter((f) => f.viewId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_deskTilesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$SavedViewsTableFilterComposer
    extends Composer<_$AppDatabase, $SavedViewsTable> {
  $$SavedViewsTableFilterComposer({
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

  ColumnFilters<String> get sheetRef => $composableBuilder(
    column: $table.sheetRef,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get filtersJson => $composableBuilder(
    column: $table.filtersJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sortJson => $composableBuilder(
    column: $table.sortJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get columnsJson => $composableBuilder(
    column: $table.columnsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> deskTilesRefs(
    Expression<bool> Function($$DeskTilesTableFilterComposer f) f,
  ) {
    final $$DeskTilesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.deskTiles,
      getReferencedColumn: (t) => t.viewId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DeskTilesTableFilterComposer(
            $db: $db,
            $table: $db.deskTiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SavedViewsTableOrderingComposer
    extends Composer<_$AppDatabase, $SavedViewsTable> {
  $$SavedViewsTableOrderingComposer({
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

  ColumnOrderings<String> get sheetRef => $composableBuilder(
    column: $table.sheetRef,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get filtersJson => $composableBuilder(
    column: $table.filtersJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sortJson => $composableBuilder(
    column: $table.sortJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get columnsJson => $composableBuilder(
    column: $table.columnsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SavedViewsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SavedViewsTable> {
  $$SavedViewsTableAnnotationComposer({
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

  GeneratedColumn<String> get sheetRef =>
      $composableBuilder(column: $table.sheetRef, builder: (column) => column);

  GeneratedColumn<String> get filtersJson => $composableBuilder(
    column: $table.filtersJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sortJson =>
      $composableBuilder(column: $table.sortJson, builder: (column) => column);

  GeneratedColumn<String> get columnsJson => $composableBuilder(
    column: $table.columnsJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<int> get revision =>
      $composableBuilder(column: $table.revision, builder: (column) => column);

  Expression<T> deskTilesRefs<T extends Object>(
    Expression<T> Function($$DeskTilesTableAnnotationComposer a) f,
  ) {
    final $$DeskTilesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.deskTiles,
      getReferencedColumn: (t) => t.viewId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DeskTilesTableAnnotationComposer(
            $db: $db,
            $table: $db.deskTiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SavedViewsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SavedViewsTable,
          SavedViewRow,
          $$SavedViewsTableFilterComposer,
          $$SavedViewsTableOrderingComposer,
          $$SavedViewsTableAnnotationComposer,
          $$SavedViewsTableCreateCompanionBuilder,
          $$SavedViewsTableUpdateCompanionBuilder,
          (SavedViewRow, $$SavedViewsTableReferences),
          SavedViewRow,
          PrefetchHooks Function({bool deskTilesRefs})
        > {
  $$SavedViewsTableTableManager(_$AppDatabase db, $SavedViewsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SavedViewsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SavedViewsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SavedViewsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> sheetRef = const Value.absent(),
                Value<String> filtersJson = const Value.absent(),
                Value<String?> sortJson = const Value.absent(),
                Value<String?> columnsJson = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SavedViewsCompanion(
                id: id,
                name: name,
                sheetRef: sheetRef,
                filtersJson: filtersJson,
                sortJson: sortJson,
                columnsJson: columnsJson,
                position: position,
                revision: revision,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String sheetRef,
                required String filtersJson,
                Value<String?> sortJson = const Value.absent(),
                Value<String?> columnsJson = const Value.absent(),
                required int position,
                required int revision,
                Value<int> rowid = const Value.absent(),
              }) => SavedViewsCompanion.insert(
                id: id,
                name: name,
                sheetRef: sheetRef,
                filtersJson: filtersJson,
                sortJson: sortJson,
                columnsJson: columnsJson,
                position: position,
                revision: revision,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SavedViewsTable, SavedViewRow>(table),
                  $$SavedViewsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({deskTilesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (deskTilesRefs) db.deskTiles],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (deskTilesRefs)
                    await $_getPrefetchedData<
                      SavedViewRow,
                      $SavedViewsTable,
                      DeskTileRow
                    >(
                      currentTable: table,
                      referencedTable: $$SavedViewsTableReferences
                          ._deskTilesRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$SavedViewsTableReferences(
                            db,
                            table,
                            p0,
                          ).deskTilesRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.viewId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$SavedViewsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SavedViewsTable,
      SavedViewRow,
      $$SavedViewsTableFilterComposer,
      $$SavedViewsTableOrderingComposer,
      $$SavedViewsTableAnnotationComposer,
      $$SavedViewsTableCreateCompanionBuilder,
      $$SavedViewsTableUpdateCompanionBuilder,
      (SavedViewRow, $$SavedViewsTableReferences),
      SavedViewRow,
      PrefetchHooks Function({bool deskTilesRefs})
    >;
typedef $$DeskTilesTableCreateCompanionBuilder = DeskTilesCompanion Function({
  required String id,
  required String deskId,
  required int position,
  required String sheetRef,
  Value<String?> viewId,
  Value<int> rowid,
});
typedef $$DeskTilesTableUpdateCompanionBuilder = DeskTilesCompanion Function({
  Value<String> id,
  Value<String> deskId,
  Value<int> position,
  Value<String> sheetRef,
  Value<String?> viewId,
  Value<int> rowid,
});

final class $$DeskTilesTableReferences
    extends BaseReferences<_$AppDatabase, $DeskTilesTable, DeskTileRow> {
  $$DeskTilesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $DesksTable _deskIdTable(_$AppDatabase db) =>
      db.desks.createAlias('desk_tiles__desk_id__desks__id');

  $$DesksTableProcessedTableManager get deskId {
    final $_column = $_itemColumn<String>('desk_id')!;

    final manager = $$DesksTableTableManager(
      $_db,
      $_db.desks,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_deskIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $SavedViewsTable _viewIdTable(_$AppDatabase db) =>
      db.savedViews.createAlias('desk_tiles__view_id__saved_views__id');

  $$SavedViewsTableProcessedTableManager? get viewId {
    final $_column = $_itemColumn<String>('view_id');
    if ($_column == null) return null;
    final manager = $$SavedViewsTableTableManager(
      $_db,
      $_db.savedViews,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_viewIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$DeskTilesTableFilterComposer
    extends Composer<_$AppDatabase, $DeskTilesTable> {
  $$DeskTilesTableFilterComposer({
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

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sheetRef => $composableBuilder(
    column: $table.sheetRef,
    builder: (column) => ColumnFilters(column),
  );

  $$DesksTableFilterComposer get deskId {
    final $$DesksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.deskId,
      referencedTable: $db.desks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DesksTableFilterComposer(
            $db: $db,
            $table: $db.desks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$SavedViewsTableFilterComposer get viewId {
    final $$SavedViewsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.viewId,
      referencedTable: $db.savedViews,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SavedViewsTableFilterComposer(
            $db: $db,
            $table: $db.savedViews,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DeskTilesTableOrderingComposer
    extends Composer<_$AppDatabase, $DeskTilesTable> {
  $$DeskTilesTableOrderingComposer({
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

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sheetRef => $composableBuilder(
    column: $table.sheetRef,
    builder: (column) => ColumnOrderings(column),
  );

  $$DesksTableOrderingComposer get deskId {
    final $$DesksTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.deskId,
      referencedTable: $db.desks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DesksTableOrderingComposer(
            $db: $db,
            $table: $db.desks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$SavedViewsTableOrderingComposer get viewId {
    final $$SavedViewsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.viewId,
      referencedTable: $db.savedViews,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SavedViewsTableOrderingComposer(
            $db: $db,
            $table: $db.savedViews,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DeskTilesTableAnnotationComposer
    extends Composer<_$AppDatabase, $DeskTilesTable> {
  $$DeskTilesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<String> get sheetRef =>
      $composableBuilder(column: $table.sheetRef, builder: (column) => column);

  $$DesksTableAnnotationComposer get deskId {
    final $$DesksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.deskId,
      referencedTable: $db.desks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DesksTableAnnotationComposer(
            $db: $db,
            $table: $db.desks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$SavedViewsTableAnnotationComposer get viewId {
    final $$SavedViewsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.viewId,
      referencedTable: $db.savedViews,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SavedViewsTableAnnotationComposer(
            $db: $db,
            $table: $db.savedViews,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DeskTilesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DeskTilesTable,
          DeskTileRow,
          $$DeskTilesTableFilterComposer,
          $$DeskTilesTableOrderingComposer,
          $$DeskTilesTableAnnotationComposer,
          $$DeskTilesTableCreateCompanionBuilder,
          $$DeskTilesTableUpdateCompanionBuilder,
          (DeskTileRow, $$DeskTilesTableReferences),
          DeskTileRow,
          PrefetchHooks Function({bool deskId, bool viewId})
        > {
  $$DeskTilesTableTableManager(_$AppDatabase db, $DeskTilesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DeskTilesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DeskTilesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DeskTilesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> deskId = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<String> sheetRef = const Value.absent(),
                Value<String?> viewId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DeskTilesCompanion(
                id: id,
                deskId: deskId,
                position: position,
                sheetRef: sheetRef,
                viewId: viewId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String deskId,
                required int position,
                required String sheetRef,
                Value<String?> viewId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DeskTilesCompanion.insert(
                id: id,
                deskId: deskId,
                position: position,
                sheetRef: sheetRef,
                viewId: viewId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$DeskTilesTable, DeskTileRow>(table),
                  $$DeskTilesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({deskId = false, viewId = false}) {
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
                    if (deskId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.deskId,
                        referencedTable: $$DeskTilesTableReferences
                            ._deskIdTable(db),
                        referencedColumn: $$DeskTilesTableReferences
                            ._deskIdTable(db)
                            .id,
                      ) as T;
                    }
                    if (viewId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.viewId,
                        referencedTable: $$DeskTilesTableReferences
                            ._viewIdTable(db),
                        referencedColumn: $$DeskTilesTableReferences
                            ._viewIdTable(db)
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

typedef $$DeskTilesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DeskTilesTable,
      DeskTileRow,
      $$DeskTilesTableFilterComposer,
      $$DeskTilesTableOrderingComposer,
      $$DeskTilesTableAnnotationComposer,
      $$DeskTilesTableCreateCompanionBuilder,
      $$DeskTilesTableUpdateCompanionBuilder,
      (DeskTileRow, $$DeskTilesTableReferences),
      DeskTileRow,
      PrefetchHooks Function({bool deskId, bool viewId})
    >;
typedef $$PreferencesTableCreateCompanionBuilder =
    PreferencesCompanion Function({
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $$PreferencesTableUpdateCompanionBuilder =
    PreferencesCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $$PreferencesTableFilterComposer
    extends Composer<_$AppDatabase, $PreferencesTable> {
  $$PreferencesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PreferencesTableOrderingComposer
    extends Composer<_$AppDatabase, $PreferencesTable> {
  $$PreferencesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PreferencesTableAnnotationComposer
    extends Composer<_$AppDatabase, $PreferencesTable> {
  $$PreferencesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$PreferencesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PreferencesTable,
          PreferenceRow,
          $$PreferencesTableFilterComposer,
          $$PreferencesTableOrderingComposer,
          $$PreferencesTableAnnotationComposer,
          $$PreferencesTableCreateCompanionBuilder,
          $$PreferencesTableUpdateCompanionBuilder,
          (
            PreferenceRow,
            BaseReferences<_$AppDatabase, $PreferencesTable, PreferenceRow>,
          ),
          PreferenceRow,
          PrefetchHooks Function()
        > {
  $$PreferencesTableTableManager(_$AppDatabase db, $PreferencesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PreferencesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PreferencesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PreferencesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => PreferencesCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => PreferencesCompanion.insert(
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PreferencesTable, PreferenceRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $PreferencesTable,
                    PreferenceRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PreferencesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PreferencesTable,
      PreferenceRow,
      $$PreferencesTableFilterComposer,
      $$PreferencesTableOrderingComposer,
      $$PreferencesTableAnnotationComposer,
      $$PreferencesTableCreateCompanionBuilder,
      $$PreferencesTableUpdateCompanionBuilder,
      (
        PreferenceRow,
        BaseReferences<_$AppDatabase, $PreferencesTable, PreferenceRow>,
      ),
      PreferenceRow,
      PrefetchHooks Function()
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
  $$WorkSchedulesTableTableManager get workSchedules =>
      $$WorkSchedulesTableTableManager(_db, _db.workSchedules);
  $$WorkScheduleShiftTypesTableTableManager get workScheduleShiftTypes =>
      $$WorkScheduleShiftTypesTableTableManager(
        _db,
        _db.workScheduleShiftTypes,
      );
  $$WorkScheduleBlocksTableTableManager get workScheduleBlocks =>
      $$WorkScheduleBlocksTableTableManager(_db, _db.workScheduleBlocks);
  $$WorkDayExceptionsTableTableManager get workDayExceptions =>
      $$WorkDayExceptionsTableTableManager(_db, _db.workDayExceptions);
  $$WorkLeaveRecordsTableTableManager get workLeaveRecords =>
      $$WorkLeaveRecordsTableTableManager(_db, _db.workLeaveRecords);
  $$RecordEventsTableTableManager get recordEvents =>
      $$RecordEventsTableTableManager(_db, _db.recordEvents);
  $$DesksTableTableManager get desks =>
      $$DesksTableTableManager(_db, _db.desks);
  $$SavedViewsTableTableManager get savedViews =>
      $$SavedViewsTableTableManager(_db, _db.savedViews);
  $$DeskTilesTableTableManager get deskTiles =>
      $$DeskTilesTableTableManager(_db, _db.deskTiles);
  $$PreferencesTableTableManager get preferences =>
      $$PreferencesTableTableManager(_db, _db.preferences);
}
