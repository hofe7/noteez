// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $StickiesTable extends Stickies
    with TableInfo<$StickiesTable, StickyRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StickiesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _colorIndexMeta = const VerificationMeta(
    'colorIndex',
  );
  @override
  late final GeneratedColumn<int> colorIndex = GeneratedColumn<int>(
    'color_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _xMeta = const VerificationMeta('x');
  @override
  late final GeneratedColumn<double> x = GeneratedColumn<double>(
    'x',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _yMeta = const VerificationMeta('y');
  @override
  late final GeneratedColumn<double> y = GeneratedColumn<double>(
    'y',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _collapsedMeta = const VerificationMeta(
    'collapsed',
  );
  @override
  late final GeneratedColumn<bool> collapsed = GeneratedColumn<bool>(
    'collapsed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("collapsed" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
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
  static const VerificationMeta _openMeta = const VerificationMeta('open');
  @override
  late final GeneratedColumn<bool> open = GeneratedColumn<bool>(
    'open',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("open" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _remindAtMeta = const VerificationMeta(
    'remindAt',
  );
  @override
  late final GeneratedColumn<int> remindAt = GeneratedColumn<int>(
    'remind_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _blocksJsonMeta = const VerificationMeta(
    'blocksJson',
  );
  @override
  late final GeneratedColumn<String> blocksJson = GeneratedColumn<String>(
    'blocks_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<int> deletedAt = GeneratedColumn<int>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    colorIndex,
    x,
    y,
    collapsed,
    pinned,
    open,
    remindAt,
    blocksJson,
    createdAt,
    updatedAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'stickies';
  @override
  VerificationContext validateIntegrity(
    Insertable<StickyRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('color_index')) {
      context.handle(
        _colorIndexMeta,
        colorIndex.isAcceptableOrUnknown(data['color_index']!, _colorIndexMeta),
      );
    } else if (isInserting) {
      context.missing(_colorIndexMeta);
    }
    if (data.containsKey('x')) {
      context.handle(_xMeta, x.isAcceptableOrUnknown(data['x']!, _xMeta));
    } else if (isInserting) {
      context.missing(_xMeta);
    }
    if (data.containsKey('y')) {
      context.handle(_yMeta, y.isAcceptableOrUnknown(data['y']!, _yMeta));
    } else if (isInserting) {
      context.missing(_yMeta);
    }
    if (data.containsKey('collapsed')) {
      context.handle(
        _collapsedMeta,
        collapsed.isAcceptableOrUnknown(data['collapsed']!, _collapsedMeta),
      );
    }
    if (data.containsKey('pinned')) {
      context.handle(
        _pinnedMeta,
        pinned.isAcceptableOrUnknown(data['pinned']!, _pinnedMeta),
      );
    }
    if (data.containsKey('open')) {
      context.handle(
        _openMeta,
        open.isAcceptableOrUnknown(data['open']!, _openMeta),
      );
    }
    if (data.containsKey('remind_at')) {
      context.handle(
        _remindAtMeta,
        remindAt.isAcceptableOrUnknown(data['remind_at']!, _remindAtMeta),
      );
    }
    if (data.containsKey('blocks_json')) {
      context.handle(
        _blocksJsonMeta,
        blocksJson.isAcceptableOrUnknown(data['blocks_json']!, _blocksJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_blocksJsonMeta);
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
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  StickyRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StickyRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      colorIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}color_index'],
      )!,
      x: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}x'],
      )!,
      y: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}y'],
      )!,
      collapsed: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}collapsed'],
      )!,
      pinned: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}pinned'],
      )!,
      open: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}open'],
      )!,
      remindAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}remind_at'],
      ),
      blocksJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}blocks_json'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $StickiesTable createAlias(String alias) {
    return $StickiesTable(attachedDatabase, alias);
  }
}

class StickyRow extends DataClass implements Insertable<StickyRow> {
  final String id;
  final int colorIndex;
  final double x;
  final double y;
  final bool collapsed;
  final bool pinned;
  final bool open;
  final int? remindAt;
  final String blocksJson;
  final int createdAt;
  final int updatedAt;
  final int? deletedAt;
  const StickyRow({
    required this.id,
    required this.colorIndex,
    required this.x,
    required this.y,
    required this.collapsed,
    required this.pinned,
    required this.open,
    this.remindAt,
    required this.blocksJson,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['color_index'] = Variable<int>(colorIndex);
    map['x'] = Variable<double>(x);
    map['y'] = Variable<double>(y);
    map['collapsed'] = Variable<bool>(collapsed);
    map['pinned'] = Variable<bool>(pinned);
    map['open'] = Variable<bool>(open);
    if (!nullToAbsent || remindAt != null) {
      map['remind_at'] = Variable<int>(remindAt);
    }
    map['blocks_json'] = Variable<String>(blocksJson);
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<int>(deletedAt);
    }
    return map;
  }

