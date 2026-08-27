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
    dueDate,
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
    if (data.containsKey('due_date')) {
      context.handle(
        _dueDateMeta,
        dueDate.isAcceptableOrUnknown(data['due_date']!, _dueDateMeta),
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
      dueDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}due_date'],
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
  final DateTime? dueDate;
  final DateTime createdAt;
  final DateTime updatedAt;
  const VehicleObligation({
    required this.id,
    required this.vehicleId,
    required this.type,
    required this.status,
    this.dueDate,
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
    if (!nullToAbsent || dueDate != null) {
      map['due_date'] = Variable<DateTime>(dueDate);
    }
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
      dueDate: dueDate == null && nullToAbsent
          ? const Value.absent()
          : Value(dueDate),
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
      dueDate: serializer.fromJson<DateTime?>(json['dueDate']),
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
      'dueDate': serializer.toJson<DateTime?>(dueDate),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  VehicleObligation copyWith({
    String? id,
    String? vehicleId,
    String? type,
    String? status,
    Value<DateTime?> dueDate = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => VehicleObligation(
    id: id ?? this.id,
    vehicleId: vehicleId ?? this.vehicleId,
    type: type ?? this.type,
    status: status ?? this.status,
    dueDate: dueDate.present ? dueDate.value : this.dueDate,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  VehicleObligation copyWithCompanion(VehicleObligationsCompanion data) {
    return VehicleObligation(
      id: data.id.present ? data.id.value : this.id,
      vehicleId: data.vehicleId.present ? data.vehicleId.value : this.vehicleId,
      type: data.type.present ? data.type.value : this.type,
      status: data.status.present ? data.status.value : this.status,
      dueDate: data.dueDate.present ? data.dueDate.value : this.dueDate,
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
          ..write('dueDate: $dueDate, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, vehicleId, type, status, dueDate, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is VehicleObligation &&
          other.id == this.id &&
          other.vehicleId == this.vehicleId &&
          other.type == this.type &&
          other.status == this.status &&
          other.dueDate == this.dueDate &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class VehicleObligationsCompanion extends UpdateCompanion<VehicleObligation> {
  final Value<String> id;
  final Value<String> vehicleId;
  final Value<String> type;
  final Value<String> status;
  final Value<DateTime?> dueDate;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const VehicleObligationsCompanion({
    this.id = const Value.absent(),
    this.vehicleId = const Value.absent(),
    this.type = const Value.absent(),
    this.status = const Value.absent(),
    this.dueDate = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  VehicleObligationsCompanion.insert({
    required String id,
    required String vehicleId,
    required String type,
    required String status,
    this.dueDate = const Value.absent(),
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
    Expression<DateTime>? dueDate,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (vehicleId != null) 'vehicle_id': vehicleId,
      if (type != null) 'type': type,
      if (status != null) 'status': status,
      if (dueDate != null) 'due_date': dueDate,
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
    Value<DateTime?>? dueDate,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return VehicleObligationsCompanion(
      id: id ?? this.id,
      vehicleId: vehicleId ?? this.vehicleId,
      type: type ?? this.type,
      status: status ?? this.status,
      dueDate: dueDate ?? this.dueDate,
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
    if (dueDate.present) {
      map['due_date'] = Variable<DateTime>(dueDate.value);
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
          ..write('dueDate: $dueDate, ')
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
  final DateTime appliedAt;
  const DatasetVersion({
    required this.id,
    required this.datasetKey,
    required this.version,
    this.sha256,
    required this.status,
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
      'appliedAt': serializer.toJson<DateTime>(appliedAt),
    };
  }

  DatasetVersion copyWith({
    String? id,
    String? datasetKey,
    String? version,
    Value<String?> sha256 = const Value.absent(),
    String? status,
    DateTime? appliedAt,
  }) => DatasetVersion(
    id: id ?? this.id,
    datasetKey: datasetKey ?? this.datasetKey,
    version: version ?? this.version,
    sha256: sha256.present ? sha256.value : this.sha256,
    status: status ?? this.status,
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
          ..write('appliedAt: $appliedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, datasetKey, version, sha256, status, appliedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DatasetVersion &&
          other.id == this.id &&
          other.datasetKey == this.datasetKey &&
          other.version == this.version &&
          other.sha256 == this.sha256 &&
          other.status == this.status &&
          other.appliedAt == this.appliedAt);
}

class DatasetVersionsCompanion extends UpdateCompanion<DatasetVersion> {
  final Value<String> id;
  final Value<String> datasetKey;
  final Value<String> version;
  final Value<String?> sha256;
  final Value<String> status;
  final Value<DateTime> appliedAt;
  final Value<int> rowid;
  const DatasetVersionsCompanion({
    this.id = const Value.absent(),
    this.datasetKey = const Value.absent(),
    this.version = const Value.absent(),
    this.sha256 = const Value.absent(),
    this.status = const Value.absent(),
    this.appliedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DatasetVersionsCompanion.insert({
    required String id,
    required String datasetKey,
    required String version,
    this.sha256 = const Value.absent(),
    required String status,
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
    Expression<DateTime>? appliedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (datasetKey != null) 'dataset_key': datasetKey,
      if (version != null) 'version': version,
      if (sha256 != null) 'sha256': sha256,
      if (status != null) 'status': status,
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
    Value<DateTime>? appliedAt,
    Value<int>? rowid,
  }) {
    return DatasetVersionsCompanion(
      id: id ?? this.id,
      datasetKey: datasetKey ?? this.datasetKey,
      version: version ?? this.version,
      sha256: sha256 ?? this.sha256,
      status: status ?? this.status,
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

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $VehiclesTable vehicles = $VehiclesTable(this);
  late final $VehicleObligationsTable vehicleObligations =
      $VehicleObligationsTable(this);
  late final $NotificationPreferencesTable notificationPreferences =
      $NotificationPreferencesTable(this);
  late final $DatasetVersionsTable datasetVersions = $DatasetVersionsTable(
    this,
  );
  late final $RestrictionCoveragesTable restrictionCoverages =
      $RestrictionCoveragesTable(this);
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
  late final Index datasetVersionsDatasetKeyIdx = Index(
    'dataset_versions_dataset_key_idx',
    'CREATE UNIQUE INDEX dataset_versions_dataset_key_idx ON dataset_versions (dataset_key)',
  );
  late final Index restrictionCoveragesLookupIdx = Index(
    'restriction_coverages_lookup_idx',
    'CREATE UNIQUE INDEX restriction_coverages_lookup_idx ON restriction_coverages (jurisdiction_id, vehicle_kind, service_type)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    vehicles,
    vehicleObligations,
    notificationPreferences,
    datasetVersions,
    restrictionCoverages,
    vehiclesPlateIdx,
    vehicleObligationsVehicleIdIdx,
    vehicleObligationsDueDateIdx,
    datasetVersionsDatasetKeyIdx,
    restrictionCoveragesLookupIdx,
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
          PrefetchHooks Function({bool vehicleObligationsRefs})
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
          prefetchHooksCallback: ({vehicleObligationsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (vehicleObligationsRefs) db.vehicleObligations,
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
                      managerFromTypedResult: (p0) => $$VehiclesTableReferences(
                        db,
                        table,
                        p0,
                      ).vehicleObligationsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.vehicleId == item.id),
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
      PrefetchHooks Function({bool vehicleObligationsRefs})
    >;
typedef $$VehicleObligationsTableCreateCompanionBuilder =
    VehicleObligationsCompanion Function({
      required String id,
      required String vehicleId,
      required String type,
      required String status,
      Value<DateTime?> dueDate,
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
      Value<DateTime?> dueDate,
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

  ColumnFilters<DateTime> get dueDate => $composableBuilder(
    column: $table.dueDate,
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

  ColumnOrderings<DateTime> get dueDate => $composableBuilder(
    column: $table.dueDate,
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

  GeneratedColumn<DateTime> get dueDate =>
      $composableBuilder(column: $table.dueDate, builder: (column) => column);

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
                Value<DateTime?> dueDate = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => VehicleObligationsCompanion(
                id: id,
                vehicleId: vehicleId,
                type: type,
                status: status,
                dueDate: dueDate,
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
                Value<DateTime?> dueDate = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => VehicleObligationsCompanion.insert(
                id: id,
                vehicleId: vehicleId,
                type: type,
                status: status,
                dueDate: dueDate,
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
                Value<DateTime> appliedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DatasetVersionsCompanion(
                id: id,
                datasetKey: datasetKey,
                version: version,
                sha256: sha256,
                status: status,
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
                Value<DateTime> appliedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DatasetVersionsCompanion.insert(
                id: id,
                datasetKey: datasetKey,
                version: version,
                sha256: sha256,
                status: status,
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

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$VehiclesTableTableManager get vehicles =>
      $$VehiclesTableTableManager(_db, _db.vehicles);
  $$VehicleObligationsTableTableManager get vehicleObligations =>
      $$VehicleObligationsTableTableManager(_db, _db.vehicleObligations);
  $$NotificationPreferencesTableTableManager get notificationPreferences =>
      $$NotificationPreferencesTableTableManager(
        _db,
        _db.notificationPreferences,
      );
  $$DatasetVersionsTableTableManager get datasetVersions =>
      $$DatasetVersionsTableTableManager(_db, _db.datasetVersions);
  $$RestrictionCoveragesTableTableManager get restrictionCoverages =>
      $$RestrictionCoveragesTableTableManager(_db, _db.restrictionCoverages);
}
