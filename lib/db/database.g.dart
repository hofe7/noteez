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

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $StickiesTable stickies = $StickiesTable(this);
  late final $LinksTable links = $LinksTable(this);
  late final $EmbeddingsTable embeddings = $EmbeddingsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    stickies,
    links,
    embeddings,
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

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$StickiesTableTableManager get stickies =>
      $$StickiesTableTableManager(_db, _db.stickies);
  $$LinksTableTableManager get links =>
      $$LinksTableTableManager(_db, _db.links);
  $$EmbeddingsTableTableManager get embeddings =>
      $$EmbeddingsTableTableManager(_db, _db.embeddings);
}