  StickiesCompanion toCompanion(bool nullToAbsent) {
    return StickiesCompanion(
      id: Value(id),
      colorIndex: Value(colorIndex),
      x: Value(x),
      y: Value(y),
      collapsed: Value(collapsed),
      pinned: Value(pinned),
      open: Value(open),
      remindAt: remindAt == null && nullToAbsent
          ? const Value.absent()
          : Value(remindAt),
      blocksJson: Value(blocksJson),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory StickyRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StickyRow(
      id: serializer.fromJson<String>(json['id']),
      colorIndex: serializer.fromJson<int>(json['colorIndex']),
      x: serializer.fromJson<double>(json['x']),
      y: serializer.fromJson<double>(json['y']),
      collapsed: serializer.fromJson<bool>(json['collapsed']),
      pinned: serializer.fromJson<bool>(json['pinned']),
      open: serializer.fromJson<bool>(json['open']),
      remindAt: serializer.fromJson<int?>(json['remindAt']),
      blocksJson: serializer.fromJson<String>(json['blocksJson']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      deletedAt: serializer.fromJson<int?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'colorIndex': serializer.toJson<int>(colorIndex),
      'x': serializer.toJson<double>(x),
      'y': serializer.toJson<double>(y),
      'collapsed': serializer.toJson<bool>(collapsed),
      'pinned': serializer.toJson<bool>(pinned),
      'open': serializer.toJson<bool>(open),
      'remindAt': serializer.toJson<int?>(remindAt),
      'blocksJson': serializer.toJson<String>(blocksJson),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'deletedAt': serializer.toJson<int?>(deletedAt),
    };
  }

  StickyRow copyWith({
    String? id,
    int? colorIndex,
    double? x,
    double? y,
    bool? collapsed,
    bool? pinned,
    bool? open,
    Value<int?> remindAt = const Value.absent(),
    String? blocksJson,
    int? createdAt,
    int? updatedAt,
    Value<int?> deletedAt = const Value.absent(),
  }) => StickyRow(
    id: id ?? this.id,
    colorIndex: colorIndex ?? this.colorIndex,
    x: x ?? this.x,
    y: y ?? this.y,
    collapsed: collapsed ?? this.collapsed,
    pinned: pinned ?? this.pinned,
    open: open ?? this.open,
    remindAt: remindAt.present ? remindAt.value : this.remindAt,
    blocksJson: blocksJson ?? this.blocksJson,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  StickyRow copyWithCompanion(StickiesCompanion data) {
    return StickyRow(
      id: data.id.present ? data.id.value : this.id,
      colorIndex: data.colorIndex.present
          ? data.colorIndex.value
          : this.colorIndex,
      x: data.x.present ? data.x.value : this.x,
      y: data.y.present ? data.y.value : this.y,
      collapsed: data.collapsed.present ? data.collapsed.value : this.collapsed,
      pinned: data.pinned.present ? data.pinned.value : this.pinned,
      open: data.open.present ? data.open.value : this.open,
      remindAt: data.remindAt.present ? data.remindAt.value : this.remindAt,
      blocksJson: data.blocksJson.present
          ? data.blocksJson.value
          : this.blocksJson,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StickyRow(')
          ..write('id: $id, ')
          ..write('colorIndex: $colorIndex, ')
          ..write('x: $x, ')
          ..write('y: $y, ')
          ..write('collapsed: $collapsed, ')
          ..write('pinned: $pinned, ')
          ..write('open: $open, ')
          ..write('remindAt: $remindAt, ')
          ..write('blocksJson: $blocksJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    colorIndex,
    x,
    y,
    collapsed,
    pinned,
    open,
    remindAt,
    blocksJson,
    createdAt,
    updatedAt,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StickyRow &&
          other.id == this.id &&
          other.colorIndex == this.colorIndex &&
          other.x == this.x &&
          other.y == this.y &&
          other.collapsed == this.collapsed &&
          other.pinned == this.pinned &&
          other.open == this.open &&
          other.remindAt == this.remindAt &&
          other.blocksJson == this.blocksJson &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class StickiesCompanion extends UpdateCompanion<StickyRow> {
  final Value<String> id;
  final Value<int> colorIndex;
  final Value<double> x;
  final Value<double> y;
  final Value<bool> collapsed;
  final Value<bool> pinned;
  final Value<bool> open;
  final Value<int?> remindAt;
  final Value<String> blocksJson;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int?> deletedAt;
  final Value<int> rowid;
  const StickiesCompanion({
    this.id = const Value.absent(),
    this.colorIndex = const Value.absent(),
    this.x = const Value.absent(),
    this.y = const Value.absent(),
    this.collapsed = const Value.absent(),
    this.pinned = const Value.absent(),
    this.open = const Value.absent(),
    this.remindAt = const Value.absent(),
    this.blocksJson = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  StickiesCompanion.insert({
    required String id,
    required int colorIndex,
    required double x,
    required double y,
    this.collapsed = const Value.absent(),
    this.pinned = const Value.absent(),
    this.open = const Value.absent(),
    this.remindAt = const Value.absent(),
    required String blocksJson,
    required int createdAt,
    required int updatedAt,
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       colorIndex = Value(colorIndex),
       x = Value(x),
       y = Value(y),
       blocksJson = Value(blocksJson),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<StickyRow> custom({
    Expression<String>? id,
    Expression<int>? colorIndex,
    Expression<double>? x,
    Expression<double>? y,
    Expression<bool>? collapsed,
    Expression<bool>? pinned,
    Expression<bool>? open,
    Expression<int>? remindAt,
    Expression<String>? blocksJson,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (colorIndex != null) 'color_index': colorIndex,
      if (x != null) 'x': x,
      if (y != null) 'y': y,
      if (collapsed != null) 'collapsed': collapsed,
      if (pinned != null) 'pinned': pinned,
      if (open != null) 'open': open,
      if (remindAt != null) 'remind_at': remindAt,
      if (blocksJson != null) 'blocks_json': blocksJson,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  StickiesCompanion copyWith({
    Value<String>? id,
    Value<int>? colorIndex,
    Value<double>? x,
    Value<double>? y,
    Value<bool>? collapsed,
    Value<bool>? pinned,
    Value<bool>? open,
    Value<int?>? remindAt,
    Value<String>? blocksJson,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int?>? deletedAt,
    Value<int>? rowid,
  }) {
    return StickiesCompanion(
      id: id ?? this.id,
      colorIndex: colorIndex ?? this.colorIndex,
      x: x ?? this.x,
      y: y ?? this.y,
      collapsed: collapsed ?? this.collapsed,
      pinned: pinned ?? this.pinned,
      open: open ?? this.open,
      remindAt: remindAt ?? this.remindAt,
      blocksJson: blocksJson ?? this.blocksJson,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (colorIndex.present) {
      map['color_index'] = Variable<int>(colorIndex.value);
    }
    if (x.present) {
      map['x'] = Variable<double>(x.value);
    }
    if (y.present) {
      map['y'] = Variable<double>(y.value);
    }
    if (collapsed.present) {
      map['collapsed'] = Variable<bool>(collapsed.value);
    }
    if (pinned.present) {
      map['pinned'] = Variable<bool>(pinned.value);
    }
    if (open.present) {
      map['open'] = Variable<bool>(open.value);
    }
    if (remindAt.present) {
      map['remind_at'] = Variable<int>(remindAt.value);
    }
    if (blocksJson.present) {
      map['blocks_json'] = Variable<String>(blocksJson.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<int>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StickiesCompanion(')
          ..write('id: $id, ')
          ..write('colorIndex: $colorIndex, ')
          ..write('x: $x, ')
          ..write('y: $y, ')
          ..write('collapsed: $collapsed, ')
          ..write('pinned: $pinned, ')
          ..write('open: $open, ')
          ..write('remindAt: $remindAt, ')
          ..write('blocksJson: $blocksJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LinksTable extends Links with TableInfo<$LinksTable, LinkRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LinksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _aIdMeta = const VerificationMeta('aId');
  @override
  late final GeneratedColumn<String> aId = GeneratedColumn<String>(
    'a_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bIdMeta = const VerificationMeta('bId');
  @override
  late final GeneratedColumn<String> bId = GeneratedColumn<String>(
    'b_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<int> deletedAt = GeneratedColumn<int>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [id, aId, bId, createdAt, deletedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'links';
  @override
  VerificationContext validateIntegrity(
    Insertable<LinkRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('a_id')) {
      context.handle(
        _aIdMeta,
        aId.isAcceptableOrUnknown(data['a_id']!, _aIdMeta),
      );
    } else if (isInserting) {
      context.missing(_aIdMeta);
    }
    if (data.containsKey('b_id')) {
      context.handle(
        _bIdMeta,
        bId.isAcceptableOrUnknown(data['b_id']!, _bIdMeta),
      );
    } else if (isInserting) {
      context.missing(_bIdMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LinkRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LinkRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      aId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}a_id'],
      )!,
      bId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}b_id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $LinksTable createAlias(String alias) {
    return $LinksTable(attachedDatabase, alias);
  }
}

class LinkRow extends DataClass implements Insertable<LinkRow> {
  final String id;
  final String aId;
  final String bId;
  final int createdAt;
  final int? deletedAt;
  const LinkRow({
    required this.id,
    required this.aId,
    required this.bId,
    required this.createdAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['a_id'] = Variable<String>(aId);
    map['b_id'] = Variable<String>(bId);
    map['created_at'] = Variable<int>(createdAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<int>(deletedAt);
    }
    return map;
  }

  LinksCompanion toCompanion(bool nullToAbsent) {
    return LinksCompanion(
      id: Value(id),
      aId: Value(aId),
      bId: Value(bId),
      createdAt: Value(createdAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory LinkRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LinkRow(
      id: serializer.fromJson<String>(json['id']),
      aId: serializer.fromJson<String>(json['aId']),
      bId: serializer.fromJson<String>(json['bId']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      deletedAt: serializer.fromJson<int?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'aId': serializer.toJson<String>(aId),
      'bId': serializer.toJson<String>(bId),
      'createdAt': serializer.toJson<int>(createdAt),
      'deletedAt': serializer.toJson<int?>(deletedAt),
    };
  }

  LinkRow copyWith({
    String? id,
    String? aId,
    String? bId,
    int? createdAt,
    Value<int?> deletedAt = const Value.absent(),
  }) => LinkRow(
    id: id ?? this.id,
    aId: aId ?? this.aId,
    bId: bId ?? this.bId,
    createdAt: createdAt ?? this.createdAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  LinkRow copyWithCompanion(LinksCompanion data) {
    return LinkRow(
      id: data.id.present ? data.id.value : this.id,
      aId: data.aId.present ? data.aId.value : this.aId,
      bId: data.bId.present ? data.bId.value : this.bId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LinkRow(')
          ..write('id: $id, ')
          ..write('aId: $aId, ')
          ..write('bId: $bId, ')
          ..write('createdAt: $createdAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, aId, bId, createdAt, deletedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LinkRow &&
          other.id == this.id &&
          other.aId == this.aId &&
          other.bId == this.bId &&
          other.createdAt == this.createdAt &&
          other.deletedAt == this.deletedAt);
}

class LinksCompanion extends UpdateCompanion<LinkRow> {
  final Value<String> id;
  final Value<String> aId;
  final Value<String> bId;
  final Value<int> createdAt;
  final Value<int?> deletedAt;
  final Value<int> rowid;
  const LinksCompanion({
    this.id = const Value.absent(),
    this.aId = const Value.absent(),
    this.bId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LinksCompanion.insert({
    required String id,
    required String aId,
    required String bId,
    required int createdAt,
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       aId = Value(aId),
       bId = Value(bId),
       createdAt = Value(createdAt);
  static Insertable<LinkRow> custom({
    Expression<String>? id,
    Expression<String>? aId,
    Expression<String>? bId,
    Expression<int>? createdAt,
    Expression<int>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (aId != null) 'a_id': aId,
      if (bId != null) 'b_id': bId,
      if (createdAt != null) 'created_at': createdAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LinksCompanion copyWith({
    Value<String>? id,
    Value<String>? aId,
    Value<String>? bId,
    Value<int>? createdAt,
    Value<int?>? deletedAt,
    Value<int>? rowid,
  }) {
    return LinksCompanion(
      id: id ?? this.id,
      aId: aId ?? this.aId,
      bId: bId ?? this.bId,
      createdAt: createdAt ?? this.createdAt,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (aId.present) {
      map['a_id'] = Variable<String>(aId.value);
    }
    if (bId.present) {
      map['b_id'] = Variable<String>(bId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<int>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LinksCompanion(')
          ..write('id: $id, ')
          ..write('aId: $aId, ')
          ..write('bId: $bId, ')
          ..write('createdAt: $createdAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $EmbeddingsTable extends Embeddings
    with TableInfo<$EmbeddingsTable, EmbeddingRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EmbeddingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _stickyIdMeta = const VerificationMeta(
    'stickyId',
  );
  @override
  late final GeneratedColumn<String> stickyId = GeneratedColumn<String>(
    'sticky_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _hashMeta = const VerificationMeta('hash');
  @override
  late final GeneratedColumn<String> hash = GeneratedColumn<String>(
    'hash',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _vecMeta = const VerificationMeta('vec');
  @override
  late final GeneratedColumn<String> vec = GeneratedColumn<String>(
    'vec',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [stickyId, hash, vec];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'embeddings';
  @override
  VerificationContext validateIntegrity(
    Insertable<EmbeddingRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('sticky_id')) {
      context.handle(
        _stickyIdMeta,
        stickyId.isAcceptableOrUnknown(data['sticky_id']!, _stickyIdMeta),
      );
    } else if (isInserting) {
      context.missing(_stickyIdMeta);
    }
    if (data.containsKey('hash')) {
      context.handle(
        _hashMeta,
        hash.isAcceptableOrUnknown(data['hash']!, _hashMeta),
      );
    } else if (isInserting) {
      context.missing(_hashMeta);
    }
    if (data.containsKey('vec')) {
      context.handle(
        _vecMeta,
        vec.isAcceptableOrUnknown(data['vec']!, _vecMeta),
      );
    } else if (isInserting) {
      context.missing(_vecMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {stickyId};
  @override
  EmbeddingRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EmbeddingRow(
      stickyId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sticky_id'],
      )!,
      hash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}hash'],
      )!,
      vec: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}vec'],
      )!,
    );
  }

  @override
  $EmbeddingsTable createAlias(String alias) {
    return $EmbeddingsTable(attachedDatabase, alias);
  }
}

class EmbeddingRow extends DataClass implements Insertable<EmbeddingRow> {
  final String stickyId;
  final String hash;
  final String vec;
  const EmbeddingRow({
    required this.stickyId,
    required this.hash,
    required this.vec,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['sticky_id'] = Variable<String>(stickyId);
    map['hash'] = Variable<String>(hash);
    map['vec'] = Variable<String>(vec);
    return map;
  }

  EmbeddingsCompanion toCompanion(bool nullToAbsent) {
    return EmbeddingsCompanion(
      stickyId: Value(stickyId),
      hash: Value(hash),
      vec: Value(vec),
    );
  }

  factory EmbeddingRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EmbeddingRow(
      stickyId: serializer.fromJson<String>(json['stickyId']),
      hash: serializer.fromJson<String>(json['hash']),
      vec: serializer.fromJson<String>(json['vec']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'stickyId': serializer.toJson<String>(stickyId),
      'hash': serializer.toJson<String>(hash),
      'vec': serializer.toJson<String>(vec),
    };
  }

  EmbeddingRow copyWith({String? stickyId, String? hash, String? vec}) =>
      EmbeddingRow(
        stickyId: stickyId ?? this.stickyId,
        hash: hash ?? this.hash,
        vec: vec ?? this.vec,
      );
  EmbeddingRow copyWithCompanion(EmbeddingsCompanion data) {
    return EmbeddingRow(
      stickyId: data.stickyId.present ? data.stickyId.value : this.stickyId,
      hash: data.hash.present ? data.hash.value : this.hash,
      vec: data.vec.present ? data.vec.value : this.vec,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EmbeddingRow(')
          ..write('stickyId: $stickyId, ')
          ..write('hash: $hash, ')
          ..write('vec: $vec')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(stickyId, hash, vec);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EmbeddingRow &&
          other.stickyId == this.stickyId &&
          other.hash == this.hash &&
          other.vec == this.vec);
}

class EmbeddingsCompanion extends UpdateCompanion<EmbeddingRow> {
  final Value<String> stickyId;
  final Value<String> hash;
  final Value<String> vec;
  final Value<int> rowid;
  const EmbeddingsCompanion({
    this.stickyId = const Value.absent(),
    this.hash = const Value.absent(),
    this.vec = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  EmbeddingsCompanion.insert({
    required String stickyId,
    required String hash,
    required String vec,
    this.rowid = const Value.absent(),
  }) : stickyId = Value(stickyId),
       hash = Value(hash),
       vec = Value(vec);
  static Insertable<EmbeddingRow> custom({
    Expression<String>? stickyId,
    Expression<String>? hash,
    Expression<String>? vec,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (stickyId != null) 'sticky_id': stickyId,
      if (hash != null) 'hash': hash,
      if (vec != null) 'vec': vec,
      if (rowid != null) 'rowid': rowid,
    });
  }

  EmbeddingsCompanion copyWith({
    Value<String>? stickyId,
    Value<String>? hash,
    Value<String>? vec,
    Value<int>? rowid,
  }) {
    return EmbeddingsCompanion(
      stickyId: stickyId ?? this.stickyId,
      hash: hash ?? this.hash,
      vec: vec ?? this.vec,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (stickyId.present) {
      map['sticky_id'] = Variable<String>(stickyId.value);
    }
    if (hash.present) {
      map['hash'] = Variable<String>(hash.value);
    }
    if (vec.present) {
      map['vec'] = Variable<String>(vec.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EmbeddingsCompanion(')
          ..write('stickyId: $stickyId, ')
          ..write('hash: $hash, ')
          ..write('vec: $vec, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SuggestionDismissalsTable extends SuggestionDismissals
    with TableInfo<$SuggestionDismissalsTable, SuggestionDismissalRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SuggestionDismissalsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _aIdMeta = const VerificationMeta('aId');
  @override
  late final GeneratedColumn<String> aId = GeneratedColumn<String>(
    'a_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bIdMeta = const VerificationMeta('bId');
  @override
  late final GeneratedColumn<String> bId = GeneratedColumn<String>(
    'b_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _aHashMeta = const VerificationMeta('aHash');
  @override
  late final GeneratedColumn<String> aHash = GeneratedColumn<String>(
    'a_hash',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bHashMeta = const VerificationMeta('bHash');
  @override
  late final GeneratedColumn<String> bHash = GeneratedColumn<String>(
    'b_hash',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [aId, bId, aHash, bHash, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'suggestion_dismissals';
  @override
  VerificationContext validateIntegrity(
    Insertable<SuggestionDismissalRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('a_id')) {
      context.handle(
        _aIdMeta,
        aId.isAcceptableOrUnknown(data['a_id']!, _aIdMeta),
      );
    } else if (isInserting) {
      context.missing(_aIdMeta);
    }
    if (data.containsKey('b_id')) {
      context.handle(
        _bIdMeta,
        bId.isAcceptableOrUnknown(data['b_id']!, _bIdMeta),
      );
    } else if (isInserting) {
      context.missing(_bIdMeta);
    }
    if (data.containsKey('a_hash')) {
      context.handle(
        _aHashMeta,
        aHash.isAcceptableOrUnknown(data['a_hash']!, _aHashMeta),
      );
    } else if (isInserting) {
      context.missing(_aHashMeta);
    }
    if (data.containsKey('b_hash')) {
      context.handle(
        _bHashMeta,
        bHash.isAcceptableOrUnknown(data['b_hash']!, _bHashMeta),
      );
    } else if (isInserting) {
      context.missing(_bHashMeta);
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
  Set<GeneratedColumn> get $primaryKey => {aId, bId};
  @override
  SuggestionDismissalRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SuggestionDismissalRow(
      aId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}a_id'],
      )!,
      bId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}b_id'],
      )!,
      aHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}a_hash'],
      )!,
      bHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}b_hash'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $SuggestionDismissalsTable createAlias(String alias) {
    return $SuggestionDismissalsTable(attachedDatabase, alias);
  }
}

class SuggestionDismissalRow extends DataClass
    implements Insertable<SuggestionDismissalRow> {
  final String aId;
  final String bId;
  final String aHash;
  final String bHash;
  final int createdAt;
  const SuggestionDismissalRow({
    required this.aId,
    required this.bId,
    required this.aHash,
    required this.bHash,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['a_id'] = Variable<String>(aId);
    map['b_id'] = Variable<String>(bId);
    map['a_hash'] = Variable<String>(aHash);
    map['b_hash'] = Variable<String>(bHash);
    map['created_at'] = Variable<int>(createdAt);
    return map;
  }

  SuggestionDismissalsCompanion toCompanion(bool nullToAbsent) {
    return SuggestionDismissalsCompanion(
      aId: Value(aId),
      bId: Value(bId),
      aHash: Value(aHash),
      bHash: Value(bHash),
      createdAt: Value(createdAt),
    );
  }

  factory SuggestionDismissalRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SuggestionDismissalRow(
      aId: serializer.fromJson<String>(json['aId']),
      bId: serializer.fromJson<String>(json['bId']),
      aHash: serializer.fromJson<String>(json['aHash']),
      bHash: serializer.fromJson<String>(json['bHash']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'aId': serializer.toJson<String>(aId),
      'bId': serializer.toJson<String>(bId),
      'aHash': serializer.toJson<String>(aHash),
      'bHash': serializer.toJson<String>(bHash),
      'createdAt': serializer.toJson<int>(createdAt),
    };
  }

  SuggestionDismissalRow copyWith({
    String? aId,
    String? bId,
    String? aHash,
    String? bHash,
    int? createdAt,
  }) => SuggestionDismissalRow(
    aId: aId ?? this.aId,
    bId: bId ?? this.bId,
    aHash: aHash ?? this.aHash,
    bHash: bHash ?? this.bHash,
    createdAt: createdAt ?? this.createdAt,
  );
  SuggestionDismissalRow copyWithCompanion(SuggestionDismissalsCompanion data) {
    return SuggestionDismissalRow(
      aId: data.aId.present ? data.aId.value : this.aId,
      bId: data.bId.present ? data.bId.value : this.bId,
      aHash: data.aHash.present ? data.aHash.value : this.aHash,
      bHash: data.bHash.present ? data.bHash.value : this.bHash,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SuggestionDismissalRow(')
          ..write('aId: $aId, ')
          ..write('bId: $bId, ')
          ..write('aHash: $aHash, ')
          ..write('bHash: $bHash, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(aId, bId, aHash, bHash, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SuggestionDismissalRow &&
          other.aId == this.aId &&
          other.bId == this.bId &&
          other.aHash == this.aHash &&
          other.bHash == this.bHash &&
          other.createdAt == this.createdAt);
}

class SuggestionDismissalsCompanion
    extends UpdateCompanion<SuggestionDismissalRow> {
  final Value<String> aId;
  final Value<String> bId;
  final Value<String> aHash;
  final Value<String> bHash;
  final Value<int> createdAt;
  final Value<int> rowid;
  const SuggestionDismissalsCompanion({
    this.aId = const Value.absent(),
    this.bId = const Value.absent(),
    this.aHash = const Value.absent(),
    this.bHash = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SuggestionDismissalsCompanion.insert({
    required String aId,
    required String bId,
    required String aHash,
    required String bHash,
    required int createdAt,
    this.rowid = const Value.absent(),
  }) : aId = Value(aId),
       bId = Value(bId),
       aHash = Value(aHash),
       bHash = Value(bHash),
       createdAt = Value(createdAt);
  static Insertable<SuggestionDismissalRow> custom({
    Expression<String>? aId,
    Expression<String>? bId,
    Expression<String>? aHash,
    Expression<String>? bHash,
    Expression<int>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (aId != null) 'a_id': aId,
      if (bId != null) 'b_id': bId,
      if (aHash != null) 'a_hash': aHash,
      if (bHash != null) 'b_hash': bHash,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SuggestionDismissalsCompanion copyWith({
    Value<String>? aId,
    Value<String>? bId,
    Value<String>? aHash,
    Value<String>? bHash,
    Value<int>? createdAt,
    Value<int>? rowid,
  }) {
    return SuggestionDismissalsCompanion(
      aId: aId ?? this.aId,
      bId: bId ?? this.bId,
      aHash: aHash ?? this.aHash,
      bHash: bHash ?? this.bHash,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (aId.present) {
      map['a_id'] = Variable<String>(aId.value);
    }
    if (bId.present) {
      map['b_id'] = Variable<String>(bId.value);
    }
    if (aHash.present) {
      map['a_hash'] = Variable<String>(aHash.value);
    }
    if (bHash.present) {
      map['b_hash'] = Variable<String>(bHash.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SuggestionDismissalsCompanion(')
          ..write('aId: $aId, ')
          ..write('bId: $bId, ')
          ..write('aHash: $aHash, ')
          ..write('bHash: $bHash, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ImportOriginsTable extends ImportOrigins
    with TableInfo<$ImportOriginsTable, ImportOriginRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ImportOriginsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _sourceKeyMeta = const VerificationMeta(
    'sourceKey',
  );
  @override
  late final GeneratedColumn<String> sourceKey = GeneratedColumn<String>(
    'source_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _stickyIdMeta = const VerificationMeta(
    'stickyId',
  );
  @override
  late final GeneratedColumn<String> stickyId = GeneratedColumn<String>(
    'sticky_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceHashMeta = const VerificationMeta(
    'sourceHash',
  );
  @override
  late final GeneratedColumn<String> sourceHash = GeneratedColumn<String>(
    'source_hash',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _stickyHashMeta = const VerificationMeta(
    'stickyHash',
  );
  @override
  late final GeneratedColumn<String> stickyHash = GeneratedColumn<String>(
    'sticky_hash',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _importedAtMeta = const VerificationMeta(
    'importedAt',
  );
  @override
  late final GeneratedColumn<int> importedAt = GeneratedColumn<int>(
    'imported_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    sourceKey,
    stickyId,
    sourceHash,
    stickyHash,
    importedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'import_origins';
  @override
  VerificationContext validateIntegrity(
    Insertable<ImportOriginRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('source_key')) {
      context.handle(
        _sourceKeyMeta,
        sourceKey.isAcceptableOrUnknown(data['source_key']!, _sourceKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceKeyMeta);
    }
    if (data.containsKey('sticky_id')) {
      context.handle(
        _stickyIdMeta,
        stickyId.isAcceptableOrUnknown(data['sticky_id']!, _stickyIdMeta),
      );
    } else if (isInserting) {
      context.missing(_stickyIdMeta);
    }
    if (data.containsKey('source_hash')) {
      context.handle(
        _sourceHashMeta,
        sourceHash.isAcceptableOrUnknown(data['source_hash']!, _sourceHashMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceHashMeta);
    }
    if (data.containsKey('sticky_hash')) {
      context.handle(
        _stickyHashMeta,
        stickyHash.isAcceptableOrUnknown(data['sticky_hash']!, _stickyHashMeta),
      );
    } else if (isInserting) {
      context.missing(_stickyHashMeta);
    }
    if (data.containsKey('imported_at')) {
      context.handle(
        _importedAtMeta,
        importedAt.isAcceptableOrUnknown(data['imported_at']!, _importedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_importedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {sourceKey};
  @override
  ImportOriginRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ImportOriginRow(
      sourceKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_key'],
      )!,
      stickyId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sticky_id'],
      )!,
      sourceHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_hash'],
      )!,
      stickyHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sticky_hash'],
      )!,
      importedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}imported_at'],
      )!,
    );
  }

  @override
  $ImportOriginsTable createAlias(String alias) {
    return $ImportOriginsTable(attachedDatabase, alias);
  }
}

class ImportOriginRow extends DataClass implements Insertable<ImportOriginRow> {
  final String sourceKey;
  final String stickyId;
  final String sourceHash;
  final String stickyHash;
  final int importedAt;
  const ImportOriginRow({
    required this.sourceKey,
    required this.stickyId,
    required this.sourceHash,
    required this.stickyHash,
    required this.importedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['source_key'] = Variable<String>(sourceKey);
    map['sticky_id'] = Variable<String>(stickyId);
    map['source_hash'] = Variable<String>(sourceHash);
    map['sticky_hash'] = Variable<String>(stickyHash);
    map['imported_at'] = Variable<int>(importedAt);
    return map;
  }

  ImportOriginsCompanion toCompanion(bool nullToAbsent) {
    return ImportOriginsCompanion(
      sourceKey: Value(sourceKey),
      stickyId: Value(stickyId),
      sourceHash: Value(sourceHash),
      stickyHash: Value(stickyHash),
      importedAt: Value(importedAt),
    );
  }

  factory ImportOriginRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ImportOriginRow(
      sourceKey: serializer.fromJson<String>(json['sourceKey']),
      stickyId: serializer.fromJson<String>(json['stickyId']),
      sourceHash: serializer.fromJson<String>(json['sourceHash']),
      stickyHash: serializer.fromJson<String>(json['stickyHash']),
      importedAt: serializer.fromJson<int>(json['importedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'sourceKey': serializer.toJson<String>(sourceKey),
      'stickyId': serializer.toJson<String>(stickyId),
      'sourceHash': serializer.toJson<String>(sourceHash),
      'stickyHash': serializer.toJson<String>(stickyHash),
      'importedAt': serializer.toJson<int>(importedAt),
    };
  }

  ImportOriginRow copyWith({
    String? sourceKey,
    String? stickyId,
    String? sourceHash,
    String? stickyHash,
    int? importedAt,
  }) => ImportOriginRow(
    sourceKey: sourceKey ?? this.sourceKey,
    stickyId: stickyId ?? this.stickyId,
    sourceHash: sourceHash ?? this.sourceHash,
    stickyHash: stickyHash ?? this.stickyHash,
    importedAt: importedAt ?? this.importedAt,
  );
  ImportOriginRow copyWithCompanion(ImportOriginsCompanion data) {
    return ImportOriginRow(
      sourceKey: data.sourceKey.present ? data.sourceKey.value : this.sourceKey,
      stickyId: data.stickyId.present ? data.stickyId.value : this.stickyId,
      sourceHash: data.sourceHash.present
          ? data.sourceHash.value
          : this.sourceHash,
      stickyHash: data.stickyHash.present
          ? data.stickyHash.value
          : this.stickyHash,
      importedAt: data.importedAt.present
          ? data.importedAt.value
          : this.importedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ImportOriginRow(')
          ..write('sourceKey: $sourceKey, ')
          ..write('stickyId: $stickyId, ')
          ..write('sourceHash: $sourceHash, ')
          ..write('stickyHash: $stickyHash, ')
          ..write('importedAt: $importedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(sourceKey, stickyId, sourceHash, stickyHash, importedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ImportOriginRow &&
          other.sourceKey == this.sourceKey &&
          other.stickyId == this.stickyId &&
          other.sourceHash == this.sourceHash &&
          other.stickyHash == this.stickyHash &&
          other.importedAt == this.importedAt);
}

class ImportOriginsCompanion extends UpdateCompanion<ImportOriginRow> {
  final Value<String> sourceKey;
  final Value<String> stickyId;
  final Value<String> sourceHash;
  final Value<String> stickyHash;
  final Value<int> importedAt;
  final Value<int> rowid;
  const ImportOriginsCompanion({
    this.sourceKey = const Value.absent(),
    this.stickyId = const Value.absent(),
    this.sourceHash = const Value.absent(),
    this.stickyHash = const Value.absent(),
    this.importedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ImportOriginsCompanion.insert({
    required String sourceKey,
    required String stickyId,
    required String sourceHash,
    required String stickyHash,
    required int importedAt,
    this.rowid = const Value.absent(),
  }) : sourceKey = Value(sourceKey),
       stickyId = Value(stickyId),
       sourceHash = Value(sourceHash),
       stickyHash = Value(stickyHash),
       importedAt = Value(importedAt);
  static Insertable<ImportOriginRow> custom({
    Expression<String>? sourceKey,
    Expression<String>? stickyId,
    Expression<String>? sourceHash,
    Expression<String>? stickyHash,
    Expression<int>? importedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (sourceKey != null) 'source_key': sourceKey,
      if (stickyId != null) 'sticky_id': stickyId,
      if (sourceHash != null) 'source_hash': sourceHash,
      if (stickyHash != null) 'sticky_hash': stickyHash,
      if (importedAt != null) 'imported_at': importedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ImportOriginsCompanion copyWith({
    Value<String>? sourceKey,
    Value<String>? stickyId,
    Value<String>? sourceHash,
    Value<String>? stickyHash,
    Value<int>? importedAt,
    Value<int>? rowid,
  }) {
    return ImportOriginsCompanion(
      sourceKey: sourceKey ?? this.sourceKey,
      stickyId: stickyId ?? this.stickyId,
      sourceHash: sourceHash ?? this.sourceHash,
      stickyHash: stickyHash ?? this.stickyHash,
      importedAt: importedAt ?? this.importedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (sourceKey.present) {
      map['source_key'] = Variable<String>(sourceKey.value);
    }
    if (stickyId.present) {
      map['sticky_id'] = Variable<String>(stickyId.value);
    }
    if (sourceHash.present) {
      map['source_hash'] = Variable<String>(sourceHash.value);
    }
    if (stickyHash.present) {
      map['sticky_hash'] = Variable<String>(stickyHash.value);
    }
    if (importedAt.present) {
      map['imported_at'] = Variable<int>(importedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ImportOriginsCompanion(')
          ..write('sourceKey: $sourceKey, ')
          ..write('stickyId: $stickyId, ')
          ..write('sourceHash: $sourceHash, ')
          ..write('stickyHash: $stickyHash, ')
          ..write('importedAt: $importedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $StickiesTable stickies = $StickiesTable(this);
  late final $LinksTable links = $LinksTable(this);
  late final $EmbeddingsTable embeddings = $EmbeddingsTable(this);
  late final $SuggestionDismissalsTable suggestionDismissals =
      $SuggestionDismissalsTable(this);
  late final $ImportOriginsTable importOrigins = $ImportOriginsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    stickies,
    links,
    embeddings,
    suggestionDismissals,
    importOrigins,
  ];
}

typedef $$StickiesTableCreateCompanionBuilder =
    StickiesCompanion Function({
      required String id,
      required int colorIndex,
      required double x,
      required double y,
      Value<bool> collapsed,
      Value<bool> pinned,
      Value<bool> open,
      Value<int?> remindAt,
      required String blocksJson,
      required int createdAt,
      required int updatedAt,
      Value<int?> deletedAt,
      Value<int> rowid,
    });
typedef $$StickiesTableUpdateCompanionBuilder =
    StickiesCompanion Function({
      Value<String> id,
      Value<int> colorIndex,
      Value<double> x,
      Value<double> y,
      Value<bool> collapsed,
      Value<bool> pinned,
      Value<bool> open,
      Value<int?> remindAt,
      Value<String> blocksJson,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<int?> deletedAt,
      Value<int> rowid,
    });

class $$StickiesTableFilterComposer
    extends Composer<_$AppDatabase, $StickiesTable> {
  $$StickiesTableFilterComposer({
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

  ColumnFilters<int> get colorIndex => $composableBuilder(
    column: $table.colorIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get x => $composableBuilder(
    column: $table.x,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get y => $composableBuilder(
    column: $table.y,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get collapsed => $composableBuilder(
    column: $table.collapsed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get pinned => $composableBuilder(
    column: $table.pinned,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get open => $composableBuilder(
    column: $table.open,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get remindAt => $composableBuilder(
    column: $table.remindAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get blocksJson => $composableBuilder(
    column: $table.blocksJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$StickiesTableOrderingComposer
    extends Composer<_$AppDatabase, $StickiesTable> {
  $$StickiesTableOrderingComposer({
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

  ColumnOrderings<int> get colorIndex => $composableBuilder(
    column: $table.colorIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get x => $composableBuilder(
    column: $table.x,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get y => $composableBuilder(
    column: $table.y,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get collapsed => $composableBuilder(
    column: $table.collapsed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get pinned => $composableBuilder(
    column: $table.pinned,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get open => $composableBuilder(
    column: $table.open,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get remindAt => $composableBuilder(
    column: $table.remindAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get blocksJson => $composableBuilder(
    column: $table.blocksJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$StickiesTableAnnotationComposer
    extends Composer<_$AppDatabase, $StickiesTable> {
  $$StickiesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get colorIndex => $composableBuilder(
    column: $table.colorIndex,
    builder: (column) => column,
  );

  GeneratedColumn<double> get x =>
      $composableBuilder(column: $table.x, builder: (column) => column);

  GeneratedColumn<double> get y =>
      $composableBuilder(column: $table.y, builder: (column) => column);

  GeneratedColumn<bool> get collapsed =>
      $composableBuilder(column: $table.collapsed, builder: (column) => column);

  GeneratedColumn<bool> get pinned =>
      $composableBuilder(column: $table.pinned, builder: (column) => column);

  GeneratedColumn<bool> get open =>
      $composableBuilder(column: $table.open, builder: (column) => column);

  GeneratedColumn<int> get remindAt =>
      $composableBuilder(column: $table.remindAt, builder: (column) => column);

  GeneratedColumn<String> get blocksJson => $composableBuilder(
    column: $table.blocksJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$StickiesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $StickiesTable,
          StickyRow,
          $$StickiesTableFilterComposer,
          $$StickiesTableOrderingComposer,
          $$StickiesTableAnnotationComposer,
          $$StickiesTableCreateCompanionBuilder,
          $$StickiesTableUpdateCompanionBuilder,
          (StickyRow, BaseReferences<_$AppDatabase, $StickiesTable, StickyRow>),
          StickyRow,
          PrefetchHooks Function()
        > {
  $$StickiesTableTableManager(_$AppDatabase db, $StickiesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$StickiesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$StickiesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$StickiesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> colorIndex = const Value.absent(),
                Value<double> x = const Value.absent(),
                Value<double> y = const Value.absent(),
                Value<bool> collapsed = const Value.absent(),
                Value<bool> pinned = const Value.absent(),
                Value<bool> open = const Value.absent(),
                Value<int?> remindAt = const Value.absent(),
                Value<String> blocksJson = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StickiesCompanion(
                id: id,
                colorIndex: colorIndex,
                x: x,
                y: y,
                collapsed: collapsed,
                pinned: pinned,
                open: open,
                remindAt: remindAt,
                blocksJson: blocksJson,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required int colorIndex,
                required double x,
                required double y,
                Value<bool> collapsed = const Value.absent(),
                Value<bool> pinned = const Value.absent(),
                Value<bool> open = const Value.absent(),
                Value<int?> remindAt = const Value.absent(),
                required String blocksJson,
                required int createdAt,
                required int updatedAt,
                Value<int?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StickiesCompanion.insert(
                id: id,
                colorIndex: colorIndex,
                x: x,
                y: y,
                collapsed: collapsed,
                pinned: pinned,
                open: open,
                remindAt: remindAt,
                blocksJson: blocksJson,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$StickiesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $StickiesTable,
      StickyRow,
      $$StickiesTableFilterComposer,
      $$StickiesTableOrderingComposer,
      $$StickiesTableAnnotationComposer,
      $$StickiesTableCreateCompanionBuilder,
      $$StickiesTableUpdateCompanionBuilder,
      (StickyRow, BaseReferences<_$AppDatabase, $StickiesTable, StickyRow>),
      StickyRow,
      PrefetchHooks Function()
    >;
typedef $$LinksTableCreateCompanionBuilder =
    LinksCompanion Function({
      required String id,
      required String aId,
      required String bId,
      required int createdAt,
      Value<int?> deletedAt,
      Value<int> rowid,
    });
typedef $$LinksTableUpdateCompanionBuilder =
    LinksCompanion Function({
      Value<String> id,
      Value<String> aId,
      Value<String> bId,
      Value<int> createdAt,
      Value<int?> deletedAt,
      Value<int> rowid,
    });

class $$LinksTableFilterComposer extends Composer<_$AppDatabase, $LinksTable> {
  $$LinksTableFilterComposer({
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

  ColumnFilters<String> get aId => $composableBuilder(
    column: $table.aId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bId => $composableBuilder(
    column: $table.bId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LinksTableOrderingComposer
    extends Composer<_$AppDatabase, $LinksTable> {
  $$LinksTableOrderingComposer({
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

  ColumnOrderings<String> get aId => $composableBuilder(
    column: $table.aId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bId => $composableBuilder(
    column: $table.bId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LinksTableAnnotationComposer
    extends Composer<_$AppDatabase, $LinksTable> {
  $$LinksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get aId =>
      $composableBuilder(column: $table.aId, builder: (column) => column);

  GeneratedColumn<String> get bId =>
      $composableBuilder(column: $table.bId, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$LinksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LinksTable,
          LinkRow,
          $$LinksTableFilterComposer,
          $$LinksTableOrderingComposer,
          $$LinksTableAnnotationComposer,
          $$LinksTableCreateCompanionBuilder,
          $$LinksTableUpdateCompanionBuilder,
          (LinkRow, BaseReferences<_$AppDatabase, $LinksTable, LinkRow>),
          LinkRow,
          PrefetchHooks Function()
        > {
  $$LinksTableTableManager(_$AppDatabase db, $LinksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LinksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LinksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LinksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> aId = const Value.absent(),
                Value<String> bId = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LinksCompanion(
                id: id,
                aId: aId,
                bId: bId,
                createdAt: createdAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String aId,
                required String bId,
                required int createdAt,
                Value<int?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LinksCompanion.insert(
                id: id,
                aId: aId,
                bId: bId,
                createdAt: createdAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LinksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LinksTable,
      LinkRow,
      $$LinksTableFilterComposer,
      $$LinksTableOrderingComposer,
      $$LinksTableAnnotationComposer,
      $$LinksTableCreateCompanionBuilder,
      $$LinksTableUpdateCompanionBuilder,
      (LinkRow, BaseReferences<_$AppDatabase, $LinksTable, LinkRow>),
      LinkRow,
      PrefetchHooks Function()
    >;
typedef $$EmbeddingsTableCreateCompanionBuilder =
    EmbeddingsCompanion Function({
      required String stickyId,
      required String hash,
      required String vec,
      Value<int> rowid,
    });
typedef $$EmbeddingsTableUpdateCompanionBuilder =
    EmbeddingsCompanion Function({
      Value<String> stickyId,
      Value<String> hash,
      Value<String> vec,
      Value<int> rowid,
    });

class $$EmbeddingsTableFilterComposer
    extends Composer<_$AppDatabase, $EmbeddingsTable> {
  $$EmbeddingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get stickyId => $composableBuilder(
    column: $table.stickyId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get hash => $composableBuilder(
    column: $table.hash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get vec => $composableBuilder(
    column: $table.vec,
    builder: (column) => ColumnFilters(column),
  );
}

class $$EmbeddingsTableOrderingComposer
    extends Composer<_$AppDatabase, $EmbeddingsTable> {
  $$EmbeddingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get stickyId => $composableBuilder(
    column: $table.stickyId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get hash => $composableBuilder(
    column: $table.hash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get vec => $composableBuilder(
    column: $table.vec,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$EmbeddingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $EmbeddingsTable> {
  $$EmbeddingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get stickyId =>
      $composableBuilder(column: $table.stickyId, builder: (column) => column);

  GeneratedColumn<String> get hash =>
      $composableBuilder(column: $table.hash, builder: (column) => column);

  GeneratedColumn<String> get vec =>
      $composableBuilder(column: $table.vec, builder: (column) => column);
}

class $$EmbeddingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $EmbeddingsTable,
          EmbeddingRow,
          $$EmbeddingsTableFilterComposer,
          $$EmbeddingsTableOrderingComposer,
          $$EmbeddingsTableAnnotationComposer,
          $$EmbeddingsTableCreateCompanionBuilder,
          $$EmbeddingsTableUpdateCompanionBuilder,
          (
            EmbeddingRow,
            BaseReferences<_$AppDatabase, $EmbeddingsTable, EmbeddingRow>,
          ),
          EmbeddingRow,
          PrefetchHooks Function()
        > {
  $$EmbeddingsTableTableManager(_$AppDatabase db, $EmbeddingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EmbeddingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EmbeddingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EmbeddingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> stickyId = const Value.absent(),
                Value<String> hash = const Value.absent(),
                Value<String> vec = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EmbeddingsCompanion(
                stickyId: stickyId,
                hash: hash,
                vec: vec,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String stickyId,
                required String hash,
                required String vec,
                Value<int> rowid = const Value.absent(),
              }) => EmbeddingsCompanion.insert(
                stickyId: stickyId,
                hash: hash,
                vec: vec,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$EmbeddingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $EmbeddingsTable,
      EmbeddingRow,
      $$EmbeddingsTableFilterComposer,
      $$EmbeddingsTableOrderingComposer,
      $$EmbeddingsTableAnnotationComposer,
      $$EmbeddingsTableCreateCompanionBuilder,
      $$EmbeddingsTableUpdateCompanionBuilder,
      (
        EmbeddingRow,
        BaseReferences<_$AppDatabase, $EmbeddingsTable, EmbeddingRow>,
      ),
      EmbeddingRow,
      PrefetchHooks Function()
    >;
typedef $$SuggestionDismissalsTableCreateCompanionBuilder =
    SuggestionDismissalsCompanion Function({
      required String aId,
      required String bId,
      required String aHash,
      required String bHash,
      required int createdAt,
      Value<int> rowid,
    });
typedef $$SuggestionDismissalsTableUpdateCompanionBuilder =
    SuggestionDismissalsCompanion Function({
      Value<String> aId,
      Value<String> bId,
      Value<String> aHash,
      Value<String> bHash,
      Value<int> createdAt,
      Value<int> rowid,
    });

class $$SuggestionDismissalsTableFilterComposer
    extends Composer<_$AppDatabase, $SuggestionDismissalsTable> {
  $$SuggestionDismissalsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get aId => $composableBuilder(
    column: $table.aId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bId => $composableBuilder(
    column: $table.bId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get aHash => $composableBuilder(
    column: $table.aHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bHash => $composableBuilder(
    column: $table.bHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SuggestionDismissalsTableOrderingComposer
    extends Composer<_$AppDatabase, $SuggestionDismissalsTable> {
  $$SuggestionDismissalsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get aId => $composableBuilder(
    column: $table.aId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bId => $composableBuilder(
    column: $table.bId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get aHash => $composableBuilder(
    column: $table.aHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bHash => $composableBuilder(
    column: $table.bHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SuggestionDismissalsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SuggestionDismissalsTable> {
  $$SuggestionDismissalsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get aId =>
      $composableBuilder(column: $table.aId, builder: (column) => column);

  GeneratedColumn<String> get bId =>
      $composableBuilder(column: $table.bId, builder: (column) => column);

  GeneratedColumn<String> get aHash =>
      $composableBuilder(column: $table.aHash, builder: (column) => column);

  GeneratedColumn<String> get bHash =>
      $composableBuilder(column: $table.bHash, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$SuggestionDismissalsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SuggestionDismissalsTable,
          SuggestionDismissalRow,
          $$SuggestionDismissalsTableFilterComposer,
          $$SuggestionDismissalsTableOrderingComposer,
          $$SuggestionDismissalsTableAnnotationComposer,
          $$SuggestionDismissalsTableCreateCompanionBuilder,
          $$SuggestionDismissalsTableUpdateCompanionBuilder,
          (
            SuggestionDismissalRow,
            BaseReferences<
              _$AppDatabase,
              $SuggestionDismissalsTable,
              SuggestionDismissalRow
            >,
          ),
          SuggestionDismissalRow,
          PrefetchHooks Function()
        > {
  $$SuggestionDismissalsTableTableManager(
    _$AppDatabase db,
    $SuggestionDismissalsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SuggestionDismissalsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SuggestionDismissalsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$SuggestionDismissalsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> aId = const Value.absent(),
                Value<String> bId = const Value.absent(),
                Value<String> aHash = const Value.absent(),
                Value<String> bHash = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SuggestionDismissalsCompanion(
                aId: aId,
                bId: bId,
                aHash: aHash,
                bHash: bHash,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String aId,
                required String bId,
                required String aHash,
                required String bHash,
                required int createdAt,
                Value<int> rowid = const Value.absent(),
              }) => SuggestionDismissalsCompanion.insert(
                aId: aId,
                bId: bId,
                aHash: aHash,
                bHash: bHash,
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

typedef $$SuggestionDismissalsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SuggestionDismissalsTable,
      SuggestionDismissalRow,
      $$SuggestionDismissalsTableFilterComposer,
      $$SuggestionDismissalsTableOrderingComposer,
      $$SuggestionDismissalsTableAnnotationComposer,
      $$SuggestionDismissalsTableCreateCompanionBuilder,
      $$SuggestionDismissalsTableUpdateCompanionBuilder,
      (
        SuggestionDismissalRow,
        BaseReferences<
          _$AppDatabase,
          $SuggestionDismissalsTable,
          SuggestionDismissalRow
        >,
      ),
      SuggestionDismissalRow,
      PrefetchHooks Function()
    >;
typedef $$ImportOriginsTableCreateCompanionBuilder =
    ImportOriginsCompanion Function({
      required String sourceKey,
      required String stickyId,
      required String sourceHash,
      required String stickyHash,
      required int importedAt,
      Value<int> rowid,
    });
typedef $$ImportOriginsTableUpdateCompanionBuilder =
    ImportOriginsCompanion Function({
      Value<String> sourceKey,
      Value<String> stickyId,
      Value<String> sourceHash,
      Value<String> stickyHash,
      Value<int> importedAt,
      Value<int> rowid,
    });

class $$ImportOriginsTableFilterComposer
    extends Composer<_$AppDatabase, $ImportOriginsTable> {
  $$ImportOriginsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get sourceKey => $composableBuilder(
    column: $table.sourceKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get stickyId => $composableBuilder(
    column: $table.stickyId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceHash => $composableBuilder(
    column: $table.sourceHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get stickyHash => $composableBuilder(
    column: $table.stickyHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get importedAt => $composableBuilder(
    column: $table.importedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ImportOriginsTableOrderingComposer
    extends Composer<_$AppDatabase, $ImportOriginsTable> {
  $$ImportOriginsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get sourceKey => $composableBuilder(
    column: $table.sourceKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get stickyId => $composableBuilder(
    column: $table.stickyId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceHash => $composableBuilder(
    column: $table.sourceHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get stickyHash => $composableBuilder(
    column: $table.stickyHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get importedAt => $composableBuilder(
    column: $table.importedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ImportOriginsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ImportOriginsTable> {
  $$ImportOriginsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get sourceKey =>
      $composableBuilder(column: $table.sourceKey, builder: (column) => column);

  GeneratedColumn<String> get stickyId =>
      $composableBuilder(column: $table.stickyId, builder: (column) => column);

  GeneratedColumn<String> get sourceHash => $composableBuilder(
    column: $table.sourceHash,
    builder: (column) => column,
  );

  GeneratedColumn<String> get stickyHash => $composableBuilder(
    column: $table.stickyHash,
    builder: (column) => column,
  );

  GeneratedColumn<int> get importedAt => $composableBuilder(
    column: $table.importedAt,
    builder: (column) => column,
  );
}

class $$ImportOriginsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ImportOriginsTable,
          ImportOriginRow,
          $$ImportOriginsTableFilterComposer,
          $$ImportOriginsTableOrderingComposer,
          $$ImportOriginsTableAnnotationComposer,
          $$ImportOriginsTableCreateCompanionBuilder,
          $$ImportOriginsTableUpdateCompanionBuilder,
          (
            ImportOriginRow,
            BaseReferences<_$AppDatabase, $ImportOriginsTable, ImportOriginRow>,
          ),
          ImportOriginRow,
          PrefetchHooks Function()
        > {
  $$ImportOriginsTableTableManager(_$AppDatabase db, $ImportOriginsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ImportOriginsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ImportOriginsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ImportOriginsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> sourceKey = const Value.absent(),
                Value<String> stickyId = const Value.absent(),
                Value<String> sourceHash = const Value.absent(),
                Value<String> stickyHash = const Value.absent(),
                Value<int> importedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ImportOriginsCompanion(
                sourceKey: sourceKey,
                stickyId: stickyId,
                sourceHash: sourceHash,
                stickyHash: stickyHash,
                importedAt: importedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String sourceKey,
                required String stickyId,
                required String sourceHash,
                required String stickyHash,
                required int importedAt,
                Value<int> rowid = const Value.absent(),
              }) => ImportOriginsCompanion.insert(
                sourceKey: sourceKey,
                stickyId: stickyId,
                sourceHash: sourceHash,
                stickyHash: stickyHash,
                importedAt: importedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ImportOriginsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ImportOriginsTable,
      ImportOriginRow,
      $$ImportOriginsTableFilterComposer,
      $$ImportOriginsTableOrderingComposer,
      $$ImportOriginsTableAnnotationComposer,
      $$ImportOriginsTableCreateCompanionBuilder,
      $$ImportOriginsTableUpdateCompanionBuilder,
      (
        ImportOriginRow,
        BaseReferences<_$AppDatabase, $ImportOriginsTable, ImportOriginRow>,
      ),
      ImportOriginRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$StickiesTableTableManager get stickies =>
      $$StickiesTableTableManager(_db, _db.stickies);
  $$LinksTableTableManager get links =>
      $$LinksTableTableManager(_db, _db.links);
  $$EmbeddingsTableTableManager get embeddings =>
      $$EmbeddingsTableTableManager(_db, _db.embeddings);
  $$SuggestionDismissalsTableTableManager get suggestionDismissals =>
      $$SuggestionDismissalsTableTableManager(_db, _db.suggestionDismissals);
  $$ImportOriginsTableTableManager get importOrigins =>
      $$ImportOriginsTableTableManager(_db, _db.importOrigins);
}
