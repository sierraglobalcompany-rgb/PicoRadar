// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $VehiclesTable extends Vehicles with TableInfo<$VehiclesTable, Vehicle> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $VehiclesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _plateMeta = const VerificationMeta('plate');
  @override
  late final GeneratedColumn<String> plate = GeneratedColumn<String>(
    'plate',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 12,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nicknameMeta = const VerificationMeta(
    'nickname',
  );
  @override
  late final GeneratedColumn<String> nickname = GeneratedColumn<String>(
    'nickname',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('car'),
  );
  static const VerificationMeta _serviceTypeMeta = const VerificationMeta(
    'serviceType',
  );
  @override
  late final GeneratedColumn<String> serviceType = GeneratedColumn<String>(
    'service_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('private'),
  );
  static const VerificationMeta _subtypeMeta = const VerificationMeta(
    'subtype',
  );
  @override
  late final GeneratedColumn<String> subtype = GeneratedColumn<String>(
    'subtype',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _registrationCityMeta = const VerificationMeta(
    'registrationCity',
  );
  @override
  late final GeneratedColumn<String> registrationCity = GeneratedColumn<String>(
    'registration_city',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _brandMeta = const VerificationMeta('brand');
  @override
  late final GeneratedColumn<String> brand = GeneratedColumn<String>(
    'brand',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _modelMeta = const VerificationMeta('model');
  @override
  late final GeneratedColumn<String> model = GeneratedColumn<String>(
    'model',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _yearMeta = const VerificationMeta('year');
  @override
  late final GeneratedColumn<int> year = GeneratedColumn<int>(
    'year',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _colorMeta = const VerificationMeta('color');
  @override
  late final GeneratedColumn<String> color = GeneratedColumn<String>(
    'color',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fuelMeta = const VerificationMeta('fuel');
  @override
  late final GeneratedColumn<String> fuel = GeneratedColumn<String>(
    'fuel',
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
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
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
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    plate,
    nickname,
    kind,
    serviceType,
    subtype,
    registrationCity,
    brand,
    model,
    year,
    color,
    fuel,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'vehicles';
  @override
  VerificationContext validateIntegrity(
    Insertable<Vehicle> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('plate')) {
      context.handle(
        _plateMeta,
        plate.isAcceptableOrUnknown(data['plate']!, _plateMeta),
      );
    } else if (isInserting) {
      context.missing(_plateMeta);
    }
    if (data.containsKey('nickname')) {
      context.handle(
        _nicknameMeta,
        nickname.isAcceptableOrUnknown(data['nickname']!, _nicknameMeta),
      );
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    }
    if (data.containsKey('service_type')) {
      context.handle(
        _serviceTypeMeta,
        serviceType.isAcceptableOrUnknown(
          data['service_type']!,
          _serviceTypeMeta,
        ),
      );
    }
    if (data.containsKey('subtype')) {
      context.handle(
        _subtypeMeta,
        subtype.isAcceptableOrUnknown(data['subtype']!, _subtypeMeta),
      );
    }
    if (data.containsKey('registration_city')) {
      context.handle(
        _registrationCityMeta,
        registrationCity.isAcceptableOrUnknown(
          data['registration_city']!,
          _registrationCityMeta,
        ),
      );
    }
    if (data.containsKey('brand')) {
      context.handle(
        _brandMeta,
        brand.isAcceptableOrUnknown(data['brand']!, _brandMeta),
      );
    }
    if (data.containsKey('model')) {
      context.handle(
        _modelMeta,
        model.isAcceptableOrUnknown(data['model']!, _modelMeta),
      );
    }
    if (data.containsKey('year')) {
      context.handle(
        _yearMeta,
        year.isAcceptableOrUnknown(data['year']!, _yearMeta),
      );
    }
    if (data.containsKey('color')) {
      context.handle(
        _colorMeta,
        color.isAcceptableOrUnknown(data['color']!, _colorMeta),
      );
    }
    if (data.containsKey('fuel')) {
      context.handle(
        _fuelMeta,
        fuel.isAcceptableOrUnknown(data['fuel']!, _fuelMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Vehicle map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Vehicle(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      plate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}plate'],
      )!,
      nickname: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}nickname'],
      ),
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      serviceType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}service_type'],
      )!,
      subtype: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}subtype'],
      ),
      registrationCity: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}registration_city'],
      ),
      brand: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}brand'],
      ),
      model: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}model'],
      ),
      year: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}year'],
      ),
      color: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}color'],
      ),
      fuel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}fuel'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $VehiclesTable createAlias(String alias) {
    return $VehiclesTable(attachedDatabase, alias);
  }
}

class Vehicle extends DataClass implements Insertable<Vehicle> {
  final String id;
  final String plate;
  final String? nickname;
  final String kind;
  final String serviceType;
  final String? subtype;
  final String? registrationCity;
  final String? brand;
  final String? model;
  final int? year;
  final String? color;
  final String? fuel;
  final DateTime createdAt;
  final DateTime updatedAt;
  const Vehicle({
    required this.id,
    required this.plate,
    this.nickname,
    required this.kind,
    required this.serviceType,
    this.subtype,
    this.registrationCity,
    this.brand,
    this.model,
    this.year,
    this.color,
    this.fuel,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['plate'] = Variable<String>(plate);
    if (!nullToAbsent || nickname != null) {
      map['nickname'] = Variable<String>(nickname);
    }
    map['kind'] = Variable<String>(kind);
    map['service_type'] = Variable<String>(serviceType);
    if (!nullToAbsent || subtype != null) {
      map['subtype'] = Variable<String>(subtype);
    }
    if (!nullToAbsent || registrationCity != null) {
      map['registration_city'] = Variable<String>(registrationCity);
    }
    if (!nullToAbsent || brand != null) {
      map['brand'] = Variable<String>(brand);
    }
    if (!nullToAbsent || model != null) {
      map['model'] = Variable<String>(model);
    }
    if (!nullToAbsent || year != null) {
      map['year'] = Variable<int>(year);
    }
    if (!nullToAbsent || color != null) {
      map['color'] = Variable<String>(color);
    }
    if (!nullToAbsent || fuel != null) {
      map['fuel'] = Variable<String>(fuel);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  VehiclesCompanion toCompanion(bool nullToAbsent) {
    return VehiclesCompanion(
      id: Value(id),
      plate: Value(plate),
      nickname: nickname == null && nullToAbsent
          ? const Value.absent()
          : Value(nickname),
      kind: Value(kind),
      serviceType: Value(serviceType),
      subtype: subtype == null && nullToAbsent
          ? const Value.absent()
          : Value(subtype),
      registrationCity: registrationCity == null && nullToAbsent
          ? const Value.absent()
          : Value(registrationCity),
      brand: brand == null && nullToAbsent
          ? const Value.absent()
          : Value(brand),
      model: model == null && nullToAbsent
          ? const Value.absent()
          : Value(model),
      year: year == null && nullToAbsent ? const Value.absent() : Value(year),
      color: color == null && nullToAbsent
          ? const Value.absent()
          : Value(color),
      fuel: fuel == null && nullToAbsent ? const Value.absent() : Value(fuel),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Vehicle.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Vehicle(
      id: serializer.fromJson<String>(json['id']),
      plate: serializer.fromJson<String>(json['plate']),
      nickname: serializer.fromJson<String?>(json['nickname']),
      kind: serializer.fromJson<String>(json['kind']),
      serviceType: serializer.fromJson<String>(json['serviceType']),
      subtype: serializer.fromJson<String?>(json['subtype']),
      registrationCity: serializer.fromJson<String?>(json['registrationCity']),
      brand: serializer.fromJson<String?>(json['brand']),
      model: serializer.fromJson<String?>(json['model']),
      year: serializer.fromJson<int?>(json['year']),
      color: serializer.fromJson<String?>(json['color']),
      fuel: serializer.fromJson<String?>(json['fuel']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'plate': serializer.toJson<String>(plate),
      'nickname': serializer.toJson<String?>(nickname),
      'kind': serializer.toJson<String>(kind),
      'serviceType': serializer.toJson<String>(serviceType),
      'subtype': serializer.toJson<String?>(subtype),
      'registrationCity': serializer.toJson<String?>(registrationCity),
      'brand': serializer.toJson<String?>(brand),
      'model': serializer.toJson<String?>(model),
      'year': serializer.toJson<int?>(year),
      'color': serializer.toJson<String?>(color),
      'fuel': serializer.toJson<String?>(fuel),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Vehicle copyWith({
    String? id,
    String? plate,
    Value<String?> nickname = const Value.absent(),
    String? kind,
    String? serviceType,
    Value<String?> subtype = const Value.absent(),
    Value<String?> registrationCity = const Value.absent(),
    Value<String?> brand = const Value.absent(),
    Value<String?> model = const Value.absent(),
    Value<int?> year = const Value.absent(),
    Value<String?> color = const Value.absent(),
    Value<String?> fuel = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Vehicle(
    id: id ?? this.id,
    plate: plate ?? this.plate,
    nickname: nickname.present ? nickname.value : this.nickname,
    kind: kind ?? this.kind,
    serviceType: serviceType ?? this.serviceType,
    subtype: subtype.present ? subtype.value : this.subtype,
    registrationCity: registrationCity.present
        ? registrationCity.value
        : this.registrationCity,
    brand: brand.present ? brand.value : this.brand,
    model: model.present ? model.value : this.model,
    year: year.present ? year.value : this.year,
    color: color.present ? color.value : this.color,
    fuel: fuel.present ? fuel.value : this.fuel,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Vehicle copyWithCompanion(VehiclesCompanion data) {
    return Vehicle(
      id: data.id.present ? data.id.value : this.id,
      plate: data.plate.present ? data.plate.value : this.plate,
      nickname: data.nickname.present ? data.nickname.value : this.nickname,
      kind: data.kind.present ? data.kind.value : this.kind,
      serviceType: data.serviceType.present
          ? data.serviceType.value
          : this.serviceType,
      subtype: data.subtype.present ? data.subtype.value : this.subtype,
      registrationCity: data.registrationCity.present
          ? data.registrationCity.value
          : this.registrationCity,
      brand: data.brand.present ? data.brand.value : this.brand,
      model: data.model.present ? data.model.value : this.model,
      year: data.year.present ? data.year.value : this.year,
      color: data.color.present ? data.color.value : this.color,
      fuel: data.fuel.present ? data.fuel.value : this.fuel,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Vehicle(')
          ..write('id: $id, ')
          ..write('plate: $plate, ')
          ..write('nickname: $nickname, ')
          ..write('kind: $kind, ')
          ..write('serviceType: $serviceType, ')
          ..write('subtype: $subtype, ')
          ..write('registrationCity: $registrationCity, ')
          ..write('brand: $brand, ')
          ..write('model: $model, ')
          ..write('year: $year, ')
          ..write('color: $color, ')
          ..write('fuel: $fuel, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    plate,
    nickname,
    kind,
    serviceType,
    subtype,
    registrationCity,
    brand,
    model,
    year,
    color,
    fuel,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Vehicle &&
          other.id == this.id &&
          other.plate == this.plate &&
          other.nickname == this.nickname &&
          other.kind == this.kind &&
          other.serviceType == this.serviceType &&
          other.subtype == this.subtype &&
          other.registrationCity == this.registrationCity &&
          other.brand == this.brand &&
          other.model == this.model &&
          other.year == this.year &&
          other.color == this.color &&
          other.fuel == this.fuel &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class VehiclesCompanion extends UpdateCompanion<Vehicle> {
  final Value<String> id;
  final Value<String> plate;
  final Value<String?> nickname;
  final Value<String> kind;
  final Value<String> serviceType;
  final Value<String?> subtype;
  final Value<String?> registrationCity;
  final Value<String?> brand;
  final Value<String?> model;
  final Value<int?> year;
  final Value<String?> color;
  final Value<String?> fuel;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const VehiclesCompanion({
    this.id = const Value.absent(),
    this.plate = const Value.absent(),
    this.nickname = const Value.absent(),
    this.kind = const Value.absent(),
    this.serviceType = const Value.absent(),
    this.subtype = const Value.absent(),
    this.registrationCity = const Value.absent(),
    this.brand = const Value.absent(),
    this.model = const Value.absent(),
    this.year = const Value.absent(),
    this.color = const Value.absent(),
    this.fuel = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  VehiclesCompanion.insert({
    required String id,
    required String plate,
    this.nickname = const Value.absent(),
    this.kind = const Value.absent(),
    this.serviceType = const Value.absent(),
    this.subtype = const Value.absent(),
    this.registrationCity = const Value.absent(),
    this.brand = const Value.absent(),
    this.model = const Value.absent(),
    this.year = const Value.absent(),
    this.color = const Value.absent(),
    this.fuel = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       plate = Value(plate);
  static Insertable<Vehicle> custom({
    Expression<String>? id,
    Expression<String>? plate,
    Expression<String>? nickname,
    Expression<String>? kind,
    Expression<String>? serviceType,
    Expression<String>? subtype,
    Expression<String>? registrationCity,
    Expression<String>? brand,
    Expression<String>? model,
    Expression<int>? year,
    Expression<String>? color,
    Expression<String>? fuel,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (plate != null) 'plate': plate,
      if (nickname != null) 'nickname': nickname,
      if (kind != null) 'kind': kind,
      if (serviceType != null) 'service_type': serviceType,
      if (subtype != null) 'subtype': subtype,
      if (registrationCity != null) 'registration_city': registrationCity,
      if (brand != null) 'brand': brand,
      if (model != null) 'model': model,
      if (year != null) 'year': year,
      if (color != null) 'color': color,
      if (fuel != null) 'fuel': fuel,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  VehiclesCompanion copyWith({
    Value<String>? id,
    Value<String>? plate,
    Value<String?>? nickname,
    Value<String>? kind,
    Value<String>? serviceType,
    Value<String?>? subtype,
    Value<String?>? registrationCity,
    Value<String?>? brand,
    Value<String?>? model,
    Value<int?>? year,
    Value<String?>? color,
    Value<String?>? fuel,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return VehiclesCompanion(
      id: id ?? this.id,
      plate: plate ?? this.plate,
      nickname: nickname ?? this.nickname,
      kind: kind ?? this.kind,
      serviceType: serviceType ?? this.serviceType,
      subtype: subtype ?? this.subtype,
      registrationCity: registrationCity ?? this.registrationCity,
      brand: brand ?? this.brand,
      model: model ?? this.model,
      year: year ?? this.year,
      color: color ?? this.color,
      fuel: fuel ?? this.fuel,
      createdAt: createdAt ?? this.createdAt,
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
    if (plate.present) {
      map['plate'] = Variable<String>(plate.value);
    }
    if (nickname.present) {
      map['nickname'] = Variable<String>(nickname.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (serviceType.present) {
      map['service_type'] = Variable<String>(serviceType.value);
    }
    if (subtype.present) {
      map['subtype'] = Variable<String>(subtype.value);
    }
    if (registrationCity.present) {
      map['registration_city'] = Variable<String>(registrationCity.value);
    }
    if (brand.present) {
      map['brand'] = Variable<String>(brand.value);
    }
    if (model.present) {
      map['model'] = Variable<String>(model.value);
    }
    if (year.present) {
      map['year'] = Variable<int>(year.value);
    }
    if (color.present) {
      map['color'] = Variable<String>(color.value);
    }
    if (fuel.present) {
      map['fuel'] = Variable<String>(fuel.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
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
    return (StringBuffer('VehiclesCompanion(')
          ..write('id: $id, ')
          ..write('plate: $plate, ')
          ..write('nickname: $nickname, ')
          ..write('kind: $kind, ')
          ..write('serviceType: $serviceType, ')
          ..write('subtype: $subtype, ')
          ..write('registrationCity: $registrationCity, ')
          ..write('brand: $brand, ')
          ..write('model: $model, ')
          ..write('year: $year, ')
          ..write('color: $color, ')
          ..write('fuel: $fuel, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $VehicleObligationsTable extends VehicleObligations
    with TableInfo<$VehicleObligationsTable, VehicleObligation> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $VehicleObligationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _vehicleIdMeta = const VerificationMeta(
    'vehicleId',
  );
  @override
  late final GeneratedColumn<String> vehicleId = GeneratedColumn<String>(
    'vehicle_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES vehicles (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 32,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 32,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startDateMeta = const VerificationMeta(
    'startDate',
  );
  @override
  late final GeneratedColumn<DateTime> startDate = GeneratedColumn<DateTime>(
    'start_date',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dueDateMeta = const VerificationMeta(
    'dueDate',
  );
  @override
  late final GeneratedColumn<DateTime> dueDate = GeneratedColumn<DateTime>(
    'due_date',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _detailsJsonMeta = const VerificationMeta(
    'detailsJson',
  );
  @override
  late final GeneratedColumn<String> detailsJson = GeneratedColumn<String>(
    'details_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _reminderEnabledMeta = const VerificationMeta(
    'reminderEnabled',
  );
  @override
  late final GeneratedColumn<bool> reminderEnabled = GeneratedColumn<bool>(
    'reminder_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("reminder_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
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
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
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
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    vehicleId,
    type,
    status,
    startDate,
    dueDate,
    detailsJson,
    reminderEnabled,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'vehicle_obligations';
  @override
  VerificationContext validateIntegrity(
    Insertable<VehicleObligation> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('vehicle_id')) {
      context.handle(
        _vehicleIdMeta,
        vehicleId.isAcceptableOrUnknown(data['vehicle_id']!, _vehicleIdMeta),
      );
    } else if (isInserting) {
      context.missing(_vehicleIdMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('start_date')) {
      context.handle(
        _startDateMeta,
        startDate.isAcceptableOrUnknown(data['start_date']!, _startDateMeta),
      );
    }
    if (data.containsKey('due_date')) {
      context.handle(
        _dueDateMeta,
        dueDate.isAcceptableOrUnknown(data['due_date']!, _dueDateMeta),
      );
    }
    if (data.containsKey('details_json')) {
      context.handle(
        _detailsJsonMeta,
        detailsJson.isAcceptableOrUnknown(
          data['details_json']!,
          _detailsJsonMeta,
        ),
      );
    }
    if (data.containsKey('reminder_enabled')) {
      context.handle(
        _reminderEnabledMeta,
        reminderEnabled.isAcceptableOrUnknown(
          data['reminder_enabled']!,
          _reminderEnabledMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  VehicleObligation map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return VehicleObligation(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      vehicleId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}vehicle_id'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      startDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}start_date'],
      ),
      dueDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}due_date'],
      ),
      detailsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}details_json'],
      ),
      reminderEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}reminder_enabled'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $VehicleObligationsTable createAlias(String alias) {
    return $VehicleObligationsTable(attachedDatabase, alias);
  }
}

class VehicleObligation extends DataClass
    implements Insertable<VehicleObligation> {
  final String id;
  final String vehicleId;
  final String type;
  final String status;
  final DateTime? startDate;
  final DateTime? dueDate;
  final String? detailsJson;
  final bool reminderEnabled;
  final DateTime createdAt;
  final DateTime updatedAt;
  const VehicleObligation({
    required this.id,
    required this.vehicleId,
    required this.type,
    required this.status,
    this.startDate,
    this.dueDate,
    this.detailsJson,
    required this.reminderEnabled,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['vehicle_id'] = Variable<String>(vehicleId);
    map['type'] = Variable<String>(type);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || startDate != null) {
      map['start_date'] = Variable<DateTime>(startDate);
    }
    if (!nullToAbsent || dueDate != null) {
      map['due_date'] = Variable<DateTime>(dueDate);
    }
    if (!nullToAbsent || detailsJson != null) {
      map['details_json'] = Variable<String>(detailsJson);
    }
    map['reminder_enabled'] = Variable<bool>(reminderEnabled);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  VehicleObligationsCompanion toCompanion(bool nullToAbsent) {
    return VehicleObligationsCompanion(
      id: Value(id),
      vehicleId: Value(vehicleId),
      type: Value(type),
      status: Value(status),
      startDate: startDate == null && nullToAbsent
          ? const Value.absent()
          : Value(startDate),
      dueDate: dueDate == null && nullToAbsent
          ? const Value.absent()
          : Value(dueDate),
      detailsJson: detailsJson == null && nullToAbsent
          ? const Value.absent()
          : Value(detailsJson),
      reminderEnabled: Value(reminderEnabled),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory VehicleObligation.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return VehicleObligation(
      id: serializer.fromJson<String>(json['id']),
      vehicleId: serializer.fromJson<String>(json['vehicleId']),
      type: serializer.fromJson<String>(json['type']),
      status: serializer.fromJson<String>(json['status']),
      startDate: serializer.fromJson<DateTime?>(json['startDate']),
      dueDate: serializer.fromJson<DateTime?>(json['dueDate']),
      detailsJson: serializer.fromJson<String?>(json['detailsJson']),
      reminderEnabled: serializer.fromJson<bool>(json['reminderEnabled']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'vehicleId': serializer.toJson<String>(vehicleId),
      'type': serializer.toJson<String>(type),
      'status': serializer.toJson<String>(status),
      'startDate': serializer.toJson<DateTime?>(startDate),
      'dueDate': serializer.toJson<DateTime?>(dueDate),
      'detailsJson': serializer.toJson<String?>(detailsJson),
      'reminderEnabled': serializer.toJson<bool>(reminderEnabled),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  VehicleObligation copyWith({
    String? id,
    String? vehicleId,
    String? type,
    String? status,
    Value<DateTime?> startDate = const Value.absent(),
    Value<DateTime?> dueDate = const Value.absent(),
    Value<String?> detailsJson = const Value.absent(),
    bool? reminderEnabled,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => VehicleObligation(
    id: id ?? this.id,
    vehicleId: vehicleId ?? this.vehicleId,
    type: type ?? this.type,
    status: status ?? this.status,
    startDate: startDate.present ? startDate.value : this.startDate,
    dueDate: dueDate.present ? dueDate.value : this.dueDate,
    detailsJson: detailsJson.present ? detailsJson.value : this.detailsJson,
    reminderEnabled: reminderEnabled ?? this.reminderEnabled,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  VehicleObligation copyWithCompanion(VehicleObligationsCompanion data) {
    return VehicleObligation(
      id: data.id.present ? data.id.value : this.id,
      vehicleId: data.vehicleId.present ? data.vehicleId.value : this.vehicleId,
      type: data.type.present ? data.type.value : this.type,
      status: data.status.present ? data.status.value : this.status,
      startDate: data.startDate.present ? data.startDate.value : this.startDate,
      dueDate: data.dueDate.present ? data.dueDate.value : this.dueDate,
      detailsJson: data.detailsJson.present
          ? data.detailsJson.value
          : this.detailsJson,
      reminderEnabled: data.reminderEnabled.present
          ? data.reminderEnabled.value
          : this.reminderEnabled,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('VehicleObligation(')
          ..write('id: $id, ')
          ..write('vehicleId: $vehicleId, ')
          ..write('type: $type, ')
          ..write('status: $status, ')
          ..write('startDate: $startDate, ')
          ..write('dueDate: $dueDate, ')
          ..write('detailsJson: $detailsJson, ')
          ..write('reminderEnabled: $reminderEnabled, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    vehicleId,
    type,
    status,
    startDate,
    dueDate,
    detailsJson,
    reminderEnabled,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is VehicleObligation &&
          other.id == this.id &&
          other.vehicleId == this.vehicleId &&
          other.type == this.type &&
          other.status == this.status &&
          other.startDate == this.startDate &&
          other.dueDate == this.dueDate &&
          other.detailsJson == this.detailsJson &&
          other.reminderEnabled == this.reminderEnabled &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class VehicleObligationsCompanion extends UpdateCompanion<VehicleObligation> {
  final Value<String> id;
  final Value<String> vehicleId;
  final Value<String> type;
  final Value<String> status;
  final Value<DateTime?> startDate;
  final Value<DateTime?> dueDate;
  final Value<String?> detailsJson;
  final Value<bool> reminderEnabled;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const VehicleObligationsCompanion({
    this.id = const Value.absent(),
    this.vehicleId = const Value.absent(),
    this.type = const Value.absent(),
    this.status = const Value.absent(),
    this.startDate = const Value.absent(),
    this.dueDate = const Value.absent(),
    this.detailsJson = const Value.absent(),
    this.reminderEnabled = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  VehicleObligationsCompanion.insert({
    required String id,
    required String vehicleId,
    required String type,
    required String status,
    this.startDate = const Value.absent(),
    this.dueDate = const Value.absent(),
    this.detailsJson = const Value.absent(),
    this.reminderEnabled = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       vehicleId = Value(vehicleId),
       type = Value(type),
       status = Value(status);
  static Insertable<VehicleObligation> custom({
    Expression<String>? id,
    Expression<String>? vehicleId,
    Expression<String>? type,
    Expression<String>? status,
    Expression<DateTime>? startDate,
    Expression<DateTime>? dueDate,
    Expression<String>? detailsJson,
    Expression<bool>? reminderEnabled,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (vehicleId != null) 'vehicle_id': vehicleId,
      if (type != null) 'type': type,
      if (status != null) 'status': status,
      if (startDate != null) 'start_date': startDate,
      if (dueDate != null) 'due_date': dueDate,
      if (detailsJson != null) 'details_json': detailsJson,
      if (reminderEnabled != null) 'reminder_enabled': reminderEnabled,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  VehicleObligationsCompanion copyWith({
    Value<String>? id,
    Value<String>? vehicleId,
    Value<String>? type,
    Value<String>? status,
    Value<DateTime?>? startDate,
    Value<DateTime?>? dueDate,
    Value<String?>? detailsJson,
    Value<bool>? reminderEnabled,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return VehicleObligationsCompanion(
      id: id ?? this.id,
      vehicleId: vehicleId ?? this.vehicleId,
      type: type ?? this.type,
      status: status ?? this.status,
      startDate: startDate ?? this.startDate,
      dueDate: dueDate ?? this.dueDate,
      detailsJson: detailsJson ?? this.detailsJson,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      createdAt: createdAt ?? this.createdAt,
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
    if (vehicleId.present) {
      map['vehicle_id'] = Variable<String>(vehicleId.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (startDate.present) {
      map['start_date'] = Variable<DateTime>(startDate.value);
    }
    if (dueDate.present) {
      map['due_date'] = Variable<DateTime>(dueDate.value);
    }
    if (detailsJson.present) {
      map['details_json'] = Variable<String>(detailsJson.value);
    }
    if (reminderEnabled.present) {
      map['reminder_enabled'] = Variable<bool>(reminderEnabled.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
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
    return (StringBuffer('VehicleObligationsCompanion(')
          ..write('id: $id, ')
          ..write('vehicleId: $vehicleId, ')
          ..write('type: $type, ')
          ..write('status: $status, ')
          ..write('startDate: $startDate, ')
          ..write('dueDate: $dueDate, ')
          ..write('detailsJson: $detailsJson, ')
          ..write('reminderEnabled: $reminderEnabled, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MaintenanceRecordsTable extends MaintenanceRecords
    with TableInfo<$MaintenanceRecordsTable, MaintenanceRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MaintenanceRecordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _vehicleIdMeta = const VerificationMeta(
    'vehicleId',
  );
  @override
  late final GeneratedColumn<String> vehicleId = GeneratedColumn<String>(
    'vehicle_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES vehicles (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _serviceDateMeta = const VerificationMeta(
    'serviceDate',
  );
  @override
  late final GeneratedColumn<DateTime> serviceDate = GeneratedColumn<DateTime>(
    'service_date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _odometerMeta = const VerificationMeta(
    'odometer',
  );
  @override
  late final GeneratedColumn<int> odometer = GeneratedColumn<int>(
    'odometer',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 64,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 500,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _costCentsMeta = const VerificationMeta(
    'costCents',
  );
  @override
  late final GeneratedColumn<int> costCents = GeneratedColumn<int>(
    'cost_cents',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nextServiceDateMeta = const VerificationMeta(
    'nextServiceDate',
  );
  @override
  late final GeneratedColumn<DateTime> nextServiceDate =
      GeneratedColumn<DateTime>(
        'next_service_date',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _nextOdometerMeta = const VerificationMeta(
    'nextOdometer',
  );
  @override
  late final GeneratedColumn<int> nextOdometer = GeneratedColumn<int>(
    'next_odometer',
    aliasedName,
    true,
    type: DriftSqlType.int,
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
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
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
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    vehicleId,
    serviceDate,
    odometer,
    type,
    description,
    costCents,
    nextServiceDate,
    nextOdometer,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'maintenance_records';
  @override
  VerificationContext validateIntegrity(
    Insertable<MaintenanceRecord> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('vehicle_id')) {
      context.handle(
        _vehicleIdMeta,
        vehicleId.isAcceptableOrUnknown(data['vehicle_id']!, _vehicleIdMeta),
      );
    } else if (isInserting) {
      context.missing(_vehicleIdMeta);
    }
    if (data.containsKey('service_date')) {
      context.handle(
        _serviceDateMeta,
        serviceDate.isAcceptableOrUnknown(
          data['service_date']!,
          _serviceDateMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_serviceDateMeta);
    }
    if (data.containsKey('odometer')) {
      context.handle(
        _odometerMeta,
        odometer.isAcceptableOrUnknown(data['odometer']!, _odometerMeta),
      );
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_descriptionMeta);
    }
    if (data.containsKey('cost_cents')) {
      context.handle(
        _costCentsMeta,
        costCents.isAcceptableOrUnknown(data['cost_cents']!, _costCentsMeta),
      );
    }
    if (data.containsKey('next_service_date')) {
      context.handle(
        _nextServiceDateMeta,
        nextServiceDate.isAcceptableOrUnknown(
          data['next_service_date']!,
          _nextServiceDateMeta,
        ),
      );
    }
    if (data.containsKey('next_odometer')) {
      context.handle(
        _nextOdometerMeta,
        nextOdometer.isAcceptableOrUnknown(
          data['next_odometer']!,
          _nextOdometerMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MaintenanceRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MaintenanceRecord(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      vehicleId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}vehicle_id'],
      )!,
      serviceDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}service_date'],
      )!,
      odometer: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}odometer'],
      ),
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      )!,
      costCents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}cost_cents'],
      ),
      nextServiceDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}next_service_date'],
      ),
      nextOdometer: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}next_odometer'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $MaintenanceRecordsTable createAlias(String alias) {
    return $MaintenanceRecordsTable(attachedDatabase, alias);
  }
}

class MaintenanceRecord extends DataClass
    implements Insertable<MaintenanceRecord> {
  final String id;
  final String vehicleId;
  final DateTime serviceDate;
  final int? odometer;
  final String type;
  final String description;
  final int? costCents;
  final DateTime? nextServiceDate;
  final int? nextOdometer;
  final DateTime createdAt;
  final DateTime updatedAt;
  const MaintenanceRecord({
    required this.id,
    required this.vehicleId,
    required this.serviceDate,
    this.odometer,
    required this.type,
    required this.description,
    this.costCents,
    this.nextServiceDate,
    this.nextOdometer,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['vehicle_id'] = Variable<String>(vehicleId);
    map['service_date'] = Variable<DateTime>(serviceDate);
    if (!nullToAbsent || odometer != null) {
      map['odometer'] = Variable<int>(odometer);
    }
    map['type'] = Variable<String>(type);
    map['description'] = Variable<String>(description);
    if (!nullToAbsent || costCents != null) {
      map['cost_cents'] = Variable<int>(costCents);
    }
    if (!nullToAbsent || nextServiceDate != null) {
      map['next_service_date'] = Variable<DateTime>(nextServiceDate);
    }
    if (!nullToAbsent || nextOdometer != null) {
      map['next_odometer'] = Variable<int>(nextOdometer);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  MaintenanceRecordsCompanion toCompanion(bool nullToAbsent) {
    return MaintenanceRecordsCompanion(
      id: Value(id),
      vehicleId: Value(vehicleId),
      serviceDate: Value(serviceDate),
      odometer: odometer == null && nullToAbsent
          ? const Value.absent()
          : Value(odometer),
      type: Value(type),
      description: Value(description),
      costCents: costCents == null && nullToAbsent
          ? const Value.absent()
          : Value(costCents),
      nextServiceDate: nextServiceDate == null && nullToAbsent
          ? const Value.absent()
          : Value(nextServiceDate),
      nextOdometer: nextOdometer == null && nullToAbsent
          ? const Value.absent()
          : Value(nextOdometer),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory MaintenanceRecord.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MaintenanceRecord(
      id: serializer.fromJson<String>(json['id']),
      vehicleId: serializer.fromJson<String>(json['vehicleId']),
      serviceDate: serializer.fromJson<DateTime>(json['serviceDate']),
      odometer: serializer.fromJson<int?>(json['odometer']),
      type: serializer.fromJson<String>(json['type']),
      description: serializer.fromJson<String>(json['description']),
      costCents: serializer.fromJson<int?>(json['costCents']),
      nextServiceDate: serializer.fromJson<DateTime?>(json['nextServiceDate']),
      nextOdometer: serializer.fromJson<int?>(json['nextOdometer']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'vehicleId': serializer.toJson<String>(vehicleId),
      'serviceDate': serializer.toJson<DateTime>(serviceDate),
      'odometer': serializer.toJson<int?>(odometer),
      'type': serializer.toJson<String>(type),
      'description': serializer.toJson<String>(description),
      'costCents': serializer.toJson<int?>(costCents),
      'nextServiceDate': serializer.toJson<DateTime?>(nextServiceDate),
      'nextOdometer': serializer.toJson<int?>(nextOdometer),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  MaintenanceRecord copyWith({
    String? id,
    String? vehicleId,
    DateTime? serviceDate,
    Value<int?> odometer = const Value.absent(),
    String? type,
    String? description,
    Value<int?> costCents = const Value.absent(),
    Value<DateTime?> nextServiceDate = const Value.absent(),
    Value<int?> nextOdometer = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => MaintenanceRecord(
    id: id ?? this.id,
    vehicleId: vehicleId ?? this.vehicleId,
    serviceDate: serviceDate ?? this.serviceDate,
    odometer: odometer.present ? odometer.value : this.odometer,
    type: type ?? this.type,
    description: description ?? this.description,
    costCents: costCents.present ? costCents.value : this.costCents,
    nextServiceDate: nextServiceDate.present
        ? nextServiceDate.value
        : this.nextServiceDate,
    nextOdometer: nextOdometer.present ? nextOdometer.value : this.nextOdometer,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  MaintenanceRecord copyWithCompanion(MaintenanceRecordsCompanion data) {
    return MaintenanceRecord(
      id: data.id.present ? data.id.value : this.id,
      vehicleId: data.vehicleId.present ? data.vehicleId.value : this.vehicleId,
      serviceDate: data.serviceDate.present
          ? data.serviceDate.value
          : this.serviceDate,
      odometer: data.odometer.present ? data.odometer.value : this.odometer,
      type: data.type.present ? data.type.value : this.type,
      description: data.description.present
          ? data.description.value
          : this.description,
      costCents: data.costCents.present ? data.costCents.value : this.costCents,
      nextServiceDate: data.nextServiceDate.present
          ? data.nextServiceDate.value
          : this.nextServiceDate,
      nextOdometer: data.nextOdometer.present
          ? data.nextOdometer.value
          : this.nextOdometer,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MaintenanceRecord(')
          ..write('id: $id, ')
          ..write('vehicleId: $vehicleId, ')
          ..write('serviceDate: $serviceDate, ')
          ..write('odometer: $odometer, ')
          ..write('type: $type, ')
          ..write('description: $description, ')
          ..write('costCents: $costCents, ')
          ..write('nextServiceDate: $nextServiceDate, ')
          ..write('nextOdometer: $nextOdometer, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    vehicleId,
    serviceDate,
    odometer,
    type,
    description,
    costCents,
    nextServiceDate,
    nextOdometer,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MaintenanceRecord &&
          other.id == this.id &&
          other.vehicleId == this.vehicleId &&
          other.serviceDate == this.serviceDate &&
          other.odometer == this.odometer &&
          other.type == this.type &&
          other.description == this.description &&
          other.costCents == this.costCents &&
          other.nextServiceDate == this.nextServiceDate &&
          other.nextOdometer == this.nextOdometer &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class MaintenanceRecordsCompanion extends UpdateCompanion<MaintenanceRecord> {
  final Value<String> id;
  final Value<String> vehicleId;
  final Value<DateTime> serviceDate;
  final Value<int?> odometer;
  final Value<String> type;
  final Value<String> description;
  final Value<int?> costCents;
  final Value<DateTime?> nextServiceDate;
  final Value<int?> nextOdometer;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const MaintenanceRecordsCompanion({
    this.id = const Value.absent(),
    this.vehicleId = const Value.absent(),
    this.serviceDate = const Value.absent(),
    this.odometer = const Value.absent(),
    this.type = const Value.absent(),
    this.description = const Value.absent(),
    this.costCents = const Value.absent(),
    this.nextServiceDate = const Value.absent(),
    this.nextOdometer = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MaintenanceRecordsCompanion.insert({
    required String id,
    required String vehicleId,
    required DateTime serviceDate,
    this.odometer = const Value.absent(),
    required String type,
    required String description,
    this.costCents = const Value.absent(),
    this.nextServiceDate = const Value.absent(),
    this.nextOdometer = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       vehicleId = Value(vehicleId),
       serviceDate = Value(serviceDate),
       type = Value(type),
       description = Value(description);
  static Insertable<MaintenanceRecord> custom({
    Expression<String>? id,
    Expression<String>? vehicleId,
    Expression<DateTime>? serviceDate,
    Expression<int>? odometer,
    Expression<String>? type,
    Expression<String>? description,
    Expression<int>? costCents,
    Expression<DateTime>? nextServiceDate,
    Expression<int>? nextOdometer,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (vehicleId != null) 'vehicle_id': vehicleId,
      if (serviceDate != null) 'service_date': serviceDate,
      if (odometer != null) 'odometer': odometer,
      if (type != null) 'type': type,
      if (description != null) 'description': description,
      if (costCents != null) 'cost_cents': costCents,
      if (nextServiceDate != null) 'next_service_date': nextServiceDate,
      if (nextOdometer != null) 'next_odometer': nextOdometer,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MaintenanceRecordsCompanion copyWith({
    Value<String>? id,
    Value<String>? vehicleId,
    Value<DateTime>? serviceDate,
    Value<int?>? odometer,
    Value<String>? type,
    Value<String>? description,
    Value<int?>? costCents,
    Value<DateTime?>? nextServiceDate,
    Value<int?>? nextOdometer,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return MaintenanceRecordsCompanion(
      id: id ?? this.id,
      vehicleId: vehicleId ?? this.vehicleId,
      serviceDate: serviceDate ?? this.serviceDate,
      odometer: odometer ?? this.odometer,
      type: type ?? this.type,
      description: description ?? this.description,
      costCents: costCents ?? this.costCents,
      nextServiceDate: nextServiceDate ?? this.nextServiceDate,
      nextOdometer: nextOdometer ?? this.nextOdometer,
      createdAt: createdAt ?? this.createdAt,
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
    if (vehicleId.present) {
      map['vehicle_id'] = Variable<String>(vehicleId.value);
    }
    if (serviceDate.present) {
      map['service_date'] = Variable<DateTime>(serviceDate.value);
    }
    if (odometer.present) {
      map['odometer'] = Variable<int>(odometer.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (costCents.present) {
      map['cost_cents'] = Variable<int>(costCents.value);
    }
    if (nextServiceDate.present) {
      map['next_service_date'] = Variable<DateTime>(nextServiceDate.value);
    }
    if (nextOdometer.present) {
      map['next_odometer'] = Variable<int>(nextOdometer.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
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
    return (StringBuffer('MaintenanceRecordsCompanion(')
          ..write('id: $id, ')
          ..write('vehicleId: $vehicleId, ')
          ..write('serviceDate: $serviceDate, ')
          ..write('odometer: $odometer, ')
          ..write('type: $type, ')
          ..write('description: $description, ')
          ..write('costCents: $costCents, ')
          ..write('nextServiceDate: $nextServiceDate, ')
          ..write('nextOdometer: $nextOdometer, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $NotificationPreferencesTable extends NotificationPreferences
    with TableInfo<$NotificationPreferencesTable, NotificationPreference> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $NotificationPreferencesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _restrictionAlertsEnabledMeta =
      const VerificationMeta('restrictionAlertsEnabled');
  @override
  late final GeneratedColumn<bool> restrictionAlertsEnabled =
      GeneratedColumn<bool>(
        'restriction_alerts_enabled',
        aliasedName,
        false,
        type: DriftSqlType.bool,
        requiredDuringInsert: false,
        defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("restriction_alerts_enabled" IN (0, 1))',
        ),
        defaultValue: const Constant(true),
      );
  static const VerificationMeta _obligationRemindersEnabledMeta =
      const VerificationMeta('obligationRemindersEnabled');
  @override
  late final GeneratedColumn<bool> obligationRemindersEnabled =
      GeneratedColumn<bool>(
        'obligation_reminders_enabled',
        aliasedName,
        false,
        type: DriftSqlType.bool,
        requiredDuringInsert: false,
        defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("obligation_reminders_enabled" IN (0, 1))',
        ),
        defaultValue: const Constant(true),
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
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    restrictionAlertsEnabled,
    obligationRemindersEnabled,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'notification_preferences';
  @override
  VerificationContext validateIntegrity(
    Insertable<NotificationPreference> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('restriction_alerts_enabled')) {
      context.handle(
        _restrictionAlertsEnabledMeta,
        restrictionAlertsEnabled.isAcceptableOrUnknown(
          data['restriction_alerts_enabled']!,
          _restrictionAlertsEnabledMeta,
        ),
      );
    }
    if (data.containsKey('obligation_reminders_enabled')) {
      context.handle(
        _obligationRemindersEnabledMeta,
        obligationRemindersEnabled.isAcceptableOrUnknown(
          data['obligation_reminders_enabled']!,
          _obligationRemindersEnabledMeta,
        ),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  NotificationPreference map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return NotificationPreference(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      restrictionAlertsEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}restriction_alerts_enabled'],
      )!,
      obligationRemindersEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}obligation_reminders_enabled'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $NotificationPreferencesTable createAlias(String alias) {
    return $NotificationPreferencesTable(attachedDatabase, alias);
  }
}

class NotificationPreference extends DataClass
    implements Insertable<NotificationPreference> {
  final String id;
  final bool restrictionAlertsEnabled;
  final bool obligationRemindersEnabled;
  final DateTime updatedAt;
  const NotificationPreference({
    required this.id,
    required this.restrictionAlertsEnabled,
    required this.obligationRemindersEnabled,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['restriction_alerts_enabled'] = Variable<bool>(
      restrictionAlertsEnabled,
    );
    map['obligation_reminders_enabled'] = Variable<bool>(
      obligationRemindersEnabled,
    );
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  NotificationPreferencesCompanion toCompanion(bool nullToAbsent) {
    return NotificationPreferencesCompanion(
      id: Value(id),
      restrictionAlertsEnabled: Value(restrictionAlertsEnabled),
      obligationRemindersEnabled: Value(obligationRemindersEnabled),
      updatedAt: Value(updatedAt),
    );
  }

  factory NotificationPreference.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return NotificationPreference(
      id: serializer.fromJson<String>(json['id']),
      restrictionAlertsEnabled: serializer.fromJson<bool>(
        json['restrictionAlertsEnabled'],
      ),
      obligationRemindersEnabled: serializer.fromJson<bool>(
        json['obligationRemindersEnabled'],
      ),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'restrictionAlertsEnabled': serializer.toJson<bool>(
        restrictionAlertsEnabled,
      ),
      'obligationRemindersEnabled': serializer.toJson<bool>(
        obligationRemindersEnabled,
      ),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  NotificationPreference copyWith({
    String? id,
    bool? restrictionAlertsEnabled,
    bool? obligationRemindersEnabled,
    DateTime? updatedAt,
  }) => NotificationPreference(
    id: id ?? this.id,
    restrictionAlertsEnabled:
        restrictionAlertsEnabled ?? this.restrictionAlertsEnabled,
    obligationRemindersEnabled:
        obligationRemindersEnabled ?? this.obligationRemindersEnabled,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  NotificationPreference copyWithCompanion(
    NotificationPreferencesCompanion data,
  ) {
    return NotificationPreference(
      id: data.id.present ? data.id.value : this.id,
      restrictionAlertsEnabled: data.restrictionAlertsEnabled.present
          ? data.restrictionAlertsEnabled.value
          : this.restrictionAlertsEnabled,
      obligationRemindersEnabled: data.obligationRemindersEnabled.present
          ? data.obligationRemindersEnabled.value
          : this.obligationRemindersEnabled,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('NotificationPreference(')
          ..write('id: $id, ')
          ..write('restrictionAlertsEnabled: $restrictionAlertsEnabled, ')
          ..write('obligationRemindersEnabled: $obligationRemindersEnabled, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    restrictionAlertsEnabled,
    obligationRemindersEnabled,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is NotificationPreference &&
          other.id == this.id &&
          other.restrictionAlertsEnabled == this.restrictionAlertsEnabled &&
          other.obligationRemindersEnabled == this.obligationRemindersEnabled &&
          other.updatedAt == this.updatedAt);
}

class NotificationPreferencesCompanion
    extends UpdateCompanion<NotificationPreference> {
  final Value<String> id;
  final Value<bool> restrictionAlertsEnabled;
  final Value<bool> obligationRemindersEnabled;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const NotificationPreferencesCompanion({
    this.id = const Value.absent(),
    this.restrictionAlertsEnabled = const Value.absent(),
    this.obligationRemindersEnabled = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  NotificationPreferencesCompanion.insert({
    required String id,
    this.restrictionAlertsEnabled = const Value.absent(),
    this.obligationRemindersEnabled = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id);
  static Insertable<NotificationPreference> custom({
    Expression<String>? id,
    Expression<bool>? restrictionAlertsEnabled,
    Expression<bool>? obligationRemindersEnabled,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (restrictionAlertsEnabled != null)
        'restriction_alerts_enabled': restrictionAlertsEnabled,
      if (obligationRemindersEnabled != null)
        'obligation_reminders_enabled': obligationRemindersEnabled,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  NotificationPreferencesCompanion copyWith({
    Value<String>? id,
    Value<bool>? restrictionAlertsEnabled,
    Value<bool>? obligationRemindersEnabled,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return NotificationPreferencesCompanion(
      id: id ?? this.id,
      restrictionAlertsEnabled:
          restrictionAlertsEnabled ?? this.restrictionAlertsEnabled,
      obligationRemindersEnabled:
          obligationRemindersEnabled ?? this.obligationRemindersEnabled,
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
    if (restrictionAlertsEnabled.present) {
      map['restriction_alerts_enabled'] = Variable<bool>(
        restrictionAlertsEnabled.value,
      );
    }
    if (obligationRemindersEnabled.present) {
      map['obligation_reminders_enabled'] = Variable<bool>(
        obligationRemindersEnabled.value,
      );
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
    return (StringBuffer('NotificationPreferencesCompanion(')
          ..write('id: $id, ')
          ..write('restrictionAlertsEnabled: $restrictionAlertsEnabled, ')
          ..write('obligationRemindersEnabled: $obligationRemindersEnabled, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DatasetVersionsTable extends DatasetVersions
    with TableInfo<$DatasetVersionsTable, DatasetVersion> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DatasetVersionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _datasetKeyMeta = const VerificationMeta(
    'datasetKey',
  );
  @override
  late final GeneratedColumn<String> datasetKey = GeneratedColumn<String>(
    'dataset_key',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 64,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<String> version = GeneratedColumn<String>(
    'version',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 64,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sha256Meta = const VerificationMeta('sha256');
  @override
  late final GeneratedColumn<String> sha256 = GeneratedColumn<String>(
    'sha256',
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
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 32,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _publicationRevisionMeta =
      const VerificationMeta('publicationRevision');
  @override
  late final GeneratedColumn<int> publicationRevision = GeneratedColumn<int>(
    'publication_revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _appliedAtMeta = const VerificationMeta(
    'appliedAt',
  );
  @override
  late final GeneratedColumn<DateTime> appliedAt = GeneratedColumn<DateTime>(
    'applied_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    datasetKey,
    version,
    sha256,
    status,
    publicationRevision,
    appliedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'dataset_versions';
  @override
  VerificationContext validateIntegrity(
    Insertable<DatasetVersion> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('dataset_key')) {
      context.handle(
        _datasetKeyMeta,
        datasetKey.isAcceptableOrUnknown(data['dataset_key']!, _datasetKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_datasetKeyMeta);
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    } else if (isInserting) {
      context.missing(_versionMeta);
    }
    if (data.containsKey('sha256')) {
      context.handle(
        _sha256Meta,
        sha256.isAcceptableOrUnknown(data['sha256']!, _sha256Meta),
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
    if (data.containsKey('publication_revision')) {
      context.handle(
        _publicationRevisionMeta,
        publicationRevision.isAcceptableOrUnknown(
          data['publication_revision']!,
          _publicationRevisionMeta,
        ),
      );
    }
    if (data.containsKey('applied_at')) {
      context.handle(
        _appliedAtMeta,
        appliedAt.isAcceptableOrUnknown(data['applied_at']!, _appliedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DatasetVersion map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DatasetVersion(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      datasetKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}dataset_key'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}version'],
      )!,
      sha256: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sha256'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      publicationRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}publication_revision'],
      )!,
      appliedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}applied_at'],
      )!,
    );
  }

  @override
  $DatasetVersionsTable createAlias(String alias) {
    return $DatasetVersionsTable(attachedDatabase, alias);
  }
}

class DatasetVersion extends DataClass implements Insertable<DatasetVersion> {
  final String id;
  final String datasetKey;
  final String version;
  final String? sha256;
  final String status;
  final int publicationRevision;
  final DateTime appliedAt;
  const DatasetVersion({
    required this.id,
    required this.datasetKey,
    required this.version,
    this.sha256,
    required this.status,
    required this.publicationRevision,
    required this.appliedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['dataset_key'] = Variable<String>(datasetKey);
    map['version'] = Variable<String>(version);
    if (!nullToAbsent || sha256 != null) {
      map['sha256'] = Variable<String>(sha256);
    }
    map['status'] = Variable<String>(status);
    map['publication_revision'] = Variable<int>(publicationRevision);
    map['applied_at'] = Variable<DateTime>(appliedAt);
    return map;
  }

  DatasetVersionsCompanion toCompanion(bool nullToAbsent) {
    return DatasetVersionsCompanion(
      id: Value(id),
      datasetKey: Value(datasetKey),
      version: Value(version),
      sha256: sha256 == null && nullToAbsent
          ? const Value.absent()
          : Value(sha256),
      status: Value(status),
      publicationRevision: Value(publicationRevision),
      appliedAt: Value(appliedAt),
    );
  }

  factory DatasetVersion.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DatasetVersion(
      id: serializer.fromJson<String>(json['id']),
      datasetKey: serializer.fromJson<String>(json['datasetKey']),
      version: serializer.fromJson<String>(json['version']),
      sha256: serializer.fromJson<String?>(json['sha256']),
      status: serializer.fromJson<String>(json['status']),
      publicationRevision: serializer.fromJson<int>(
        json['publicationRevision'],
      ),
      appliedAt: serializer.fromJson<DateTime>(json['appliedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'datasetKey': serializer.toJson<String>(datasetKey),
      'version': serializer.toJson<String>(version),
      'sha256': serializer.toJson<String?>(sha256),
      'status': serializer.toJson<String>(status),
      'publicationRevision': serializer.toJson<int>(publicationRevision),
      'appliedAt': serializer.toJson<DateTime>(appliedAt),
    };
  }

  DatasetVersion copyWith({
    String? id,
    String? datasetKey,
    String? version,
    Value<String?> sha256 = const Value.absent(),
    String? status,
    int? publicationRevision,
    DateTime? appliedAt,
  }) => DatasetVersion(
    id: id ?? this.id,
    datasetKey: datasetKey ?? this.datasetKey,
    version: version ?? this.version,
    sha256: sha256.present ? sha256.value : this.sha256,
    status: status ?? this.status,
    publicationRevision: publicationRevision ?? this.publicationRevision,
    appliedAt: appliedAt ?? this.appliedAt,
  );
  DatasetVersion copyWithCompanion(DatasetVersionsCompanion data) {
    return DatasetVersion(
      id: data.id.present ? data.id.value : this.id,
      datasetKey: data.datasetKey.present
          ? data.datasetKey.value
          : this.datasetKey,
      version: data.version.present ? data.version.value : this.version,
      sha256: data.sha256.present ? data.sha256.value : this.sha256,
      status: data.status.present ? data.status.value : this.status,
      publicationRevision: data.publicationRevision.present
          ? data.publicationRevision.value
          : this.publicationRevision,
      appliedAt: data.appliedAt.present ? data.appliedAt.value : this.appliedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DatasetVersion(')
          ..write('id: $id, ')
          ..write('datasetKey: $datasetKey, ')
          ..write('version: $version, ')
          ..write('sha256: $sha256, ')
          ..write('status: $status, ')
          ..write('publicationRevision: $publicationRevision, ')
          ..write('appliedAt: $appliedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    datasetKey,
    version,
    sha256,
    status,
    publicationRevision,
    appliedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DatasetVersion &&
          other.id == this.id &&
          other.datasetKey == this.datasetKey &&
          other.version == this.version &&
          other.sha256 == this.sha256 &&
          other.status == this.status &&
          other.publicationRevision == this.publicationRevision &&
          other.appliedAt == this.appliedAt);
}

class DatasetVersionsCompanion extends UpdateCompanion<DatasetVersion> {
  final Value<String> id;
  final Value<String> datasetKey;
  final Value<String> version;
  final Value<String?> sha256;
  final Value<String> status;
  final Value<int> publicationRevision;
  final Value<DateTime> appliedAt;
  final Value<int> rowid;
  const DatasetVersionsCompanion({
    this.id = const Value.absent(),
    this.datasetKey = const Value.absent(),
    this.version = const Value.absent(),
    this.sha256 = const Value.absent(),
    this.status = const Value.absent(),
    this.publicationRevision = const Value.absent(),
    this.appliedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DatasetVersionsCompanion.insert({
    required String id,
    required String datasetKey,
    required String version,
    this.sha256 = const Value.absent(),
    required String status,
    this.publicationRevision = const Value.absent(),
    this.appliedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       datasetKey = Value(datasetKey),
       version = Value(version),
       status = Value(status);
  static Insertable<DatasetVersion> custom({
    Expression<String>? id,
    Expression<String>? datasetKey,
    Expression<String>? version,
    Expression<String>? sha256,
    Expression<String>? status,
    Expression<int>? publicationRevision,
    Expression<DateTime>? appliedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (datasetKey != null) 'dataset_key': datasetKey,
      if (version != null) 'version': version,
      if (sha256 != null) 'sha256': sha256,
      if (status != null) 'status': status,
      if (publicationRevision != null)
        'publication_revision': publicationRevision,
      if (appliedAt != null) 'applied_at': appliedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DatasetVersionsCompanion copyWith({
    Value<String>? id,
    Value<String>? datasetKey,
    Value<String>? version,
    Value<String?>? sha256,
    Value<String>? status,
    Value<int>? publicationRevision,
    Value<DateTime>? appliedAt,
    Value<int>? rowid,
  }) {
    return DatasetVersionsCompanion(
      id: id ?? this.id,
      datasetKey: datasetKey ?? this.datasetKey,
      version: version ?? this.version,
      sha256: sha256 ?? this.sha256,
      status: status ?? this.status,
      publicationRevision: publicationRevision ?? this.publicationRevision,
      appliedAt: appliedAt ?? this.appliedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (datasetKey.present) {
      map['dataset_key'] = Variable<String>(datasetKey.value);
    }
    if (version.present) {
      map['version'] = Variable<String>(version.value);
    }
    if (sha256.present) {
      map['sha256'] = Variable<String>(sha256.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (publicationRevision.present) {
      map['publication_revision'] = Variable<int>(publicationRevision.value);
    }
    if (appliedAt.present) {
      map['applied_at'] = Variable<DateTime>(appliedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DatasetVersionsCompanion(')
          ..write('id: $id, ')
          ..write('datasetKey: $datasetKey, ')
          ..write('version: $version, ')
          ..write('sha256: $sha256, ')
          ..write('status: $status, ')
          ..write('publicationRevision: $publicationRevision, ')
          ..write('appliedAt: $appliedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RestrictionCoveragesTable extends RestrictionCoverages
    with TableInfo<$RestrictionCoveragesTable, RestrictionCoverage> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RestrictionCoveragesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _jurisdictionIdMeta = const VerificationMeta(
    'jurisdictionId',
  );
  @override
  late final GeneratedColumn<String> jurisdictionId = GeneratedColumn<String>(
    'jurisdiction_id',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 64,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _jurisdictionNameMeta = const VerificationMeta(
    'jurisdictionName',
  );
  @override
  late final GeneratedColumn<String> jurisdictionName = GeneratedColumn<String>(
    'jurisdiction_name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 128,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _vehicleKindMeta = const VerificationMeta(
    'vehicleKind',
  );
  @override
  late final GeneratedColumn<String> vehicleKind = GeneratedColumn<String>(
    'vehicle_kind',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 32,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _serviceTypeMeta = const VerificationMeta(
    'serviceType',
  );
  @override
  late final GeneratedColumn<String> serviceType = GeneratedColumn<String>(
    'service_type',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 32,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rulesJsonMeta = const VerificationMeta(
    'rulesJson',
  );
  @override
  late final GeneratedColumn<String> rulesJson = GeneratedColumn<String>(
    'rules_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _verifiedAtMeta = const VerificationMeta(
    'verifiedAt',
  );
  @override
  late final GeneratedColumn<DateTime> verifiedAt = GeneratedColumn<DateTime>(
    'verified_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _staleAfterMeta = const VerificationMeta(
    'staleAfter',
  );
  @override
  late final GeneratedColumn<DateTime> staleAfter = GeneratedColumn<DateTime>(
    'stale_after',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceUrlsJsonMeta = const VerificationMeta(
    'sourceUrlsJson',
  );
  @override
  late final GeneratedColumn<String> sourceUrlsJson = GeneratedColumn<String>(
    'source_urls_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
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
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    jurisdictionId,
    jurisdictionName,
    vehicleKind,
    serviceType,
    rulesJson,
    verifiedAt,
    staleAfter,
    sourceUrlsJson,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'restriction_coverages';
  @override
  VerificationContext validateIntegrity(
    Insertable<RestrictionCoverage> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('jurisdiction_id')) {
      context.handle(
        _jurisdictionIdMeta,
        jurisdictionId.isAcceptableOrUnknown(
          data['jurisdiction_id']!,
          _jurisdictionIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_jurisdictionIdMeta);
    }
    if (data.containsKey('jurisdiction_name')) {
      context.handle(
        _jurisdictionNameMeta,
        jurisdictionName.isAcceptableOrUnknown(
          data['jurisdiction_name']!,
          _jurisdictionNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_jurisdictionNameMeta);
    }
    if (data.containsKey('vehicle_kind')) {
      context.handle(
        _vehicleKindMeta,
        vehicleKind.isAcceptableOrUnknown(
          data['vehicle_kind']!,
          _vehicleKindMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_vehicleKindMeta);
    }
    if (data.containsKey('service_type')) {
      context.handle(
        _serviceTypeMeta,
        serviceType.isAcceptableOrUnknown(
          data['service_type']!,
          _serviceTypeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_serviceTypeMeta);
    }
    if (data.containsKey('rules_json')) {
      context.handle(
        _rulesJsonMeta,
        rulesJson.isAcceptableOrUnknown(data['rules_json']!, _rulesJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_rulesJsonMeta);
    }
    if (data.containsKey('verified_at')) {
      context.handle(
        _verifiedAtMeta,
        verifiedAt.isAcceptableOrUnknown(data['verified_at']!, _verifiedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_verifiedAtMeta);
    }
    if (data.containsKey('stale_after')) {
      context.handle(
        _staleAfterMeta,
        staleAfter.isAcceptableOrUnknown(data['stale_after']!, _staleAfterMeta),
      );
    } else if (isInserting) {
      context.missing(_staleAfterMeta);
    }
    if (data.containsKey('source_urls_json')) {
      context.handle(
        _sourceUrlsJsonMeta,
        sourceUrlsJson.isAcceptableOrUnknown(
          data['source_urls_json']!,
          _sourceUrlsJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_sourceUrlsJsonMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RestrictionCoverage map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RestrictionCoverage(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      jurisdictionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}jurisdiction_id'],
      )!,
      jurisdictionName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}jurisdiction_name'],
      )!,
      vehicleKind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}vehicle_kind'],
      )!,
      serviceType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}service_type'],
      )!,
      rulesJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}rules_json'],
      )!,
      verifiedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}verified_at'],
      )!,
      staleAfter: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}stale_after'],
      )!,
      sourceUrlsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_urls_json'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $RestrictionCoveragesTable createAlias(String alias) {
    return $RestrictionCoveragesTable(attachedDatabase, alias);
  }
}

class RestrictionCoverage extends DataClass
    implements Insertable<RestrictionCoverage> {
  final String id;
  final String jurisdictionId;
  final String jurisdictionName;
  final String vehicleKind;
  final String serviceType;
  final String rulesJson;
  final DateTime verifiedAt;
  final DateTime staleAfter;
  final String sourceUrlsJson;
  final DateTime updatedAt;
  const RestrictionCoverage({
    required this.id,
    required this.jurisdictionId,
    required this.jurisdictionName,
    required this.vehicleKind,
    required this.serviceType,
    required this.rulesJson,
    required this.verifiedAt,
    required this.staleAfter,
    required this.sourceUrlsJson,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['jurisdiction_id'] = Variable<String>(jurisdictionId);
    map['jurisdiction_name'] = Variable<String>(jurisdictionName);
    map['vehicle_kind'] = Variable<String>(vehicleKind);
    map['service_type'] = Variable<String>(serviceType);
    map['rules_json'] = Variable<String>(rulesJson);
    map['verified_at'] = Variable<DateTime>(verifiedAt);
    map['stale_after'] = Variable<DateTime>(staleAfter);
    map['source_urls_json'] = Variable<String>(sourceUrlsJson);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  RestrictionCoveragesCompanion toCompanion(bool nullToAbsent) {
    return RestrictionCoveragesCompanion(
      id: Value(id),
      jurisdictionId: Value(jurisdictionId),
      jurisdictionName: Value(jurisdictionName),
      vehicleKind: Value(vehicleKind),
      serviceType: Value(serviceType),
      rulesJson: Value(rulesJson),
      verifiedAt: Value(verifiedAt),
      staleAfter: Value(staleAfter),
      sourceUrlsJson: Value(sourceUrlsJson),
      updatedAt: Value(updatedAt),
    );
  }

  factory RestrictionCoverage.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RestrictionCoverage(
      id: serializer.fromJson<String>(json['id']),
      jurisdictionId: serializer.fromJson<String>(json['jurisdictionId']),
      jurisdictionName: serializer.fromJson<String>(json['jurisdictionName']),
      vehicleKind: serializer.fromJson<String>(json['vehicleKind']),
      serviceType: serializer.fromJson<String>(json['serviceType']),
      rulesJson: serializer.fromJson<String>(json['rulesJson']),
      verifiedAt: serializer.fromJson<DateTime>(json['verifiedAt']),
      staleAfter: serializer.fromJson<DateTime>(json['staleAfter']),
      sourceUrlsJson: serializer.fromJson<String>(json['sourceUrlsJson']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'jurisdictionId': serializer.toJson<String>(jurisdictionId),
      'jurisdictionName': serializer.toJson<String>(jurisdictionName),
      'vehicleKind': serializer.toJson<String>(vehicleKind),
      'serviceType': serializer.toJson<String>(serviceType),
      'rulesJson': serializer.toJson<String>(rulesJson),
      'verifiedAt': serializer.toJson<DateTime>(verifiedAt),
      'staleAfter': serializer.toJson<DateTime>(staleAfter),
      'sourceUrlsJson': serializer.toJson<String>(sourceUrlsJson),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  RestrictionCoverage copyWith({
    String? id,
    String? jurisdictionId,
    String? jurisdictionName,
    String? vehicleKind,
    String? serviceType,
    String? rulesJson,
    DateTime? verifiedAt,
    DateTime? staleAfter,
    String? sourceUrlsJson,
    DateTime? updatedAt,
  }) => RestrictionCoverage(
    id: id ?? this.id,
    jurisdictionId: jurisdictionId ?? this.jurisdictionId,
    jurisdictionName: jurisdictionName ?? this.jurisdictionName,
    vehicleKind: vehicleKind ?? this.vehicleKind,
    serviceType: serviceType ?? this.serviceType,
    rulesJson: rulesJson ?? this.rulesJson,
    verifiedAt: verifiedAt ?? this.verifiedAt,
    staleAfter: staleAfter ?? this.staleAfter,
    sourceUrlsJson: sourceUrlsJson ?? this.sourceUrlsJson,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  RestrictionCoverage copyWithCompanion(RestrictionCoveragesCompanion data) {
    return RestrictionCoverage(
      id: data.id.present ? data.id.value : this.id,
      jurisdictionId: data.jurisdictionId.present
          ? data.jurisdictionId.value
          : this.jurisdictionId,
      jurisdictionName: data.jurisdictionName.present
          ? data.jurisdictionName.value
          : this.jurisdictionName,
      vehicleKind: data.vehicleKind.present
          ? data.vehicleKind.value
          : this.vehicleKind,
      serviceType: data.serviceType.present
          ? data.serviceType.value
          : this.serviceType,
      rulesJson: data.rulesJson.present ? data.rulesJson.value : this.rulesJson,
      verifiedAt: data.verifiedAt.present
          ? data.verifiedAt.value
          : this.verifiedAt,
      staleAfter: data.staleAfter.present
          ? data.staleAfter.value
          : this.staleAfter,
      sourceUrlsJson: data.sourceUrlsJson.present
          ? data.sourceUrlsJson.value
          : this.sourceUrlsJson,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RestrictionCoverage(')
          ..write('id: $id, ')
          ..write('jurisdictionId: $jurisdictionId, ')
          ..write('jurisdictionName: $jurisdictionName, ')
          ..write('vehicleKind: $vehicleKind, ')
          ..write('serviceType: $serviceType, ')
          ..write('rulesJson: $rulesJson, ')
          ..write('verifiedAt: $verifiedAt, ')
          ..write('staleAfter: $staleAfter, ')
          ..write('sourceUrlsJson: $sourceUrlsJson, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    jurisdictionId,
    jurisdictionName,
    vehicleKind,
    serviceType,
    rulesJson,
    verifiedAt,
    staleAfter,
    sourceUrlsJson,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RestrictionCoverage &&
          other.id == this.id &&
          other.jurisdictionId == this.jurisdictionId &&
          other.jurisdictionName == this.jurisdictionName &&
          other.vehicleKind == this.vehicleKind &&
          other.serviceType == this.serviceType &&
          other.rulesJson == this.rulesJson &&
          other.verifiedAt == this.verifiedAt &&
          other.staleAfter == this.staleAfter &&
          other.sourceUrlsJson == this.sourceUrlsJson &&
          other.updatedAt == this.updatedAt);
}

class RestrictionCoveragesCompanion
    extends UpdateCompanion<RestrictionCoverage> {
  final Value<String> id;
  final Value<String> jurisdictionId;
  final Value<String> jurisdictionName;
  final Value<String> vehicleKind;
  final Value<String> serviceType;
  final Value<String> rulesJson;
  final Value<DateTime> verifiedAt;
  final Value<DateTime> staleAfter;
  final Value<String> sourceUrlsJson;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const RestrictionCoveragesCompanion({
    this.id = const Value.absent(),
    this.jurisdictionId = const Value.absent(),
    this.jurisdictionName = const Value.absent(),
    this.vehicleKind = const Value.absent(),
    this.serviceType = const Value.absent(),
    this.rulesJson = const Value.absent(),
    this.verifiedAt = const Value.absent(),
    this.staleAfter = const Value.absent(),
    this.sourceUrlsJson = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RestrictionCoveragesCompanion.insert({
    required String id,
    required String jurisdictionId,
    required String jurisdictionName,
    required String vehicleKind,
    required String serviceType,
    required String rulesJson,
    required DateTime verifiedAt,
    required DateTime staleAfter,
    required String sourceUrlsJson,
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       jurisdictionId = Value(jurisdictionId),
       jurisdictionName = Value(jurisdictionName),
       vehicleKind = Value(vehicleKind),
       serviceType = Value(serviceType),
       rulesJson = Value(rulesJson),
       verifiedAt = Value(verifiedAt),
       staleAfter = Value(staleAfter),
       sourceUrlsJson = Value(sourceUrlsJson);
  static Insertable<RestrictionCoverage> custom({
    Expression<String>? id,
    Expression<String>? jurisdictionId,
    Expression<String>? jurisdictionName,
    Expression<String>? vehicleKind,
    Expression<String>? serviceType,
    Expression<String>? rulesJson,
    Expression<DateTime>? verifiedAt,
    Expression<DateTime>? staleAfter,
    Expression<String>? sourceUrlsJson,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (jurisdictionId != null) 'jurisdiction_id': jurisdictionId,
      if (jurisdictionName != null) 'jurisdiction_name': jurisdictionName,
      if (vehicleKind != null) 'vehicle_kind': vehicleKind,
      if (serviceType != null) 'service_type': serviceType,
      if (rulesJson != null) 'rules_json': rulesJson,
      if (verifiedAt != null) 'verified_at': verifiedAt,
      if (staleAfter != null) 'stale_after': staleAfter,
      if (sourceUrlsJson != null) 'source_urls_json': sourceUrlsJson,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RestrictionCoveragesCompanion copyWith({
    Value<String>? id,
    Value<String>? jurisdictionId,
    Value<String>? jurisdictionName,
    Value<String>? vehicleKind,
    Value<String>? serviceType,
    Value<String>? rulesJson,
    Value<DateTime>? verifiedAt,
    Value<DateTime>? staleAfter,
    Value<String>? sourceUrlsJson,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return RestrictionCoveragesCompanion(
      id: id ?? this.id,
      jurisdictionId: jurisdictionId ?? this.jurisdictionId,
      jurisdictionName: jurisdictionName ?? this.jurisdictionName,
      vehicleKind: vehicleKind ?? this.vehicleKind,
      serviceType: serviceType ?? this.serviceType,
      rulesJson: rulesJson ?? this.rulesJson,
      verifiedAt: verifiedAt ?? this.verifiedAt,
      staleAfter: staleAfter ?? this.staleAfter,
      sourceUrlsJson: sourceUrlsJson ?? this.sourceUrlsJson,
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
    if (jurisdictionId.present) {
      map['jurisdiction_id'] = Variable<String>(jurisdictionId.value);
    }
    if (jurisdictionName.present) {
      map['jurisdiction_name'] = Variable<String>(jurisdictionName.value);
    }
    if (vehicleKind.present) {
      map['vehicle_kind'] = Variable<String>(vehicleKind.value);
    }
    if (serviceType.present) {
      map['service_type'] = Variable<String>(serviceType.value);
    }
    if (rulesJson.present) {
      map['rules_json'] = Variable<String>(rulesJson.value);
    }
    if (verifiedAt.present) {
      map['verified_at'] = Variable<DateTime>(verifiedAt.value);
    }
    if (staleAfter.present) {
      map['stale_after'] = Variable<DateTime>(staleAfter.value);
    }
    if (sourceUrlsJson.present) {
      map['source_urls_json'] = Variable<String>(sourceUrlsJson.value);
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
    return (StringBuffer('RestrictionCoveragesCompanion(')
          ..write('id: $id, ')
          ..write('jurisdictionId: $jurisdictionId, ')
          ..write('jurisdictionName: $jurisdictionName, ')
          ..write('vehicleKind: $vehicleKind, ')
          ..write('serviceType: $serviceType, ')
          ..write('rulesJson: $rulesJson, ')
          ..write('verifiedAt: $verifiedAt, ')
          ..write('staleAfter: $staleAfter, ')
          ..write('sourceUrlsJson: $sourceUrlsJson, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DriverProfilesTable extends DriverProfiles
    with TableInfo<$DriverProfilesTable, DriverProfile> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DriverProfilesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _slotMeta = const VerificationMeta('slot');
  @override
  late final GeneratedColumn<int> slot = GeneratedColumn<int>(
    'slot',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _encryptedMetadataMeta = const VerificationMeta(
    'encryptedMetadata',
  );
  @override
  late final GeneratedColumn<Uint8List> encryptedMetadata =
      GeneratedColumn<Uint8List>(
        'encrypted_metadata',
        aliasedName,
        false,
        type: DriftSqlType.blob,
        requiredDuringInsert: true,
      );
  @override
  List<GeneratedColumn> get $columns => [id, slot, encryptedMetadata];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'driver_profiles';
  @override
  VerificationContext validateIntegrity(
    Insertable<DriverProfile> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('slot')) {
      context.handle(
        _slotMeta,
        slot.isAcceptableOrUnknown(data['slot']!, _slotMeta),
      );
    } else if (isInserting) {
      context.missing(_slotMeta);
    }
    if (data.containsKey('encrypted_metadata')) {
      context.handle(
        _encryptedMetadataMeta,
        encryptedMetadata.isAcceptableOrUnknown(
          data['encrypted_metadata']!,
          _encryptedMetadataMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_encryptedMetadataMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DriverProfile map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DriverProfile(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      slot: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}slot'],
      )!,
      encryptedMetadata: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}encrypted_metadata'],
      )!,
    );
  }

  @override
  $DriverProfilesTable createAlias(String alias) {
    return $DriverProfilesTable(attachedDatabase, alias);
  }
}

class DriverProfile extends DataClass implements Insertable<DriverProfile> {
  final String id;
  final int slot;
  final Uint8List encryptedMetadata;
  const DriverProfile({
    required this.id,
    required this.slot,
    required this.encryptedMetadata,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['slot'] = Variable<int>(slot);
    map['encrypted_metadata'] = Variable<Uint8List>(encryptedMetadata);
    return map;
  }

  DriverProfilesCompanion toCompanion(bool nullToAbsent) {
    return DriverProfilesCompanion(
      id: Value(id),
      slot: Value(slot),
      encryptedMetadata: Value(encryptedMetadata),
    );
  }

  factory DriverProfile.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DriverProfile(
      id: serializer.fromJson<String>(json['id']),
      slot: serializer.fromJson<int>(json['slot']),
      encryptedMetadata: serializer.fromJson<Uint8List>(
        json['encryptedMetadata'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'slot': serializer.toJson<int>(slot),
      'encryptedMetadata': serializer.toJson<Uint8List>(encryptedMetadata),
    };
  }

  DriverProfile copyWith({
    String? id,
    int? slot,
    Uint8List? encryptedMetadata,
  }) => DriverProfile(
    id: id ?? this.id,
    slot: slot ?? this.slot,
    encryptedMetadata: encryptedMetadata ?? this.encryptedMetadata,
  );
  DriverProfile copyWithCompanion(DriverProfilesCompanion data) {
    return DriverProfile(
      id: data.id.present ? data.id.value : this.id,
      slot: data.slot.present ? data.slot.value : this.slot,
      encryptedMetadata: data.encryptedMetadata.present
          ? data.encryptedMetadata.value
          : this.encryptedMetadata,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DriverProfile(')
          ..write('id: $id, ')
          ..write('slot: $slot, ')
          ..write('encryptedMetadata: $encryptedMetadata')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, slot, $driftBlobEquality.hash(encryptedMetadata));
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DriverProfile &&
          other.id == this.id &&
          other.slot == this.slot &&
          $driftBlobEquality.equals(
            other.encryptedMetadata,
            this.encryptedMetadata,
          ));
}

class DriverProfilesCompanion extends UpdateCompanion<DriverProfile> {
  final Value<String> id;
  final Value<int> slot;
  final Value<Uint8List> encryptedMetadata;
  final Value<int> rowid;
  const DriverProfilesCompanion({
    this.id = const Value.absent(),
    this.slot = const Value.absent(),
    this.encryptedMetadata = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DriverProfilesCompanion.insert({
    required String id,
    required int slot,
    required Uint8List encryptedMetadata,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       slot = Value(slot),
       encryptedMetadata = Value(encryptedMetadata);
  static Insertable<DriverProfile> custom({
    Expression<String>? id,
    Expression<int>? slot,
    Expression<Uint8List>? encryptedMetadata,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (slot != null) 'slot': slot,
      if (encryptedMetadata != null) 'encrypted_metadata': encryptedMetadata,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DriverProfilesCompanion copyWith({
    Value<String>? id,
    Value<int>? slot,
    Value<Uint8List>? encryptedMetadata,
    Value<int>? rowid,
  }) {
    return DriverProfilesCompanion(
      id: id ?? this.id,
      slot: slot ?? this.slot,
      encryptedMetadata: encryptedMetadata ?? this.encryptedMetadata,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (slot.present) {
      map['slot'] = Variable<int>(slot.value);
    }
    if (encryptedMetadata.present) {
      map['encrypted_metadata'] = Variable<Uint8List>(encryptedMetadata.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DriverProfilesCompanion(')
          ..write('id: $id, ')
          ..write('slot: $slot, ')
          ..write('encryptedMetadata: $encryptedMetadata, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $WalletPreparationsTable extends WalletPreparations
    with TableInfo<$WalletPreparationsTable, WalletPreparation> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WalletPreparationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _encryptedMetadataMeta = const VerificationMeta(
    'encryptedMetadata',
  );
  @override
  late final GeneratedColumn<Uint8List> encryptedMetadata =
      GeneratedColumn<Uint8List>(
        'encrypted_metadata',
        aliasedName,
        false,
        type: DriftSqlType.blob,
        requiredDuringInsert: true,
      );
  @override
  List<GeneratedColumn> get $columns => [id, encryptedMetadata];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'wallet_preparations';
  @override
  VerificationContext validateIntegrity(
    Insertable<WalletPreparation> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('encrypted_metadata')) {
      context.handle(
        _encryptedMetadataMeta,
        encryptedMetadata.isAcceptableOrUnknown(
          data['encrypted_metadata']!,
          _encryptedMetadataMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_encryptedMetadataMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  WalletPreparation map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WalletPreparation(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      encryptedMetadata: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}encrypted_metadata'],
      )!,
    );
  }

  @override
  $WalletPreparationsTable createAlias(String alias) {
    return $WalletPreparationsTable(attachedDatabase, alias);
  }
}

class WalletPreparation extends DataClass
    implements Insertable<WalletPreparation> {
  final String id;
  final Uint8List encryptedMetadata;
  const WalletPreparation({required this.id, required this.encryptedMetadata});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['encrypted_metadata'] = Variable<Uint8List>(encryptedMetadata);
    return map;
  }

  WalletPreparationsCompanion toCompanion(bool nullToAbsent) {
    return WalletPreparationsCompanion(
      id: Value(id),
      encryptedMetadata: Value(encryptedMetadata),
    );
  }

  factory WalletPreparation.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WalletPreparation(
      id: serializer.fromJson<String>(json['id']),
      encryptedMetadata: serializer.fromJson<Uint8List>(
        json['encryptedMetadata'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'encryptedMetadata': serializer.toJson<Uint8List>(encryptedMetadata),
    };
  }

  WalletPreparation copyWith({String? id, Uint8List? encryptedMetadata}) =>
      WalletPreparation(
        id: id ?? this.id,
        encryptedMetadata: encryptedMetadata ?? this.encryptedMetadata,
      );
  WalletPreparation copyWithCompanion(WalletPreparationsCompanion data) {
    return WalletPreparation(
      id: data.id.present ? data.id.value : this.id,
      encryptedMetadata: data.encryptedMetadata.present
          ? data.encryptedMetadata.value
          : this.encryptedMetadata,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WalletPreparation(')
          ..write('id: $id, ')
          ..write('encryptedMetadata: $encryptedMetadata')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, $driftBlobEquality.hash(encryptedMetadata));
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WalletPreparation &&
          other.id == this.id &&
          $driftBlobEquality.equals(
            other.encryptedMetadata,
            this.encryptedMetadata,
          ));
}

class WalletPreparationsCompanion extends UpdateCompanion<WalletPreparation> {
  final Value<String> id;
  final Value<Uint8List> encryptedMetadata;
  final Value<int> rowid;
  const WalletPreparationsCompanion({
    this.id = const Value.absent(),
    this.encryptedMetadata = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WalletPreparationsCompanion.insert({
    required String id,
    required Uint8List encryptedMetadata,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       encryptedMetadata = Value(encryptedMetadata);
  static Insertable<WalletPreparation> custom({
    Expression<String>? id,
    Expression<Uint8List>? encryptedMetadata,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (encryptedMetadata != null) 'encrypted_metadata': encryptedMetadata,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WalletPreparationsCompanion copyWith({
    Value<String>? id,
    Value<Uint8List>? encryptedMetadata,
    Value<int>? rowid,
  }) {
    return WalletPreparationsCompanion(
      id: id ?? this.id,
      encryptedMetadata: encryptedMetadata ?? this.encryptedMetadata,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (encryptedMetadata.present) {
      map['encrypted_metadata'] = Variable<Uint8List>(encryptedMetadata.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WalletPreparationsCompanion(')
          ..write('id: $id, ')
          ..write('encryptedMetadata: $encryptedMetadata, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PrivateDocumentsTable extends PrivateDocuments
    with TableInfo<$PrivateDocumentsTable, PrivateDocument> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PrivateDocumentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _driverIdMeta = const VerificationMeta(
    'driverId',
  );
  @override
  late final GeneratedColumn<String> driverId = GeneratedColumn<String>(
    'driver_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES driver_profiles (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _vehicleIdMeta = const VerificationMeta(
    'vehicleId',
  );
  @override
  late final GeneratedColumn<String> vehicleId = GeneratedColumn<String>(
    'vehicle_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES vehicles (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _preparationIdMeta = const VerificationMeta(
    'preparationId',
  );
  @override
  late final GeneratedColumn<String> preparationId = GeneratedColumn<String>(
    'preparation_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES wallet_preparations (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 32,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _encryptedMetadataMeta = const VerificationMeta(
    'encryptedMetadata',
  );
  @override
  late final GeneratedColumn<Uint8List> encryptedMetadata =
      GeneratedColumn<Uint8List>(
        'encrypted_metadata',
        aliasedName,
        false,
        type: DriftSqlType.blob,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _importedAtMeta = const VerificationMeta(
    'importedAt',
  );
  @override
  late final GeneratedColumn<DateTime> importedAt = GeneratedColumn<DateTime>(
    'imported_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    driverId,
    vehicleId,
    preparationId,
    type,
    encryptedMetadata,
    importedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'private_documents';
  @override
  VerificationContext validateIntegrity(
    Insertable<PrivateDocument> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('driver_id')) {
      context.handle(
        _driverIdMeta,
        driverId.isAcceptableOrUnknown(data['driver_id']!, _driverIdMeta),
      );
    }
    if (data.containsKey('vehicle_id')) {
      context.handle(
        _vehicleIdMeta,
        vehicleId.isAcceptableOrUnknown(data['vehicle_id']!, _vehicleIdMeta),
      );
    }
    if (data.containsKey('preparation_id')) {
      context.handle(
        _preparationIdMeta,
        preparationId.isAcceptableOrUnknown(
          data['preparation_id']!,
          _preparationIdMeta,
        ),
      );
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('encrypted_metadata')) {
      context.handle(
        _encryptedMetadataMeta,
        encryptedMetadata.isAcceptableOrUnknown(
          data['encrypted_metadata']!,
          _encryptedMetadataMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_encryptedMetadataMeta);
    }
    if (data.containsKey('imported_at')) {
      context.handle(
        _importedAtMeta,
        importedAt.isAcceptableOrUnknown(data['imported_at']!, _importedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PrivateDocument map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PrivateDocument(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      driverId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}driver_id'],
      ),
      vehicleId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}vehicle_id'],
      ),
      preparationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}preparation_id'],
      ),
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      encryptedMetadata: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}encrypted_metadata'],
      )!,
      importedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}imported_at'],
      )!,
    );
  }

  @override
  $PrivateDocumentsTable createAlias(String alias) {
    return $PrivateDocumentsTable(attachedDatabase, alias);
  }
}

class PrivateDocument extends DataClass implements Insertable<PrivateDocument> {
  final String id;
  final String? driverId;
  final String? vehicleId;
  final String? preparationId;
  final String type;
  final Uint8List encryptedMetadata;
  final DateTime importedAt;
  const PrivateDocument({
    required this.id,
    this.driverId,
    this.vehicleId,
    this.preparationId,
    required this.type,
    required this.encryptedMetadata,
    required this.importedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || driverId != null) {
      map['driver_id'] = Variable<String>(driverId);
    }
    if (!nullToAbsent || vehicleId != null) {
      map['vehicle_id'] = Variable<String>(vehicleId);
    }
    if (!nullToAbsent || preparationId != null) {
      map['preparation_id'] = Variable<String>(preparationId);
    }
    map['type'] = Variable<String>(type);
    map['encrypted_metadata'] = Variable<Uint8List>(encryptedMetadata);
    map['imported_at'] = Variable<DateTime>(importedAt);
    return map;
  }

  PrivateDocumentsCompanion toCompanion(bool nullToAbsent) {
    return PrivateDocumentsCompanion(
      id: Value(id),
      driverId: driverId == null && nullToAbsent
          ? const Value.absent()
          : Value(driverId),
      vehicleId: vehicleId == null && nullToAbsent
          ? const Value.absent()
          : Value(vehicleId),
      preparationId: preparationId == null && nullToAbsent
          ? const Value.absent()
          : Value(preparationId),
      type: Value(type),
      encryptedMetadata: Value(encryptedMetadata),
      importedAt: Value(importedAt),
    );
  }

  factory PrivateDocument.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PrivateDocument(
      id: serializer.fromJson<String>(json['id']),
      driverId: serializer.fromJson<String?>(json['driverId']),
      vehicleId: serializer.fromJson<String?>(json['vehicleId']),
      preparationId: serializer.fromJson<String?>(json['preparationId']),
      type: serializer.fromJson<String>(json['type']),
      encryptedMetadata: serializer.fromJson<Uint8List>(
        json['encryptedMetadata'],
      ),
      importedAt: serializer.fromJson<DateTime>(json['importedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'driverId': serializer.toJson<String?>(driverId),
      'vehicleId': serializer.toJson<String?>(vehicleId),
      'preparationId': serializer.toJson<String?>(preparationId),
      'type': serializer.toJson<String>(type),
      'encryptedMetadata': serializer.toJson<Uint8List>(encryptedMetadata),
      'importedAt': serializer.toJson<DateTime>(importedAt),
    };
  }

  PrivateDocument copyWith({
    String? id,
    Value<String?> driverId = const Value.absent(),
    Value<String?> vehicleId = const Value.absent(),
    Value<String?> preparationId = const Value.absent(),
    String? type,
    Uint8List? encryptedMetadata,
    DateTime? importedAt,
  }) => PrivateDocument(
    id: id ?? this.id,
    driverId: driverId.present ? driverId.value : this.driverId,
    vehicleId: vehicleId.present ? vehicleId.value : this.vehicleId,
    preparationId: preparationId.present
        ? preparationId.value
        : this.preparationId,
    type: type ?? this.type,
    encryptedMetadata: encryptedMetadata ?? this.encryptedMetadata,
    importedAt: importedAt ?? this.importedAt,
  );
  PrivateDocument copyWithCompanion(PrivateDocumentsCompanion data) {
    return PrivateDocument(
      id: data.id.present ? data.id.value : this.id,
      driverId: data.driverId.present ? data.driverId.value : this.driverId,
      vehicleId: data.vehicleId.present ? data.vehicleId.value : this.vehicleId,
      preparationId: data.preparationId.present
          ? data.preparationId.value
          : this.preparationId,
      type: data.type.present ? data.type.value : this.type,
      encryptedMetadata: data.encryptedMetadata.present
          ? data.encryptedMetadata.value
          : this.encryptedMetadata,
      importedAt: data.importedAt.present
          ? data.importedAt.value
          : this.importedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PrivateDocument(')
          ..write('id: $id, ')
          ..write('driverId: $driverId, ')
          ..write('vehicleId: $vehicleId, ')
          ..write('preparationId: $preparationId, ')
          ..write('type: $type, ')
          ..write('encryptedMetadata: $encryptedMetadata, ')
          ..write('importedAt: $importedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    driverId,
    vehicleId,
    preparationId,
    type,
    $driftBlobEquality.hash(encryptedMetadata),
    importedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PrivateDocument &&
          other.id == this.id &&
          other.driverId == this.driverId &&
          other.vehicleId == this.vehicleId &&
          other.preparationId == this.preparationId &&
          other.type == this.type &&
          $driftBlobEquality.equals(
            other.encryptedMetadata,
            this.encryptedMetadata,
          ) &&
          other.importedAt == this.importedAt);
}

class PrivateDocumentsCompanion extends UpdateCompanion<PrivateDocument> {
  final Value<String> id;
  final Value<String?> driverId;
  final Value<String?> vehicleId;
  final Value<String?> preparationId;
  final Value<String> type;
  final Value<Uint8List> encryptedMetadata;
  final Value<DateTime> importedAt;
  final Value<int> rowid;
  const PrivateDocumentsCompanion({
    this.id = const Value.absent(),
    this.driverId = const Value.absent(),
    this.vehicleId = const Value.absent(),
    this.preparationId = const Value.absent(),
    this.type = const Value.absent(),
    this.encryptedMetadata = const Value.absent(),
    this.importedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PrivateDocumentsCompanion.insert({
    required String id,
    this.driverId = const Value.absent(),
    this.vehicleId = const Value.absent(),
    this.preparationId = const Value.absent(),
    required String type,
    required Uint8List encryptedMetadata,
    this.importedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       type = Value(type),
       encryptedMetadata = Value(encryptedMetadata);
  static Insertable<PrivateDocument> custom({
    Expression<String>? id,
    Expression<String>? driverId,
    Expression<String>? vehicleId,
    Expression<String>? preparationId,
    Expression<String>? type,
    Expression<Uint8List>? encryptedMetadata,
    Expression<DateTime>? importedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (driverId != null) 'driver_id': driverId,
      if (vehicleId != null) 'vehicle_id': vehicleId,
      if (preparationId != null) 'preparation_id': preparationId,
      if (type != null) 'type': type,
      if (encryptedMetadata != null) 'encrypted_metadata': encryptedMetadata,
      if (importedAt != null) 'imported_at': importedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PrivateDocumentsCompanion copyWith({
    Value<String>? id,
    Value<String?>? driverId,
    Value<String?>? vehicleId,
    Value<String?>? preparationId,
    Value<String>? type,
    Value<Uint8List>? encryptedMetadata,
    Value<DateTime>? importedAt,
    Value<int>? rowid,
  }) {
    return PrivateDocumentsCompanion(
      id: id ?? this.id,
      driverId: driverId ?? this.driverId,
      vehicleId: vehicleId ?? this.vehicleId,
      preparationId: preparationId ?? this.preparationId,
      type: type ?? this.type,
      encryptedMetadata: encryptedMetadata ?? this.encryptedMetadata,
      importedAt: importedAt ?? this.importedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (driverId.present) {
      map['driver_id'] = Variable<String>(driverId.value);
    }
    if (vehicleId.present) {
      map['vehicle_id'] = Variable<String>(vehicleId.value);
    }
    if (preparationId.present) {
      map['preparation_id'] = Variable<String>(preparationId.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (encryptedMetadata.present) {
      map['encrypted_metadata'] = Variable<Uint8List>(encryptedMetadata.value);
    }
    if (importedAt.present) {
      map['imported_at'] = Variable<DateTime>(importedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PrivateDocumentsCompanion(')
          ..write('id: $id, ')
          ..write('driverId: $driverId, ')
          ..write('vehicleId: $vehicleId, ')
          ..write('preparationId: $preparationId, ')
          ..write('type: $type, ')
          ..write('encryptedMetadata: $encryptedMetadata, ')
          ..write('importedAt: $importedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $WalletMigrationsTable extends WalletMigrations
    with TableInfo<$WalletMigrationsTable, WalletMigration> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WalletMigrationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _encryptedMetadataMeta = const VerificationMeta(
    'encryptedMetadata',
  );
  @override
  late final GeneratedColumn<Uint8List> encryptedMetadata =
      GeneratedColumn<Uint8List>(
        'encrypted_metadata',
        aliasedName,
        false,
        type: DriftSqlType.blob,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _completedAtMeta = const VerificationMeta(
    'completedAt',
  );
  @override
  late final GeneratedColumn<DateTime> completedAt = GeneratedColumn<DateTime>(
    'completed_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [id, encryptedMetadata, completedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'wallet_migrations';
  @override
  VerificationContext validateIntegrity(
    Insertable<WalletMigration> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('encrypted_metadata')) {
      context.handle(
        _encryptedMetadataMeta,
        encryptedMetadata.isAcceptableOrUnknown(
          data['encrypted_metadata']!,
          _encryptedMetadataMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_encryptedMetadataMeta);
    }
    if (data.containsKey('completed_at')) {
      context.handle(
        _completedAtMeta,
        completedAt.isAcceptableOrUnknown(
          data['completed_at']!,
          _completedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  WalletMigration map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WalletMigration(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      encryptedMetadata: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}encrypted_metadata'],
      )!,
      completedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}completed_at'],
      )!,
    );
  }

  @override
  $WalletMigrationsTable createAlias(String alias) {
    return $WalletMigrationsTable(attachedDatabase, alias);
  }
}

class WalletMigration extends DataClass implements Insertable<WalletMigration> {
  final String id;
  final Uint8List encryptedMetadata;
  final DateTime completedAt;
  const WalletMigration({
    required this.id,
    required this.encryptedMetadata,
    required this.completedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['encrypted_metadata'] = Variable<Uint8List>(encryptedMetadata);
    map['completed_at'] = Variable<DateTime>(completedAt);
    return map;
  }

  WalletMigrationsCompanion toCompanion(bool nullToAbsent) {
    return WalletMigrationsCompanion(
      id: Value(id),
      encryptedMetadata: Value(encryptedMetadata),
      completedAt: Value(completedAt),
    );
  }

  factory WalletMigration.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WalletMigration(
      id: serializer.fromJson<String>(json['id']),
      encryptedMetadata: serializer.fromJson<Uint8List>(
        json['encryptedMetadata'],
      ),
      completedAt: serializer.fromJson<DateTime>(json['completedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'encryptedMetadata': serializer.toJson<Uint8List>(encryptedMetadata),
      'completedAt': serializer.toJson<DateTime>(completedAt),
    };
  }

  WalletMigration copyWith({
    String? id,
    Uint8List? encryptedMetadata,
    DateTime? completedAt,
  }) => WalletMigration(
    id: id ?? this.id,
    encryptedMetadata: encryptedMetadata ?? this.encryptedMetadata,
    completedAt: completedAt ?? this.completedAt,
  );
  WalletMigration copyWithCompanion(WalletMigrationsCompanion data) {
    return WalletMigration(
      id: data.id.present ? data.id.value : this.id,
      encryptedMetadata: data.encryptedMetadata.present
          ? data.encryptedMetadata.value
          : this.encryptedMetadata,
      completedAt: data.completedAt.present
          ? data.completedAt.value
          : this.completedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WalletMigration(')
          ..write('id: $id, ')
          ..write('encryptedMetadata: $encryptedMetadata, ')
          ..write('completedAt: $completedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, $driftBlobEquality.hash(encryptedMetadata), completedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WalletMigration &&
          other.id == this.id &&
          $driftBlobEquality.equals(
            other.encryptedMetadata,
            this.encryptedMetadata,
          ) &&
          other.completedAt == this.completedAt);
}

class WalletMigrationsCompanion extends UpdateCompanion<WalletMigration> {
  final Value<String> id;
  final Value<Uint8List> encryptedMetadata;
  final Value<DateTime> completedAt;
  final Value<int> rowid;
  const WalletMigrationsCompanion({
    this.id = const Value.absent(),
    this.encryptedMetadata = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WalletMigrationsCompanion.insert({
    required String id,
    required Uint8List encryptedMetadata,
    this.completedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       encryptedMetadata = Value(encryptedMetadata);
  static Insertable<WalletMigration> custom({
    Expression<String>? id,
    Expression<Uint8List>? encryptedMetadata,
    Expression<DateTime>? completedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (encryptedMetadata != null) 'encrypted_metadata': encryptedMetadata,
      if (completedAt != null) 'completed_at': completedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WalletMigrationsCompanion copyWith({
    Value<String>? id,
    Value<Uint8List>? encryptedMetadata,
    Value<DateTime>? completedAt,
    Value<int>? rowid,
  }) {
    return WalletMigrationsCompanion(
      id: id ?? this.id,
      encryptedMetadata: encryptedMetadata ?? this.encryptedMetadata,
      completedAt: completedAt ?? this.completedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (encryptedMetadata.present) {
      map['encrypted_metadata'] = Variable<Uint8List>(encryptedMetadata.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<DateTime>(completedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WalletMigrationsCompanion(')
          ..write('id: $id, ')
          ..write('encryptedMetadata: $encryptedMetadata, ')
          ..write('completedAt: $completedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $VehiclesTable vehicles = $VehiclesTable(this);
  late final $VehicleObligationsTable vehicleObligations =
      $VehicleObligationsTable(this);
  late final $MaintenanceRecordsTable maintenanceRecords =
      $MaintenanceRecordsTable(this);
  late final $NotificationPreferencesTable notificationPreferences =
      $NotificationPreferencesTable(this);
  late final $DatasetVersionsTable datasetVersions = $DatasetVersionsTable(
    this,
  );
  late final $RestrictionCoveragesTable restrictionCoverages =
      $RestrictionCoveragesTable(this);
  late final $DriverProfilesTable driverProfiles = $DriverProfilesTable(this);
  late final $WalletPreparationsTable walletPreparations =
      $WalletPreparationsTable(this);
  late final $PrivateDocumentsTable privateDocuments = $PrivateDocumentsTable(
    this,
  );
  late final $WalletMigrationsTable walletMigrations = $WalletMigrationsTable(
    this,
  );
  late final Index vehiclesPlateIdx = Index(
    'vehicles_plate_idx',
    'CREATE UNIQUE INDEX vehicles_plate_idx ON vehicles (plate)',
  );
  late final Index vehicleObligationsVehicleIdIdx = Index(
    'vehicle_obligations_vehicle_id_idx',
    'CREATE INDEX vehicle_obligations_vehicle_id_idx ON vehicle_obligations (vehicle_id)',
  );
  late final Index vehicleObligationsDueDateIdx = Index(
    'vehicle_obligations_due_date_idx',
    'CREATE INDEX vehicle_obligations_due_date_idx ON vehicle_obligations (due_date)',
  );
  late final Index maintenanceRecordsVehicleIdIdx = Index(
    'maintenance_records_vehicle_id_idx',
    'CREATE INDEX maintenance_records_vehicle_id_idx ON maintenance_records (vehicle_id)',
  );
  late final Index maintenanceRecordsServiceDateIdx = Index(
    'maintenance_records_service_date_idx',
    'CREATE INDEX maintenance_records_service_date_idx ON maintenance_records (service_date)',
  );
  late final Index datasetVersionsDatasetKeyIdx = Index(
    'dataset_versions_dataset_key_idx',
    'CREATE UNIQUE INDEX dataset_versions_dataset_key_idx ON dataset_versions (dataset_key)',
  );
  late final Index restrictionCoveragesLookupIdx = Index(
    'restriction_coverages_lookup_idx',
    'CREATE UNIQUE INDEX restriction_coverages_lookup_idx ON restriction_coverages (jurisdiction_id, vehicle_kind, service_type)',
  );
  late final Index privateDocumentsDriverTypeIdx = Index(
    'private_documents_driver_type_idx',
    'CREATE UNIQUE INDEX private_documents_driver_type_idx ON private_documents (driver_id, type)',
  );
  late final Index privateDocumentsVehicleTypeIdx = Index(
    'private_documents_vehicle_type_idx',
    'CREATE UNIQUE INDEX private_documents_vehicle_type_idx ON private_documents (vehicle_id, type)',
  );
  late final Index privateDocumentsPreparationTypeIdx = Index(
    'private_documents_preparation_type_idx',
    'CREATE UNIQUE INDEX private_documents_preparation_type_idx ON private_documents (preparation_id, type)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    vehicles,
    vehicleObligations,
    maintenanceRecords,
    notificationPreferences,
    datasetVersions,
    restrictionCoverages,
    driverProfiles,
    walletPreparations,
    privateDocuments,
    walletMigrations,
    vehiclesPlateIdx,
    vehicleObligationsVehicleIdIdx,
    vehicleObligationsDueDateIdx,
    maintenanceRecordsVehicleIdIdx,
    maintenanceRecordsServiceDateIdx,
    datasetVersionsDatasetKeyIdx,
    restrictionCoveragesLookupIdx,
    privateDocumentsDriverTypeIdx,
    privateDocumentsVehicleTypeIdx,
    privateDocumentsPreparationTypeIdx,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'vehicles',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('vehicle_obligations', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'vehicles',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('maintenance_records', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'driver_profiles',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('private_documents', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'vehicles',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('private_documents', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'wallet_preparations',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('private_documents', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$VehiclesTableCreateCompanionBuilder = VehiclesCompanion Function({
  required String id,
  required String plate,
  Value<String?> nickname,
  Value<String> kind,
  Value<String> serviceType,
  Value<String?> subtype,
  Value<String?> registrationCity,
  Value<String?> brand,
  Value<String?> model,
  Value<int?> year,
  Value<String?> color,
  Value<String?> fuel,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});
typedef $$VehiclesTableUpdateCompanionBuilder = VehiclesCompanion Function({
  Value<String> id,
  Value<String> plate,
  Value<String?> nickname,
  Value<String> kind,
  Value<String> serviceType,
  Value<String?> subtype,
  Value<String?> registrationCity,
  Value<String?> brand,
  Value<String?> model,
  Value<int?> year,
  Value<String?> color,
  Value<String?> fuel,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

final class $$VehiclesTableReferences
    extends BaseReferences<_$AppDatabase, $VehiclesTable, Vehicle> {
  $$VehiclesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$VehicleObligationsTable, List<VehicleObligation>>
  _vehicleObligationsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.vehicleObligations,
        aliasName: 'vehicles__id__vehicle_obligations__vehicle_id',
      );

  $$VehicleObligationsTableProcessedTableManager get vehicleObligationsRefs {
    final manager = $$VehicleObligationsTableTableManager(
      $_db,
      $_db.vehicleObligations,
    ).filter((f) => f.vehicleId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _vehicleObligationsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$MaintenanceRecordsTable, List<MaintenanceRecord>>
  _maintenanceRecordsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.maintenanceRecords,
        aliasName: 'vehicles__id__maintenance_records__vehicle_id',
      );

  $$MaintenanceRecordsTableProcessedTableManager get maintenanceRecordsRefs {
    final manager = $$MaintenanceRecordsTableTableManager(
      $_db,
      $_db.maintenanceRecords,
    ).filter((f) => f.vehicleId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _maintenanceRecordsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$PrivateDocumentsTable, List<PrivateDocument>>
  _privateDocumentsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.privateDocuments,
    aliasName: 'vehicles__id__private_documents__vehicle_id',
  );

  $$PrivateDocumentsTableProcessedTableManager get privateDocumentsRefs {
    final manager = $$PrivateDocumentsTableTableManager(
      $_db,
      $_db.privateDocuments,
    ).filter((f) => f.vehicleId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _privateDocumentsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$VehiclesTableFilterComposer
    extends Composer<_$AppDatabase, $VehiclesTable> {
  $$VehiclesTableFilterComposer({
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

  ColumnFilters<String> get plate => $composableBuilder(
    column: $table.plate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nickname => $composableBuilder(
    column: $table.nickname,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get serviceType => $composableBuilder(
    column: $table.serviceType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get subtype => $composableBuilder(
    column: $table.subtype,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get registrationCity => $composableBuilder(
    column: $table.registrationCity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get brand => $composableBuilder(
    column: $table.brand,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get model => $composableBuilder(
    column: $table.model,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get year => $composableBuilder(
    column: $table.year,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fuel => $composableBuilder(
    column: $table.fuel,
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

  Expression<bool> vehicleObligationsRefs(
    Expression<bool> Function($$VehicleObligationsTableFilterComposer f) f,
  ) {
    final $$VehicleObligationsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.vehicleObligations,
      getReferencedColumn: (t) => t.vehicleId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VehicleObligationsTableFilterComposer(
            $db: $db,
            $table: $db.vehicleObligations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> maintenanceRecordsRefs(
    Expression<bool> Function($$MaintenanceRecordsTableFilterComposer f) f,
  ) {
    final $$MaintenanceRecordsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.maintenanceRecords,
      getReferencedColumn: (t) => t.vehicleId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MaintenanceRecordsTableFilterComposer(
            $db: $db,
            $table: $db.maintenanceRecords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> privateDocumentsRefs(
    Expression<bool> Function($$PrivateDocumentsTableFilterComposer f) f,
  ) {
    final $$PrivateDocumentsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.privateDocuments,
      getReferencedColumn: (t) => t.vehicleId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PrivateDocumentsTableFilterComposer(
            $db: $db,
            $table: $db.privateDocuments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$VehiclesTableOrderingComposer
    extends Composer<_$AppDatabase, $VehiclesTable> {
  $$VehiclesTableOrderingComposer({
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

  ColumnOrderings<String> get plate => $composableBuilder(
    column: $table.plate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nickname => $composableBuilder(
    column: $table.nickname,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get serviceType => $composableBuilder(
    column: $table.serviceType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get subtype => $composableBuilder(
    column: $table.subtype,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get registrationCity => $composableBuilder(
    column: $table.registrationCity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get brand => $composableBuilder(
    column: $table.brand,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get model => $composableBuilder(
    column: $table.model,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get year => $composableBuilder(
    column: $table.year,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fuel => $composableBuilder(
    column: $table.fuel,
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
}

class $$VehiclesTableAnnotationComposer
    extends Composer<_$AppDatabase, $VehiclesTable> {
  $$VehiclesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get plate =>
      $composableBuilder(column: $table.plate, builder: (column) => column);

  GeneratedColumn<String> get nickname =>
      $composableBuilder(column: $table.nickname, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get serviceType => $composableBuilder(
    column: $table.serviceType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get subtype =>
      $composableBuilder(column: $table.subtype, builder: (column) => column);

  GeneratedColumn<String> get registrationCity => $composableBuilder(
    column: $table.registrationCity,
    builder: (column) => column,
  );

  GeneratedColumn<String> get brand =>
      $composableBuilder(column: $table.brand, builder: (column) => column);

  GeneratedColumn<String> get model =>
      $composableBuilder(column: $table.model, builder: (column) => column);

  GeneratedColumn<int> get year =>
      $composableBuilder(column: $table.year, builder: (column) => column);

  GeneratedColumn<String> get color =>
      $composableBuilder(column: $table.color, builder: (column) => column);

  GeneratedColumn<String> get fuel =>
      $composableBuilder(column: $table.fuel, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> vehicleObligationsRefs<T extends Object>(
    Expression<T> Function($$VehicleObligationsTableAnnotationComposer a) f,
  ) {
    final $$VehicleObligationsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.vehicleObligations,
          getReferencedColumn: (t) => t.vehicleId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$VehicleObligationsTableAnnotationComposer(
                $db: $db,
                $table: $db.vehicleObligations,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> maintenanceRecordsRefs<T extends Object>(
    Expression<T> Function($$MaintenanceRecordsTableAnnotationComposer a) f,
  ) {
    final $$MaintenanceRecordsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.maintenanceRecords,
          getReferencedColumn: (t) => t.vehicleId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$MaintenanceRecordsTableAnnotationComposer(
                $db: $db,
                $table: $db.maintenanceRecords,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> privateDocumentsRefs<T extends Object>(
    Expression<T> Function($$PrivateDocumentsTableAnnotationComposer a) f,
  ) {
    final $$PrivateDocumentsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.privateDocuments,
      getReferencedColumn: (t) => t.vehicleId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PrivateDocumentsTableAnnotationComposer(
            $db: $db,
            $table: $db.privateDocuments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$VehiclesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $VehiclesTable,
          Vehicle,
          $$VehiclesTableFilterComposer,
          $$VehiclesTableOrderingComposer,
          $$VehiclesTableAnnotationComposer,
          $$VehiclesTableCreateCompanionBuilder,
          $$VehiclesTableUpdateCompanionBuilder,
          (Vehicle, $$VehiclesTableReferences),
          Vehicle,
          PrefetchHooks Function({
            bool vehicleObligationsRefs,
            bool maintenanceRecordsRefs,
            bool privateDocumentsRefs,
          })
        > {
  $$VehiclesTableTableManager(_$AppDatabase db, $VehiclesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$VehiclesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$VehiclesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$VehiclesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> plate = const Value.absent(),
                Value<String?> nickname = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> serviceType = const Value.absent(),
                Value<String?> subtype = const Value.absent(),
                Value<String?> registrationCity = const Value.absent(),
                Value<String?> brand = const Value.absent(),
                Value<String?> model = const Value.absent(),
                Value<int?> year = const Value.absent(),
                Value<String?> color = const Value.absent(),
                Value<String?> fuel = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => VehiclesCompanion(
                id: id,
                plate: plate,
                nickname: nickname,
                kind: kind,
                serviceType: serviceType,
                subtype: subtype,
                registrationCity: registrationCity,
                brand: brand,
                model: model,
                year: year,
                color: color,
                fuel: fuel,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String plate,
                Value<String?> nickname = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> serviceType = const Value.absent(),
                Value<String?> subtype = const Value.absent(),
                Value<String?> registrationCity = const Value.absent(),
                Value<String?> brand = const Value.absent(),
                Value<String?> model = const Value.absent(),
                Value<int?> year = const Value.absent(),
                Value<String?> color = const Value.absent(),
                Value<String?> fuel = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => VehiclesCompanion.insert(
                id: id,
                plate: plate,
                nickname: nickname,
                kind: kind,
                serviceType: serviceType,
                subtype: subtype,
                registrationCity: registrationCity,
                brand: brand,
                model: model,
                year: year,
                color: color,
                fuel: fuel,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$VehiclesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                vehicleObligationsRefs = false,
                maintenanceRecordsRefs = false,
                privateDocumentsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (vehicleObligationsRefs) db.vehicleObligations,
                    if (maintenanceRecordsRefs) db.maintenanceRecords,
                    if (privateDocumentsRefs) db.privateDocuments,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (vehicleObligationsRefs)
                        await $_getPrefetchedData<
                          Vehicle,
                          $VehiclesTable,
                          VehicleObligation
                        >(
                          currentTable: table,
                          referencedTable: $$VehiclesTableReferences
                              ._vehicleObligationsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$VehiclesTableReferences(
                                db,
                                table,
                                p0,
                              ).vehicleObligationsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.vehicleId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (maintenanceRecordsRefs)
                        await $_getPrefetchedData<
                          Vehicle,
                          $VehiclesTable,
                          MaintenanceRecord
                        >(
                          currentTable: table,
                          referencedTable: $$VehiclesTableReferences
                              ._maintenanceRecordsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$VehiclesTableReferences(
                                db,
                                table,
                                p0,
                              ).maintenanceRecordsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.vehicleId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (privateDocumentsRefs)
                        await $_getPrefetchedData<
                          Vehicle,
                          $VehiclesTable,
                          PrivateDocument
                        >(
                          currentTable: table,
                          referencedTable: $$VehiclesTableReferences
                              ._privateDocumentsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$VehiclesTableReferences(
                                db,
                                table,
                                p0,
                              ).privateDocumentsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.vehicleId == item.id,
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

typedef $$VehiclesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $VehiclesTable,
      Vehicle,
      $$VehiclesTableFilterComposer,
      $$VehiclesTableOrderingComposer,
      $$VehiclesTableAnnotationComposer,
      $$VehiclesTableCreateCompanionBuilder,
      $$VehiclesTableUpdateCompanionBuilder,
      (Vehicle, $$VehiclesTableReferences),
      Vehicle,
      PrefetchHooks Function({
        bool vehicleObligationsRefs,
        bool maintenanceRecordsRefs,
        bool privateDocumentsRefs,
      })
    >;
typedef $$VehicleObligationsTableCreateCompanionBuilder =
    VehicleObligationsCompanion Function({
      required String id,
      required String vehicleId,
      required String type,
      required String status,
      Value<DateTime?> startDate,
      Value<DateTime?> dueDate,
      Value<String?> detailsJson,
      Value<bool> reminderEnabled,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });
typedef $$VehicleObligationsTableUpdateCompanionBuilder =
    VehicleObligationsCompanion Function({
      Value<String> id,
      Value<String> vehicleId,
      Value<String> type,
      Value<String> status,
      Value<DateTime?> startDate,
      Value<DateTime?> dueDate,
      Value<String?> detailsJson,
      Value<bool> reminderEnabled,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$VehicleObligationsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $VehicleObligationsTable,
          VehicleObligation
        > {
  $$VehicleObligationsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $VehiclesTable _vehicleIdTable(_$AppDatabase db) =>
      db.vehicles.createAlias('vehicle_obligations__vehicle_id__vehicles__id');

  $$VehiclesTableProcessedTableManager get vehicleId {
    final $_column = $_itemColumn<String>('vehicle_id')!;

    final manager = $$VehiclesTableTableManager(
      $_db,
      $_db.vehicles,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_vehicleIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$VehicleObligationsTableFilterComposer
    extends Composer<_$AppDatabase, $VehicleObligationsTable> {
  $$VehicleObligationsTableFilterComposer({
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

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startDate => $composableBuilder(
    column: $table.startDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get dueDate => $composableBuilder(
    column: $table.dueDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get detailsJson => $composableBuilder(
    column: $table.detailsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get reminderEnabled => $composableBuilder(
    column: $table.reminderEnabled,
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

  $$VehiclesTableFilterComposer get vehicleId {
    final $$VehiclesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.vehicleId,
      referencedTable: $db.vehicles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VehiclesTableFilterComposer(
            $db: $db,
            $table: $db.vehicles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$VehicleObligationsTableOrderingComposer
    extends Composer<_$AppDatabase, $VehicleObligationsTable> {
  $$VehicleObligationsTableOrderingComposer({
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

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startDate => $composableBuilder(
    column: $table.startDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get dueDate => $composableBuilder(
    column: $table.dueDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get detailsJson => $composableBuilder(
    column: $table.detailsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get reminderEnabled => $composableBuilder(
    column: $table.reminderEnabled,
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

  $$VehiclesTableOrderingComposer get vehicleId {
    final $$VehiclesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.vehicleId,
      referencedTable: $db.vehicles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VehiclesTableOrderingComposer(
            $db: $db,
            $table: $db.vehicles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$VehicleObligationsTableAnnotationComposer
    extends Composer<_$AppDatabase, $VehicleObligationsTable> {
  $$VehicleObligationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<DateTime> get startDate =>
      $composableBuilder(column: $table.startDate, builder: (column) => column);

  GeneratedColumn<DateTime> get dueDate =>
      $composableBuilder(column: $table.dueDate, builder: (column) => column);

  GeneratedColumn<String> get detailsJson => $composableBuilder(
    column: $table.detailsJson,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get reminderEnabled => $composableBuilder(
    column: $table.reminderEnabled,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$VehiclesTableAnnotationComposer get vehicleId {
    final $$VehiclesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.vehicleId,
      referencedTable: $db.vehicles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VehiclesTableAnnotationComposer(
            $db: $db,
            $table: $db.vehicles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$VehicleObligationsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $VehicleObligationsTable,
          VehicleObligation,
          $$VehicleObligationsTableFilterComposer,
          $$VehicleObligationsTableOrderingComposer,
          $$VehicleObligationsTableAnnotationComposer,
          $$VehicleObligationsTableCreateCompanionBuilder,
          $$VehicleObligationsTableUpdateCompanionBuilder,
          (VehicleObligation, $$VehicleObligationsTableReferences),
          VehicleObligation,
          PrefetchHooks Function({bool vehicleId})
        > {
  $$VehicleObligationsTableTableManager(
    _$AppDatabase db,
    $VehicleObligationsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$VehicleObligationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$VehicleObligationsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$VehicleObligationsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> vehicleId = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<DateTime?> startDate = const Value.absent(),
                Value<DateTime?> dueDate = const Value.absent(),
                Value<String?> detailsJson = const Value.absent(),
                Value<bool> reminderEnabled = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => VehicleObligationsCompanion(
                id: id,
                vehicleId: vehicleId,
                type: type,
                status: status,
                startDate: startDate,
                dueDate: dueDate,
                detailsJson: detailsJson,
                reminderEnabled: reminderEnabled,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String vehicleId,
                required String type,
                required String status,
                Value<DateTime?> startDate = const Value.absent(),
                Value<DateTime?> dueDate = const Value.absent(),
                Value<String?> detailsJson = const Value.absent(),
                Value<bool> reminderEnabled = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => VehicleObligationsCompanion.insert(
                id: id,
                vehicleId: vehicleId,
                type: type,
                status: status,
                startDate: startDate,
                dueDate: dueDate,
                detailsJson: detailsJson,
                reminderEnabled: reminderEnabled,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$VehicleObligationsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({vehicleId = false}) {
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
                    if (vehicleId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.vehicleId,
                        referencedTable: $$VehicleObligationsTableReferences
                            ._vehicleIdTable(db),
                        referencedColumn: $$VehicleObligationsTableReferences
                            ._vehicleIdTable(db)
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

typedef $$VehicleObligationsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $VehicleObligationsTable,
      VehicleObligation,
      $$VehicleObligationsTableFilterComposer,
      $$VehicleObligationsTableOrderingComposer,
      $$VehicleObligationsTableAnnotationComposer,
      $$VehicleObligationsTableCreateCompanionBuilder,
      $$VehicleObligationsTableUpdateCompanionBuilder,
      (VehicleObligation, $$VehicleObligationsTableReferences),
      VehicleObligation,
      PrefetchHooks Function({bool vehicleId})
    >;
typedef $$MaintenanceRecordsTableCreateCompanionBuilder =
    MaintenanceRecordsCompanion Function({
      required String id,
      required String vehicleId,
      required DateTime serviceDate,
      Value<int?> odometer,
      required String type,
      required String description,
      Value<int?> costCents,
      Value<DateTime?> nextServiceDate,
      Value<int?> nextOdometer,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });
typedef $$MaintenanceRecordsTableUpdateCompanionBuilder =
    MaintenanceRecordsCompanion Function({
      Value<String> id,
      Value<String> vehicleId,
      Value<DateTime> serviceDate,
      Value<int?> odometer,
      Value<String> type,
      Value<String> description,
      Value<int?> costCents,
      Value<DateTime?> nextServiceDate,
      Value<int?> nextOdometer,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$MaintenanceRecordsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $MaintenanceRecordsTable,
          MaintenanceRecord
        > {
  $$MaintenanceRecordsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $VehiclesTable _vehicleIdTable(_$AppDatabase db) =>
      db.vehicles.createAlias('maintenance_records__vehicle_id__vehicles__id');

  $$VehiclesTableProcessedTableManager get vehicleId {
    final $_column = $_itemColumn<String>('vehicle_id')!;

    final manager = $$VehiclesTableTableManager(
      $_db,
      $_db.vehicles,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_vehicleIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$MaintenanceRecordsTableFilterComposer
    extends Composer<_$AppDatabase, $MaintenanceRecordsTable> {
  $$MaintenanceRecordsTableFilterComposer({
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

  ColumnFilters<DateTime> get serviceDate => $composableBuilder(
    column: $table.serviceDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get odometer => $composableBuilder(
    column: $table.odometer,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get costCents => $composableBuilder(
    column: $table.costCents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get nextServiceDate => $composableBuilder(
    column: $table.nextServiceDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get nextOdometer => $composableBuilder(
    column: $table.nextOdometer,
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

  $$VehiclesTableFilterComposer get vehicleId {
    final $$VehiclesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.vehicleId,
      referencedTable: $db.vehicles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VehiclesTableFilterComposer(
            $db: $db,
            $table: $db.vehicles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MaintenanceRecordsTableOrderingComposer
    extends Composer<_$AppDatabase, $MaintenanceRecordsTable> {
  $$MaintenanceRecordsTableOrderingComposer({
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

  ColumnOrderings<DateTime> get serviceDate => $composableBuilder(
    column: $table.serviceDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get odometer => $composableBuilder(
    column: $table.odometer,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get costCents => $composableBuilder(
    column: $table.costCents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get nextServiceDate => $composableBuilder(
    column: $table.nextServiceDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get nextOdometer => $composableBuilder(
    column: $table.nextOdometer,
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

  $$VehiclesTableOrderingComposer get vehicleId {
    final $$VehiclesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.vehicleId,
      referencedTable: $db.vehicles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VehiclesTableOrderingComposer(
            $db: $db,
            $table: $db.vehicles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MaintenanceRecordsTableAnnotationComposer
    extends Composer<_$AppDatabase, $MaintenanceRecordsTable> {
  $$MaintenanceRecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get serviceDate => $composableBuilder(
    column: $table.serviceDate,
    builder: (column) => column,
  );

  GeneratedColumn<int> get odometer =>
      $composableBuilder(column: $table.odometer, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<int> get costCents =>
      $composableBuilder(column: $table.costCents, builder: (column) => column);

  GeneratedColumn<DateTime> get nextServiceDate => $composableBuilder(
    column: $table.nextServiceDate,
    builder: (column) => column,
  );

  GeneratedColumn<int> get nextOdometer => $composableBuilder(
    column: $table.nextOdometer,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$VehiclesTableAnnotationComposer get vehicleId {
    final $$VehiclesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.vehicleId,
      referencedTable: $db.vehicles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VehiclesTableAnnotationComposer(
            $db: $db,
            $table: $db.vehicles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MaintenanceRecordsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MaintenanceRecordsTable,
          MaintenanceRecord,
          $$MaintenanceRecordsTableFilterComposer,
          $$MaintenanceRecordsTableOrderingComposer,
          $$MaintenanceRecordsTableAnnotationComposer,
          $$MaintenanceRecordsTableCreateCompanionBuilder,
          $$MaintenanceRecordsTableUpdateCompanionBuilder,
          (MaintenanceRecord, $$MaintenanceRecordsTableReferences),
          MaintenanceRecord,
          PrefetchHooks Function({bool vehicleId})
        > {
  $$MaintenanceRecordsTableTableManager(
    _$AppDatabase db,
    $MaintenanceRecordsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MaintenanceRecordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MaintenanceRecordsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MaintenanceRecordsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> vehicleId = const Value.absent(),
                Value<DateTime> serviceDate = const Value.absent(),
                Value<int?> odometer = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String> description = const Value.absent(),
                Value<int?> costCents = const Value.absent(),
                Value<DateTime?> nextServiceDate = const Value.absent(),
                Value<int?> nextOdometer = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MaintenanceRecordsCompanion(
                id: id,
                vehicleId: vehicleId,
                serviceDate: serviceDate,
                odometer: odometer,
                type: type,
                description: description,
                costCents: costCents,
                nextServiceDate: nextServiceDate,
                nextOdometer: nextOdometer,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String vehicleId,
                required DateTime serviceDate,
                Value<int?> odometer = const Value.absent(),
                required String type,
                required String description,
                Value<int?> costCents = const Value.absent(),
                Value<DateTime?> nextServiceDate = const Value.absent(),
                Value<int?> nextOdometer = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MaintenanceRecordsCompanion.insert(
                id: id,
                vehicleId: vehicleId,
                serviceDate: serviceDate,
                odometer: odometer,
                type: type,
                description: description,
                costCents: costCents,
                nextServiceDate: nextServiceDate,
                nextOdometer: nextOdometer,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$MaintenanceRecordsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({vehicleId = false}) {
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
                    if (vehicleId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.vehicleId,
                        referencedTable: $$MaintenanceRecordsTableReferences
                            ._vehicleIdTable(db),
                        referencedColumn: $$MaintenanceRecordsTableReferences
                            ._vehicleIdTable(db)
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

typedef $$MaintenanceRecordsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MaintenanceRecordsTable,
      MaintenanceRecord,
      $$MaintenanceRecordsTableFilterComposer,
      $$MaintenanceRecordsTableOrderingComposer,
      $$MaintenanceRecordsTableAnnotationComposer,
      $$MaintenanceRecordsTableCreateCompanionBuilder,
      $$MaintenanceRecordsTableUpdateCompanionBuilder,
      (MaintenanceRecord, $$MaintenanceRecordsTableReferences),
      MaintenanceRecord,
      PrefetchHooks Function({bool vehicleId})
    >;
typedef $$NotificationPreferencesTableCreateCompanionBuilder =
    NotificationPreferencesCompanion Function({
      required String id,
      Value<bool> restrictionAlertsEnabled,
      Value<bool> obligationRemindersEnabled,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });
typedef $$NotificationPreferencesTableUpdateCompanionBuilder =
    NotificationPreferencesCompanion Function({
      Value<String> id,
      Value<bool> restrictionAlertsEnabled,
      Value<bool> obligationRemindersEnabled,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$NotificationPreferencesTableFilterComposer
    extends Composer<_$AppDatabase, $NotificationPreferencesTable> {
  $$NotificationPreferencesTableFilterComposer({
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

  ColumnFilters<bool> get restrictionAlertsEnabled => $composableBuilder(
    column: $table.restrictionAlertsEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get obligationRemindersEnabled => $composableBuilder(
    column: $table.obligationRemindersEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$NotificationPreferencesTableOrderingComposer
    extends Composer<_$AppDatabase, $NotificationPreferencesTable> {
  $$NotificationPreferencesTableOrderingComposer({
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

  ColumnOrderings<bool> get restrictionAlertsEnabled => $composableBuilder(
    column: $table.restrictionAlertsEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get obligationRemindersEnabled => $composableBuilder(
    column: $table.obligationRemindersEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$NotificationPreferencesTableAnnotationComposer
    extends Composer<_$AppDatabase, $NotificationPreferencesTable> {
  $$NotificationPreferencesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<bool> get restrictionAlertsEnabled => $composableBuilder(
    column: $table.restrictionAlertsEnabled,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get obligationRemindersEnabled => $composableBuilder(
    column: $table.obligationRemindersEnabled,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$NotificationPreferencesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $NotificationPreferencesTable,
          NotificationPreference,
          $$NotificationPreferencesTableFilterComposer,
          $$NotificationPreferencesTableOrderingComposer,
          $$NotificationPreferencesTableAnnotationComposer,
          $$NotificationPreferencesTableCreateCompanionBuilder,
          $$NotificationPreferencesTableUpdateCompanionBuilder,
          (
            NotificationPreference,
            BaseReferences<
              _$AppDatabase,
              $NotificationPreferencesTable,
              NotificationPreference
            >,
          ),
          NotificationPreference,
          PrefetchHooks Function()
        > {
  $$NotificationPreferencesTableTableManager(
    _$AppDatabase db,
    $NotificationPreferencesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$NotificationPreferencesTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$NotificationPreferencesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$NotificationPreferencesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<bool> restrictionAlertsEnabled = const Value.absent(),
                Value<bool> obligationRemindersEnabled = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => NotificationPreferencesCompanion(
                id: id,
                restrictionAlertsEnabled: restrictionAlertsEnabled,
                obligationRemindersEnabled: obligationRemindersEnabled,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<bool> restrictionAlertsEnabled = const Value.absent(),
                Value<bool> obligationRemindersEnabled = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => NotificationPreferencesCompanion.insert(
                id: id,
                restrictionAlertsEnabled: restrictionAlertsEnabled,
                obligationRemindersEnabled: obligationRemindersEnabled,
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

typedef $$NotificationPreferencesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $NotificationPreferencesTable,
      NotificationPreference,
      $$NotificationPreferencesTableFilterComposer,
      $$NotificationPreferencesTableOrderingComposer,
      $$NotificationPreferencesTableAnnotationComposer,
      $$NotificationPreferencesTableCreateCompanionBuilder,
      $$NotificationPreferencesTableUpdateCompanionBuilder,
      (
        NotificationPreference,
        BaseReferences<
          _$AppDatabase,
          $NotificationPreferencesTable,
          NotificationPreference
        >,
      ),
      NotificationPreference,
      PrefetchHooks Function()
    >;
typedef $$DatasetVersionsTableCreateCompanionBuilder =
    DatasetVersionsCompanion Function({
      required String id,
      required String datasetKey,
      required String version,
      Value<String?> sha256,
      required String status,
      Value<int> publicationRevision,
      Value<DateTime> appliedAt,
      Value<int> rowid,
    });
typedef $$DatasetVersionsTableUpdateCompanionBuilder =
    DatasetVersionsCompanion Function({
      Value<String> id,
      Value<String> datasetKey,
      Value<String> version,
      Value<String?> sha256,
      Value<String> status,
      Value<int> publicationRevision,
      Value<DateTime> appliedAt,
      Value<int> rowid,
    });

class $$DatasetVersionsTableFilterComposer
    extends Composer<_$AppDatabase, $DatasetVersionsTable> {
  $$DatasetVersionsTableFilterComposer({
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

  ColumnFilters<String> get datasetKey => $composableBuilder(
    column: $table.datasetKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sha256 => $composableBuilder(
    column: $table.sha256,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get publicationRevision => $composableBuilder(
    column: $table.publicationRevision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get appliedAt => $composableBuilder(
    column: $table.appliedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DatasetVersionsTableOrderingComposer
    extends Composer<_$AppDatabase, $DatasetVersionsTable> {
  $$DatasetVersionsTableOrderingComposer({
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

  ColumnOrderings<String> get datasetKey => $composableBuilder(
    column: $table.datasetKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sha256 => $composableBuilder(
    column: $table.sha256,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get publicationRevision => $composableBuilder(
    column: $table.publicationRevision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get appliedAt => $composableBuilder(
    column: $table.appliedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DatasetVersionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DatasetVersionsTable> {
  $$DatasetVersionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get datasetKey => $composableBuilder(
    column: $table.datasetKey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<String> get sha256 =>
      $composableBuilder(column: $table.sha256, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get publicationRevision => $composableBuilder(
    column: $table.publicationRevision,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get appliedAt =>
      $composableBuilder(column: $table.appliedAt, builder: (column) => column);
}

class $$DatasetVersionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DatasetVersionsTable,
          DatasetVersion,
          $$DatasetVersionsTableFilterComposer,
          $$DatasetVersionsTableOrderingComposer,
          $$DatasetVersionsTableAnnotationComposer,
          $$DatasetVersionsTableCreateCompanionBuilder,
          $$DatasetVersionsTableUpdateCompanionBuilder,
          (
            DatasetVersion,
            BaseReferences<
              _$AppDatabase,
              $DatasetVersionsTable,
              DatasetVersion
            >,
          ),
          DatasetVersion,
          PrefetchHooks Function()
        > {
  $$DatasetVersionsTableTableManager(
    _$AppDatabase db,
    $DatasetVersionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DatasetVersionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DatasetVersionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DatasetVersionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> datasetKey = const Value.absent(),
                Value<String> version = const Value.absent(),
                Value<String?> sha256 = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> publicationRevision = const Value.absent(),
                Value<DateTime> appliedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DatasetVersionsCompanion(
                id: id,
                datasetKey: datasetKey,
                version: version,
                sha256: sha256,
                status: status,
                publicationRevision: publicationRevision,
                appliedAt: appliedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String datasetKey,
                required String version,
                Value<String?> sha256 = const Value.absent(),
                required String status,
                Value<int> publicationRevision = const Value.absent(),
                Value<DateTime> appliedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DatasetVersionsCompanion.insert(
                id: id,
                datasetKey: datasetKey,
                version: version,
                sha256: sha256,
                status: status,
                publicationRevision: publicationRevision,
                appliedAt: appliedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DatasetVersionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DatasetVersionsTable,
      DatasetVersion,
      $$DatasetVersionsTableFilterComposer,
      $$DatasetVersionsTableOrderingComposer,
      $$DatasetVersionsTableAnnotationComposer,
      $$DatasetVersionsTableCreateCompanionBuilder,
      $$DatasetVersionsTableUpdateCompanionBuilder,
      (
        DatasetVersion,
        BaseReferences<_$AppDatabase, $DatasetVersionsTable, DatasetVersion>,
      ),
      DatasetVersion,
      PrefetchHooks Function()
    >;
typedef $$RestrictionCoveragesTableCreateCompanionBuilder =
    RestrictionCoveragesCompanion Function({
      required String id,
      required String jurisdictionId,
      required String jurisdictionName,
      required String vehicleKind,
      required String serviceType,
      required String rulesJson,
      required DateTime verifiedAt,
      required DateTime staleAfter,
      required String sourceUrlsJson,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });
typedef $$RestrictionCoveragesTableUpdateCompanionBuilder =
    RestrictionCoveragesCompanion Function({
      Value<String> id,
      Value<String> jurisdictionId,
      Value<String> jurisdictionName,
      Value<String> vehicleKind,
      Value<String> serviceType,
      Value<String> rulesJson,
      Value<DateTime> verifiedAt,
      Value<DateTime> staleAfter,
      Value<String> sourceUrlsJson,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$RestrictionCoveragesTableFilterComposer
    extends Composer<_$AppDatabase, $RestrictionCoveragesTable> {
  $$RestrictionCoveragesTableFilterComposer({
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

  ColumnFilters<String> get jurisdictionId => $composableBuilder(
    column: $table.jurisdictionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get jurisdictionName => $composableBuilder(
    column: $table.jurisdictionName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get vehicleKind => $composableBuilder(
    column: $table.vehicleKind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get serviceType => $composableBuilder(
    column: $table.serviceType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rulesJson => $composableBuilder(
    column: $table.rulesJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get verifiedAt => $composableBuilder(
    column: $table.verifiedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get staleAfter => $composableBuilder(
    column: $table.staleAfter,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceUrlsJson => $composableBuilder(
    column: $table.sourceUrlsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RestrictionCoveragesTableOrderingComposer
    extends Composer<_$AppDatabase, $RestrictionCoveragesTable> {
  $$RestrictionCoveragesTableOrderingComposer({
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

  ColumnOrderings<String> get jurisdictionId => $composableBuilder(
    column: $table.jurisdictionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get jurisdictionName => $composableBuilder(
    column: $table.jurisdictionName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get vehicleKind => $composableBuilder(
    column: $table.vehicleKind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get serviceType => $composableBuilder(
    column: $table.serviceType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rulesJson => $composableBuilder(
    column: $table.rulesJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get verifiedAt => $composableBuilder(
    column: $table.verifiedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get staleAfter => $composableBuilder(
    column: $table.staleAfter,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceUrlsJson => $composableBuilder(
    column: $table.sourceUrlsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RestrictionCoveragesTableAnnotationComposer
    extends Composer<_$AppDatabase, $RestrictionCoveragesTable> {
  $$RestrictionCoveragesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get jurisdictionId => $composableBuilder(
    column: $table.jurisdictionId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get jurisdictionName => $composableBuilder(
    column: $table.jurisdictionName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get vehicleKind => $composableBuilder(
    column: $table.vehicleKind,
    builder: (column) => column,
  );

  GeneratedColumn<String> get serviceType => $composableBuilder(
    column: $table.serviceType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get rulesJson =>
      $composableBuilder(column: $table.rulesJson, builder: (column) => column);

  GeneratedColumn<DateTime> get verifiedAt => $composableBuilder(
    column: $table.verifiedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get staleAfter => $composableBuilder(
    column: $table.staleAfter,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourceUrlsJson => $composableBuilder(
    column: $table.sourceUrlsJson,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$RestrictionCoveragesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RestrictionCoveragesTable,
          RestrictionCoverage,
          $$RestrictionCoveragesTableFilterComposer,
          $$RestrictionCoveragesTableOrderingComposer,
          $$RestrictionCoveragesTableAnnotationComposer,
          $$RestrictionCoveragesTableCreateCompanionBuilder,
          $$RestrictionCoveragesTableUpdateCompanionBuilder,
          (
            RestrictionCoverage,
            BaseReferences<
              _$AppDatabase,
              $RestrictionCoveragesTable,
              RestrictionCoverage
            >,
          ),
          RestrictionCoverage,
          PrefetchHooks Function()
        > {
  $$RestrictionCoveragesTableTableManager(
    _$AppDatabase db,
    $RestrictionCoveragesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RestrictionCoveragesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RestrictionCoveragesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$RestrictionCoveragesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> jurisdictionId = const Value.absent(),
                Value<String> jurisdictionName = const Value.absent(),
                Value<String> vehicleKind = const Value.absent(),
                Value<String> serviceType = const Value.absent(),
                Value<String> rulesJson = const Value.absent(),
                Value<DateTime> verifiedAt = const Value.absent(),
                Value<DateTime> staleAfter = const Value.absent(),
                Value<String> sourceUrlsJson = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RestrictionCoveragesCompanion(
                id: id,
                jurisdictionId: jurisdictionId,
                jurisdictionName: jurisdictionName,
                vehicleKind: vehicleKind,
                serviceType: serviceType,
                rulesJson: rulesJson,
                verifiedAt: verifiedAt,
                staleAfter: staleAfter,
                sourceUrlsJson: sourceUrlsJson,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String jurisdictionId,
                required String jurisdictionName,
                required String vehicleKind,
                required String serviceType,
                required String rulesJson,
                required DateTime verifiedAt,
                required DateTime staleAfter,
                required String sourceUrlsJson,
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RestrictionCoveragesCompanion.insert(
                id: id,
                jurisdictionId: jurisdictionId,
                jurisdictionName: jurisdictionName,
                vehicleKind: vehicleKind,
                serviceType: serviceType,
                rulesJson: rulesJson,
                verifiedAt: verifiedAt,
                staleAfter: staleAfter,
                sourceUrlsJson: sourceUrlsJson,
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

typedef $$RestrictionCoveragesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RestrictionCoveragesTable,
      RestrictionCoverage,
      $$RestrictionCoveragesTableFilterComposer,
      $$RestrictionCoveragesTableOrderingComposer,
      $$RestrictionCoveragesTableAnnotationComposer,
      $$RestrictionCoveragesTableCreateCompanionBuilder,
      $$RestrictionCoveragesTableUpdateCompanionBuilder,
      (
        RestrictionCoverage,
        BaseReferences<
          _$AppDatabase,
          $RestrictionCoveragesTable,
          RestrictionCoverage
        >,
      ),
      RestrictionCoverage,
      PrefetchHooks Function()
    >;
typedef $$DriverProfilesTableCreateCompanionBuilder =
    DriverProfilesCompanion Function({
      required String id,
      required int slot,
      required Uint8List encryptedMetadata,
      Value<int> rowid,
    });
typedef $$DriverProfilesTableUpdateCompanionBuilder =
    DriverProfilesCompanion Function({
      Value<String> id,
      Value<int> slot,
      Value<Uint8List> encryptedMetadata,
      Value<int> rowid,
    });

final class $$DriverProfilesTableReferences
    extends BaseReferences<_$AppDatabase, $DriverProfilesTable, DriverProfile> {
  $$DriverProfilesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<$PrivateDocumentsTable, List<PrivateDocument>>
  _privateDocumentsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.privateDocuments,
    aliasName: 'driver_profiles__id__private_documents__driver_id',
  );

  $$PrivateDocumentsTableProcessedTableManager get privateDocumentsRefs {
    final manager = $$PrivateDocumentsTableTableManager(
      $_db,
      $_db.privateDocuments,
    ).filter((f) => f.driverId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _privateDocumentsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$DriverProfilesTableFilterComposer
    extends Composer<_$AppDatabase, $DriverProfilesTable> {
  $$DriverProfilesTableFilterComposer({
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

  ColumnFilters<int> get slot => $composableBuilder(
    column: $table.slot,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get encryptedMetadata => $composableBuilder(
    column: $table.encryptedMetadata,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> privateDocumentsRefs(
    Expression<bool> Function($$PrivateDocumentsTableFilterComposer f) f,
  ) {
    final $$PrivateDocumentsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.privateDocuments,
      getReferencedColumn: (t) => t.driverId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PrivateDocumentsTableFilterComposer(
            $db: $db,
            $table: $db.privateDocuments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$DriverProfilesTableOrderingComposer
    extends Composer<_$AppDatabase, $DriverProfilesTable> {
  $$DriverProfilesTableOrderingComposer({
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

  ColumnOrderings<int> get slot => $composableBuilder(
    column: $table.slot,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get encryptedMetadata => $composableBuilder(
    column: $table.encryptedMetadata,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DriverProfilesTableAnnotationComposer
    extends Composer<_$AppDatabase, $DriverProfilesTable> {
  $$DriverProfilesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get slot =>
      $composableBuilder(column: $table.slot, builder: (column) => column);

  GeneratedColumn<Uint8List> get encryptedMetadata => $composableBuilder(
    column: $table.encryptedMetadata,
    builder: (column) => column,
  );

  Expression<T> privateDocumentsRefs<T extends Object>(
    Expression<T> Function($$PrivateDocumentsTableAnnotationComposer a) f,
  ) {
    final $$PrivateDocumentsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.privateDocuments,
      getReferencedColumn: (t) => t.driverId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PrivateDocumentsTableAnnotationComposer(
            $db: $db,
            $table: $db.privateDocuments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$DriverProfilesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DriverProfilesTable,
          DriverProfile,
          $$DriverProfilesTableFilterComposer,
          $$DriverProfilesTableOrderingComposer,
          $$DriverProfilesTableAnnotationComposer,
          $$DriverProfilesTableCreateCompanionBuilder,
          $$DriverProfilesTableUpdateCompanionBuilder,
          (DriverProfile, $$DriverProfilesTableReferences),
          DriverProfile,
          PrefetchHooks Function({bool privateDocumentsRefs})
        > {
  $$DriverProfilesTableTableManager(
    _$AppDatabase db,
    $DriverProfilesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DriverProfilesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DriverProfilesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DriverProfilesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> slot = const Value.absent(),
                Value<Uint8List> encryptedMetadata = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DriverProfilesCompanion(
                id: id,
                slot: slot,
                encryptedMetadata: encryptedMetadata,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required int slot,
                required Uint8List encryptedMetadata,
                Value<int> rowid = const Value.absent(),
              }) => DriverProfilesCompanion.insert(
                id: id,
                slot: slot,
                encryptedMetadata: encryptedMetadata,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$DriverProfilesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({privateDocumentsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (privateDocumentsRefs) db.privateDocuments,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (privateDocumentsRefs)
                    await $_getPrefetchedData<
                      DriverProfile,
                      $DriverProfilesTable,
                      PrivateDocument
                    >(
                      currentTable: table,
                      referencedTable: $$DriverProfilesTableReferences
                          ._privateDocumentsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$DriverProfilesTableReferences(
                            db,
                            table,
                            p0,
                          ).privateDocumentsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.driverId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$DriverProfilesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DriverProfilesTable,
      DriverProfile,
      $$DriverProfilesTableFilterComposer,
      $$DriverProfilesTableOrderingComposer,
      $$DriverProfilesTableAnnotationComposer,
      $$DriverProfilesTableCreateCompanionBuilder,
      $$DriverProfilesTableUpdateCompanionBuilder,
      (DriverProfile, $$DriverProfilesTableReferences),
      DriverProfile,
      PrefetchHooks Function({bool privateDocumentsRefs})
    >;
typedef $$WalletPreparationsTableCreateCompanionBuilder =
    WalletPreparationsCompanion Function({
      required String id,
      required Uint8List encryptedMetadata,
      Value<int> rowid,
    });
typedef $$WalletPreparationsTableUpdateCompanionBuilder =
    WalletPreparationsCompanion Function({
      Value<String> id,
      Value<Uint8List> encryptedMetadata,
      Value<int> rowid,
    });

final class $$WalletPreparationsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $WalletPreparationsTable,
          WalletPreparation
        > {
  $$WalletPreparationsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<$PrivateDocumentsTable, List<PrivateDocument>>
  _privateDocumentsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.privateDocuments,
    aliasName: 'wallet_preparations__id__private_documents__preparation_id',
  );

  $$PrivateDocumentsTableProcessedTableManager get privateDocumentsRefs {
    final manager = $$PrivateDocumentsTableTableManager(
      $_db,
      $_db.privateDocuments,
    ).filter((f) => f.preparationId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _privateDocumentsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$WalletPreparationsTableFilterComposer
    extends Composer<_$AppDatabase, $WalletPreparationsTable> {
  $$WalletPreparationsTableFilterComposer({
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

  ColumnFilters<Uint8List> get encryptedMetadata => $composableBuilder(
    column: $table.encryptedMetadata,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> privateDocumentsRefs(
    Expression<bool> Function($$PrivateDocumentsTableFilterComposer f) f,
  ) {
    final $$PrivateDocumentsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.privateDocuments,
      getReferencedColumn: (t) => t.preparationId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PrivateDocumentsTableFilterComposer(
            $db: $db,
            $table: $db.privateDocuments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$WalletPreparationsTableOrderingComposer
    extends Composer<_$AppDatabase, $WalletPreparationsTable> {
  $$WalletPreparationsTableOrderingComposer({
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

  ColumnOrderings<Uint8List> get encryptedMetadata => $composableBuilder(
    column: $table.encryptedMetadata,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$WalletPreparationsTableAnnotationComposer
    extends Composer<_$AppDatabase, $WalletPreparationsTable> {
  $$WalletPreparationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<Uint8List> get encryptedMetadata => $composableBuilder(
    column: $table.encryptedMetadata,
    builder: (column) => column,
  );

  Expression<T> privateDocumentsRefs<T extends Object>(
    Expression<T> Function($$PrivateDocumentsTableAnnotationComposer a) f,
  ) {
    final $$PrivateDocumentsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.privateDocuments,
      getReferencedColumn: (t) => t.preparationId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PrivateDocumentsTableAnnotationComposer(
            $db: $db,
            $table: $db.privateDocuments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$WalletPreparationsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WalletPreparationsTable,
          WalletPreparation,
          $$WalletPreparationsTableFilterComposer,
          $$WalletPreparationsTableOrderingComposer,
          $$WalletPreparationsTableAnnotationComposer,
          $$WalletPreparationsTableCreateCompanionBuilder,
          $$WalletPreparationsTableUpdateCompanionBuilder,
          (WalletPreparation, $$WalletPreparationsTableReferences),
          WalletPreparation,
          PrefetchHooks Function({bool privateDocumentsRefs})
        > {
  $$WalletPreparationsTableTableManager(
    _$AppDatabase db,
    $WalletPreparationsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WalletPreparationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WalletPreparationsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WalletPreparationsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<Uint8List> encryptedMetadata = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WalletPreparationsCompanion(
                id: id,
                encryptedMetadata: encryptedMetadata,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required Uint8List encryptedMetadata,
                Value<int> rowid = const Value.absent(),
              }) => WalletPreparationsCompanion.insert(
                id: id,
                encryptedMetadata: encryptedMetadata,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$WalletPreparationsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({privateDocumentsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (privateDocumentsRefs) db.privateDocuments,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (privateDocumentsRefs)
                    await $_getPrefetchedData<
                      WalletPreparation,
                      $WalletPreparationsTable,
                      PrivateDocument
                    >(
                      currentTable: table,
                      referencedTable: $$WalletPreparationsTableReferences
                          ._privateDocumentsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$WalletPreparationsTableReferences(
                            db,
                            table,
                            p0,
                          ).privateDocumentsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where(
                            (e) => e.preparationId == item.id,
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

typedef $$WalletPreparationsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WalletPreparationsTable,
      WalletPreparation,
      $$WalletPreparationsTableFilterComposer,
      $$WalletPreparationsTableOrderingComposer,
      $$WalletPreparationsTableAnnotationComposer,
      $$WalletPreparationsTableCreateCompanionBuilder,
      $$WalletPreparationsTableUpdateCompanionBuilder,
      (WalletPreparation, $$WalletPreparationsTableReferences),
      WalletPreparation,
      PrefetchHooks Function({bool privateDocumentsRefs})
    >;
typedef $$PrivateDocumentsTableCreateCompanionBuilder =
    PrivateDocumentsCompanion Function({
      required String id,
      Value<String?> driverId,
      Value<String?> vehicleId,
      Value<String?> preparationId,
      required String type,
      required Uint8List encryptedMetadata,
      Value<DateTime> importedAt,
      Value<int> rowid,
    });
typedef $$PrivateDocumentsTableUpdateCompanionBuilder =
    PrivateDocumentsCompanion Function({
      Value<String> id,
      Value<String?> driverId,
      Value<String?> vehicleId,
      Value<String?> preparationId,
      Value<String> type,
      Value<Uint8List> encryptedMetadata,
      Value<DateTime> importedAt,
      Value<int> rowid,
    });

final class $$PrivateDocumentsTableReferences
    extends
        BaseReferences<_$AppDatabase, $PrivateDocumentsTable, PrivateDocument> {
  $$PrivateDocumentsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $DriverProfilesTable _driverIdTable(_$AppDatabase db) => db
      .driverProfiles
      .createAlias('private_documents__driver_id__driver_profiles__id');

  $$DriverProfilesTableProcessedTableManager? get driverId {
    final $_column = $_itemColumn<String>('driver_id');
    if ($_column == null) return null;
    final manager = $$DriverProfilesTableTableManager(
      $_db,
      $_db.driverProfiles,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_driverIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $VehiclesTable _vehicleIdTable(_$AppDatabase db) =>
      db.vehicles.createAlias('private_documents__vehicle_id__vehicles__id');

  $$VehiclesTableProcessedTableManager? get vehicleId {
    final $_column = $_itemColumn<String>('vehicle_id');
    if ($_column == null) return null;
    final manager = $$VehiclesTableTableManager(
      $_db,
      $_db.vehicles,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_vehicleIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $WalletPreparationsTable _preparationIdTable(_$AppDatabase db) =>
      db.walletPreparations.createAlias(
        'private_documents__preparation_id__wallet_preparations__id',
      );

  $$WalletPreparationsTableProcessedTableManager? get preparationId {
    final $_column = $_itemColumn<String>('preparation_id');
    if ($_column == null) return null;
    final manager = $$WalletPreparationsTableTableManager(
      $_db,
      $_db.walletPreparations,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_preparationIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$PrivateDocumentsTableFilterComposer
    extends Composer<_$AppDatabase, $PrivateDocumentsTable> {
  $$PrivateDocumentsTableFilterComposer({
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

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get encryptedMetadata => $composableBuilder(
    column: $table.encryptedMetadata,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get importedAt => $composableBuilder(
    column: $table.importedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$DriverProfilesTableFilterComposer get driverId {
    final $$DriverProfilesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.driverId,
      referencedTable: $db.driverProfiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DriverProfilesTableFilterComposer(
            $db: $db,
            $table: $db.driverProfiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$VehiclesTableFilterComposer get vehicleId {
    final $$VehiclesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.vehicleId,
      referencedTable: $db.vehicles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VehiclesTableFilterComposer(
            $db: $db,
            $table: $db.vehicles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$WalletPreparationsTableFilterComposer get preparationId {
    final $$WalletPreparationsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.preparationId,
      referencedTable: $db.walletPreparations,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WalletPreparationsTableFilterComposer(
            $db: $db,
            $table: $db.walletPreparations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PrivateDocumentsTableOrderingComposer
    extends Composer<_$AppDatabase, $PrivateDocumentsTable> {
  $$PrivateDocumentsTableOrderingComposer({
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

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get encryptedMetadata => $composableBuilder(
    column: $table.encryptedMetadata,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get importedAt => $composableBuilder(
    column: $table.importedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$DriverProfilesTableOrderingComposer get driverId {
    final $$DriverProfilesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.driverId,
      referencedTable: $db.driverProfiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DriverProfilesTableOrderingComposer(
            $db: $db,
            $table: $db.driverProfiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$VehiclesTableOrderingComposer get vehicleId {
    final $$VehiclesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.vehicleId,
      referencedTable: $db.vehicles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VehiclesTableOrderingComposer(
            $db: $db,
            $table: $db.vehicles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$WalletPreparationsTableOrderingComposer get preparationId {
    final $$WalletPreparationsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.preparationId,
      referencedTable: $db.walletPreparations,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WalletPreparationsTableOrderingComposer(
            $db: $db,
            $table: $db.walletPreparations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PrivateDocumentsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PrivateDocumentsTable> {
  $$PrivateDocumentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<Uint8List> get encryptedMetadata => $composableBuilder(
    column: $table.encryptedMetadata,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get importedAt => $composableBuilder(
    column: $table.importedAt,
    builder: (column) => column,
  );

  $$DriverProfilesTableAnnotationComposer get driverId {
    final $$DriverProfilesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.driverId,
      referencedTable: $db.driverProfiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DriverProfilesTableAnnotationComposer(
            $db: $db,
            $table: $db.driverProfiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$VehiclesTableAnnotationComposer get vehicleId {
    final $$VehiclesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.vehicleId,
      referencedTable: $db.vehicles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VehiclesTableAnnotationComposer(
            $db: $db,
            $table: $db.vehicles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$WalletPreparationsTableAnnotationComposer get preparationId {
    final $$WalletPreparationsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.preparationId,
          referencedTable: $db.walletPreparations,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$WalletPreparationsTableAnnotationComposer(
                $db: $db,
                $table: $db.walletPreparations,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }
}

class $$PrivateDocumentsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PrivateDocumentsTable,
          PrivateDocument,
          $$PrivateDocumentsTableFilterComposer,
          $$PrivateDocumentsTableOrderingComposer,
          $$PrivateDocumentsTableAnnotationComposer,
          $$PrivateDocumentsTableCreateCompanionBuilder,
          $$PrivateDocumentsTableUpdateCompanionBuilder,
          (PrivateDocument, $$PrivateDocumentsTableReferences),
          PrivateDocument,
          PrefetchHooks Function({
            bool driverId,
            bool vehicleId,
            bool preparationId,
          })
        > {
  $$PrivateDocumentsTableTableManager(
    _$AppDatabase db,
    $PrivateDocumentsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PrivateDocumentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PrivateDocumentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PrivateDocumentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> driverId = const Value.absent(),
                Value<String?> vehicleId = const Value.absent(),
                Value<String?> preparationId = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<Uint8List> encryptedMetadata = const Value.absent(),
                Value<DateTime> importedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PrivateDocumentsCompanion(
                id: id,
                driverId: driverId,
                vehicleId: vehicleId,
                preparationId: preparationId,
                type: type,
                encryptedMetadata: encryptedMetadata,
                importedAt: importedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> driverId = const Value.absent(),
                Value<String?> vehicleId = const Value.absent(),
                Value<String?> preparationId = const Value.absent(),
                required String type,
                required Uint8List encryptedMetadata,
                Value<DateTime> importedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PrivateDocumentsCompanion.insert(
                id: id,
                driverId: driverId,
                vehicleId: vehicleId,
                preparationId: preparationId,
                type: type,
                encryptedMetadata: encryptedMetadata,
                importedAt: importedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$PrivateDocumentsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({driverId = false, vehicleId = false, preparationId = false}) {
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
                        if (driverId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.driverId,
                            referencedTable: $$PrivateDocumentsTableReferences
                                ._driverIdTable(db),
                            referencedColumn: $$PrivateDocumentsTableReferences
                                ._driverIdTable(db)
                                .id,
                          ) as T;
                        }
                        if (vehicleId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.vehicleId,
                            referencedTable: $$PrivateDocumentsTableReferences
                                ._vehicleIdTable(db),
                            referencedColumn: $$PrivateDocumentsTableReferences
                                ._vehicleIdTable(db)
                                .id,
                          ) as T;
                        }
                        if (preparationId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.preparationId,
                            referencedTable: $$PrivateDocumentsTableReferences
                                ._preparationIdTable(db),
                            referencedColumn: $$PrivateDocumentsTableReferences
                                ._preparationIdTable(db)
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

typedef $$PrivateDocumentsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PrivateDocumentsTable,
      PrivateDocument,
      $$PrivateDocumentsTableFilterComposer,
      $$PrivateDocumentsTableOrderingComposer,
      $$PrivateDocumentsTableAnnotationComposer,
      $$PrivateDocumentsTableCreateCompanionBuilder,
      $$PrivateDocumentsTableUpdateCompanionBuilder,
      (PrivateDocument, $$PrivateDocumentsTableReferences),
      PrivateDocument,
      PrefetchHooks Function({
        bool driverId,
        bool vehicleId,
        bool preparationId,
      })
    >;
typedef $$WalletMigrationsTableCreateCompanionBuilder =
    WalletMigrationsCompanion Function({
      required String id,
      required Uint8List encryptedMetadata,
      Value<DateTime> completedAt,
      Value<int> rowid,
    });
typedef $$WalletMigrationsTableUpdateCompanionBuilder =
    WalletMigrationsCompanion Function({
      Value<String> id,
      Value<Uint8List> encryptedMetadata,
      Value<DateTime> completedAt,
      Value<int> rowid,
    });

class $$WalletMigrationsTableFilterComposer
    extends Composer<_$AppDatabase, $WalletMigrationsTable> {
  $$WalletMigrationsTableFilterComposer({
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

  ColumnFilters<Uint8List> get encryptedMetadata => $composableBuilder(
    column: $table.encryptedMetadata,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$WalletMigrationsTableOrderingComposer
    extends Composer<_$AppDatabase, $WalletMigrationsTable> {
  $$WalletMigrationsTableOrderingComposer({
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

  ColumnOrderings<Uint8List> get encryptedMetadata => $composableBuilder(
    column: $table.encryptedMetadata,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$WalletMigrationsTableAnnotationComposer
    extends Composer<_$AppDatabase, $WalletMigrationsTable> {
  $$WalletMigrationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<Uint8List> get encryptedMetadata => $composableBuilder(
    column: $table.encryptedMetadata,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => column,
  );
}

class $$WalletMigrationsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WalletMigrationsTable,
          WalletMigration,
          $$WalletMigrationsTableFilterComposer,
          $$WalletMigrationsTableOrderingComposer,
          $$WalletMigrationsTableAnnotationComposer,
          $$WalletMigrationsTableCreateCompanionBuilder,
          $$WalletMigrationsTableUpdateCompanionBuilder,
          (
            WalletMigration,
            BaseReferences<
              _$AppDatabase,
              $WalletMigrationsTable,
              WalletMigration
            >,
          ),
          WalletMigration,
          PrefetchHooks Function()
        > {
  $$WalletMigrationsTableTableManager(
    _$AppDatabase db,
    $WalletMigrationsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WalletMigrationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WalletMigrationsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WalletMigrationsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<Uint8List> encryptedMetadata = const Value.absent(),
                Value<DateTime> completedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WalletMigrationsCompanion(
                id: id,
                encryptedMetadata: encryptedMetadata,
                completedAt: completedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required Uint8List encryptedMetadata,
                Value<DateTime> completedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WalletMigrationsCompanion.insert(
                id: id,
                encryptedMetadata: encryptedMetadata,
                completedAt: completedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$WalletMigrationsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WalletMigrationsTable,
      WalletMigration,
      $$WalletMigrationsTableFilterComposer,
      $$WalletMigrationsTableOrderingComposer,
      $$WalletMigrationsTableAnnotationComposer,
      $$WalletMigrationsTableCreateCompanionBuilder,
      $$WalletMigrationsTableUpdateCompanionBuilder,
      (
        WalletMigration,
        BaseReferences<_$AppDatabase, $WalletMigrationsTable, WalletMigration>,
      ),
      WalletMigration,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$VehiclesTableTableManager get vehicles =>
      $$VehiclesTableTableManager(_db, _db.vehicles);
  $$VehicleObligationsTableTableManager get vehicleObligations =>
      $$VehicleObligationsTableTableManager(_db, _db.vehicleObligations);
  $$MaintenanceRecordsTableTableManager get maintenanceRecords =>
      $$MaintenanceRecordsTableTableManager(_db, _db.maintenanceRecords);
  $$NotificationPreferencesTableTableManager get notificationPreferences =>
      $$NotificationPreferencesTableTableManager(
        _db,
        _db.notificationPreferences,
      );
  $$DatasetVersionsTableTableManager get datasetVersions =>
      $$DatasetVersionsTableTableManager(_db, _db.datasetVersions);
  $$RestrictionCoveragesTableTableManager get restrictionCoverages =>
      $$RestrictionCoveragesTableTableManager(_db, _db.restrictionCoverages);
  $$DriverProfilesTableTableManager get driverProfiles =>
      $$DriverProfilesTableTableManager(_db, _db.driverProfiles);
  $$WalletPreparationsTableTableManager get walletPreparations =>
      $$WalletPreparationsTableTableManager(_db, _db.walletPreparations);
  $$PrivateDocumentsTableTableManager get privateDocuments =>
      $$PrivateDocumentsTableTableManager(_db, _db.privateDocuments);
  $$WalletMigrationsTableTableManager get walletMigrations =>
      $$WalletMigrationsTableTableManager(_db, _db.walletMigrations);
}
