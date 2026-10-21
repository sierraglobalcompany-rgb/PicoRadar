import 'dart:convert';
import 'dart:math';

import '../../../core/storage/app_preferences.dart';

const buySellDraftPreferenceKey = 'buy_sell.draft.v1';
const _buySellDraftSchemaVersion = 4;

String newPurchasePreparationId() {
  final random = Random.secure();
  return 'purchase-${base64Url.encode(List.generate(18, (_) => random.nextInt(256)))}';
}

class PurchaseConsultationContext {
  const PurchaseConsultationContext({
    this.preparationId = '',
    this.taxAuthorityId = '',
    this.transitAuthorityId = '',
    this.comparendosAuthorityId = '',
  });

  final String preparationId;
  final String taxAuthorityId;
  final String transitAuthorityId;
  final String comparendosAuthorityId;

  PurchaseConsultationContext copyWith({
    String? preparationId,
    String? taxAuthorityId,
    String? transitAuthorityId,
    String? comparendosAuthorityId,
  }) => PurchaseConsultationContext(
    preparationId: preparationId ?? this.preparationId,
    taxAuthorityId: taxAuthorityId ?? this.taxAuthorityId,
    transitAuthorityId: transitAuthorityId ?? this.transitAuthorityId,
    comparendosAuthorityId:
        comparendosAuthorityId ?? this.comparendosAuthorityId,
  );

  Map<String, Object?> toJson() => {
    'preparationId': preparationId,
    'taxAuthorityId': taxAuthorityId,
    'transitAuthorityId': transitAuthorityId,
    'comparendosAuthorityId': comparendosAuthorityId,
  };

  factory PurchaseConsultationContext.fromJson(Object? value) {
    if (value == null) return const PurchaseConsultationContext();
    if (value is! Map) throw const FormatException('Invalid purchase context.');
    String field(String key) {
      final item = value[key];
      if (item != null && item is! String) {
        throw const FormatException('Invalid purchase context field.');
      }
      return item as String? ?? '';
    }

    return PurchaseConsultationContext(
      preparationId: field('preparationId'),
      taxAuthorityId: field('taxAuthorityId'),
      transitAuthorityId: field('transitAuthorityId'),
      comparendosAuthorityId: field('comparendosAuthorityId'),
    );
  }
}

class BuySellPurchaseSnapshot {
  const BuySellPurchaseSnapshot({
    required this.context,
    required this.candidate,
    required this.preparation,
    required this.legacyAttachment,
    required this.contract,
  });
  final PurchaseConsultationContext context;
  final BuySellCandidateVehicle candidate;
  final BuySellPreparation preparation;
  final BuySellRegistrationAttachment legacyAttachment;
  final BuySellContractDraft contract;
  Map<String, Object?> toJson() => {
    'context': context.toJson(),
    'candidate': candidate.toJson(),
    'preparation': preparation.toJson(),
    'legacyAttachment': legacyAttachment.toJson(),
    'contract': contract.toJson(),
  };
  factory BuySellPurchaseSnapshot.fromJson(Object? value) {
    if (value is! Map) {
      throw const FormatException('Invalid preparation archive.');
    }
    return BuySellPurchaseSnapshot(
      context: PurchaseConsultationContext.fromJson(value['context']),
      candidate: BuySellCandidateVehicle.fromJson(value['candidate']),
      preparation: BuySellPreparation.fromJson(value['preparation']),
      legacyAttachment: BuySellRegistrationAttachment.fromJson(
        value['legacyAttachment'],
      ),
      contract: BuySellContractDraft.fromJson(value['contract']),
    );
  }
}

const buySellMandatoryCopy =
    'Esta preparacion no certifica el estado juridico, mecanico o tributario del vehiculo.';

abstract final class BuySellPreparationStepIds {
  static const comparendos = 'comparendos';
  static const taxes = 'taxes';
  static const transfer = 'transfer';
  static const appraisal = 'appraisal';
  static const documents = 'documents';
  static const paymentDelivery = 'paymentDelivery';

  static const buy = {
    comparendos,
    taxes,
    transfer,
    appraisal,
    documents,
    paymentDelivery,
  };
}

enum BuySellMode {
  buy('buy', 'Comprar'),
  sell('sell', 'Vender');

  const BuySellMode(this.value, this.label);

  final String value;
  final String label;

  static BuySellMode? tryFromValue(String value) {
    return switch (value) {
      'buy' => BuySellMode.buy,
      'sell' => BuySellMode.sell,
      _ => null,
    };
  }
}

class BuySellPreparation {
  const BuySellPreparation({this.notes = '', this.checkedItems = const {}});

  final String notes;
  final Set<String> checkedItems;

  BuySellPreparation copyWith({String? notes, Set<String>? checkedItems}) {
    return BuySellPreparation(
      notes: notes ?? this.notes,
      checkedItems: checkedItems ?? this.checkedItems,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'notes': notes.trim(),
      'checkedItems': checkedItems.toList()..sort(),
    };
  }

  static BuySellPreparation fromJson(Object? source) {
    if (source is! Map) {
      return const BuySellPreparation();
    }
    final notes = source['notes'];
    final checked = source['checkedItems'];
    if (notes is! String || checked is! List) {
      throw const FormatException('Invalid buy/sell preparation field type.');
    }
    final checkedItems = <String>{};
    for (final item in checked) {
      if (item is! String) {
        throw const FormatException('Invalid buy/sell preparation item.');
      }
      checkedItems.add(_normalizePreparationItem(item));
    }
    return BuySellPreparation(notes: notes, checkedItems: checkedItems);
  }
}

class BuySellCandidateVehicle {
  const BuySellCandidateVehicle({
    this.plate = '',
    this.brandLine = '',
    this.modelYear = '',
    this.registrationCity = '',
    this.registrationCityConfirmed = false,
    this.notes = '',
  });

  final String plate;
  final String brandLine;
  final String modelYear;
  final String registrationCity;
  final bool registrationCityConfirmed;
  final String notes;

  bool get isEmpty {
    return [
      plate,
      brandLine,
      modelYear,
      registrationCity,
      notes,
    ].every((value) => value.trim().isEmpty);
  }

  BuySellCandidateVehicle copyWith({
    String? plate,
    String? brandLine,
    String? modelYear,
    String? registrationCity,
    bool? registrationCityConfirmed,
    String? notes,
  }) {
    return BuySellCandidateVehicle(
      plate: plate ?? this.plate,
      brandLine: brandLine ?? this.brandLine,
      modelYear: modelYear ?? this.modelYear,
      registrationCity: registrationCity ?? this.registrationCity,
      registrationCityConfirmed:
          registrationCityConfirmed ?? this.registrationCityConfirmed,
      notes: notes ?? this.notes,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'plate': plate.trim(),
      'brandLine': brandLine.trim(),
      'modelYear': modelYear.trim(),
      'registrationCity': registrationCity.trim(),
      'registrationCityConfirmed': registrationCityConfirmed,
      'notes': notes.trim(),
    };
  }

  static BuySellCandidateVehicle fromJson(
    Object? source, {
    String legacyPlate = '',
    String legacyCity = '',
  }) {
    if (source == null) {
      return BuySellCandidateVehicle(
        plate: legacyPlate,
        registrationCity: legacyCity,
      );
    }
    if (source is! Map) {
      throw const FormatException('Invalid buy/sell candidate vehicle.');
    }

    String stringField(String name) {
      final value = source[name];
      if (value == null) {
        return '';
      }
      if (value is! String) {
        throw const FormatException(
          'Invalid buy/sell candidate vehicle field.',
        );
      }
      return value;
    }

    return BuySellCandidateVehicle(
      plate: stringField('plate'),
      brandLine: stringField('brandLine'),
      modelYear: stringField('modelYear'),
      registrationCity: stringField('registrationCity'),
      registrationCityConfirmed: source['registrationCityConfirmed'] == true,
      notes: stringField('notes'),
    );
  }
}

class BuySellRegistrationAttachment {
  const BuySellRegistrationAttachment({
    this.frontImage = false,
    this.backImage = false,
    this.pdf = false,
    this.note = '',
  });

  final bool frontImage;
  final bool backImage;
  final bool pdf;
  final String note;

  bool get hasAny => frontImage || backImage || pdf;

  String get statusLabel {
    if (hasAny) return 'Copia pendiente de importar';
    return 'Sin matrícula adjunta';
  }

  BuySellRegistrationAttachment copyWith({
    bool? frontImage,
    bool? backImage,
    bool? pdf,
    String? note,
  }) {
    return BuySellRegistrationAttachment(
      frontImage: frontImage ?? this.frontImage,
      backImage: backImage ?? this.backImage,
      pdf: pdf ?? this.pdf,
      note: note ?? this.note,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'frontImage': frontImage,
      'backImage': backImage,
      'pdf': pdf,
      'note': note.trim(),
    };
  }

  static BuySellRegistrationAttachment fromJson(Object? source) {
    if (source == null) {
      return const BuySellRegistrationAttachment();
    }
    if (source is! Map) {
      throw const FormatException('Invalid buy/sell registration attachment.');
    }

    bool boolField(String name) {
      final value = source[name];
      if (value == null) {
        return false;
      }
      if (value is! bool) {
        throw const FormatException(
          'Invalid buy/sell registration attachment field.',
        );
      }
      return value;
    }

    final note = source['note'];
    if (note != null && note is! String) {
      throw const FormatException(
        'Invalid buy/sell registration attachment note.',
      );
    }

    return BuySellRegistrationAttachment(
      frontImage: boolField('frontImage'),
      backImage: boolField('backImage'),
      pdf: boolField('pdf'),
      note: note as String? ?? '',
    );
  }
}

class BuySellContractDraft {
  const BuySellContractDraft({
    this.vehiclePlate = '',
    this.vehicleDescription = '',
    this.buyerName = '',
    this.sellerName = '',
    this.city = '',
    this.price = '',
    this.date = '',
    this.notes = '',
  });

  final String vehiclePlate;
  final String vehicleDescription;
  final String buyerName;
  final String sellerName;
  final String city;
  final String price;
  final String date;
  final String notes;

  bool get isEmpty {
    return [
      vehiclePlate,
      vehicleDescription,
      buyerName,
      sellerName,
      city,
      price,
      date,
      notes,
    ].every((value) => value.trim().isEmpty);
  }

  BuySellContractDraft copyWith({
    String? vehiclePlate,
    String? vehicleDescription,
    String? buyerName,
    String? sellerName,
    String? city,
    String? price,
    String? date,
    String? notes,
  }) {
    return BuySellContractDraft(
      vehiclePlate: vehiclePlate ?? this.vehiclePlate,
      vehicleDescription: vehicleDescription ?? this.vehicleDescription,
      buyerName: buyerName ?? this.buyerName,
      sellerName: sellerName ?? this.sellerName,
      city: city ?? this.city,
      price: price ?? this.price,
      date: date ?? this.date,
      notes: notes ?? this.notes,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'vehiclePlate': vehiclePlate.trim(),
      'vehicleDescription': vehicleDescription.trim(),
      'buyerName': buyerName.trim(),
      'sellerName': sellerName.trim(),
      'city': city.trim(),
      'price': price.trim(),
      'date': date.trim(),
      'notes': notes.trim(),
    };
  }

  static BuySellContractDraft fromJson(Object? source) {
    if (source is! Map) {
      return const BuySellContractDraft();
    }
    String stringField(String name) {
      final value = source[name];
      if (value == null) {
        return '';
      }
      if (value is! String) {
        throw const FormatException('Invalid buy/sell contract field type.');
      }
      return value;
    }

    return BuySellContractDraft(
      vehiclePlate: stringField('vehiclePlate'),
      vehicleDescription: stringField('vehicleDescription'),
      buyerName: stringField('buyerName'),
      sellerName: stringField('sellerName'),
      city: stringField('city'),
      price: stringField('price'),
      date: stringField('date'),
      notes: stringField('notes'),
    );
  }
}

class BuySellDraft {
  const BuySellDraft({
    this.purchaseContext = const PurchaseConsultationContext(),
    this.archivedPurchases = const [],
    required this.mode,
    required this.candidatePlate,
    required this.city,
    required this.candidateVehicle,
    required this.candidateRegistrationAttachment,
    required this.preparations,
    required this.contract,
  });

  factory BuySellDraft.empty() {
    return const BuySellDraft(
      mode: BuySellMode.buy,
      candidatePlate: '',
      city: '',
      candidateVehicle: BuySellCandidateVehicle(),
      candidateRegistrationAttachment: BuySellRegistrationAttachment(),
      preparations: {
        BuySellMode.buy: BuySellPreparation(),
        BuySellMode.sell: BuySellPreparation(),
      },
      contract: BuySellContractDraft(),
    );
  }

  final BuySellMode mode;
  final PurchaseConsultationContext purchaseContext;
  final List<BuySellPurchaseSnapshot> archivedPurchases;
  final String candidatePlate;
  final String city;
  final BuySellCandidateVehicle candidateVehicle;
  final BuySellRegistrationAttachment candidateRegistrationAttachment;
  final Map<BuySellMode, BuySellPreparation> preparations;
  final BuySellContractDraft contract;

  String get notes => preparationFor(mode).notes;

  Set<String> get checkedItems => preparationFor(mode).checkedItems;

  BuySellPreparation preparationFor(BuySellMode mode) {
    return preparations[mode] ?? const BuySellPreparation();
  }

  BuySellDraft copyWith({
    PurchaseConsultationContext? purchaseContext,
    List<BuySellPurchaseSnapshot>? archivedPurchases,
    BuySellMode? mode,
    String? candidatePlate,
    String? city,
    BuySellCandidateVehicle? candidateVehicle,
    BuySellRegistrationAttachment? candidateRegistrationAttachment,
    Map<BuySellMode, BuySellPreparation>? preparations,
    BuySellContractDraft? contract,
  }) {
    return BuySellDraft(
      purchaseContext: purchaseContext ?? this.purchaseContext,
      archivedPurchases: archivedPurchases ?? this.archivedPurchases,
      mode: mode ?? this.mode,
      candidatePlate: candidatePlate ?? this.candidatePlate,
      city: city ?? this.city,
      candidateVehicle: candidateVehicle ?? this.candidateVehicle,
      candidateRegistrationAttachment:
          candidateRegistrationAttachment ??
          this.candidateRegistrationAttachment,
      preparations: preparations ?? this.preparations,
      contract: contract ?? this.contract,
    );
  }

  BuySellDraft updatePreparation(
    BuySellMode mode,
    BuySellPreparation preparation,
  ) {
    return copyWith(preparations: {...preparations, mode: preparation});
  }

  String toJsonString() {
    return jsonEncode({
      'version': _buySellDraftSchemaVersion,
      'purchaseContext': purchaseContext.toJson(),
      'archivedPurchases': archivedPurchases
          .map((item) => item.toJson())
          .toList(),
      'mode': mode.value,
      'candidatePlate': candidatePlate.trim(),
      'city': city.trim(),
      'candidateVehicle': candidateVehicle.toJson(),
      'candidateRegistrationAttachment': candidateRegistrationAttachment
          .toJson(),
      'preparations': {
        for (final entry in preparations.entries)
          entry.key.value: entry.value.toJson(),
      },
      'contract': contract.toJson(),
    });
  }

  static BuySellDraft fromJsonString(String source) {
    final data = jsonDecode(source);
    if (data is! Map) {
      throw const FormatException('Buy/sell draft must be an object.');
    }
    final version = data['version'];
    if (version == 1) {
      return _fromLegacyJson(data);
    }
    if (version != 2 && version != 3 && version != _buySellDraftSchemaVersion) {
      throw const FormatException('Unsupported buy/sell draft version.');
    }
    if (version == 4 &&
        (data['purchaseContext'] is! Map ||
            data['archivedPurchases'] is! List)) {
      throw const FormatException('Missing preparation ownership structure.');
    }
    if (version == 4 &&
        (data['purchaseContext'] as Map)['preparationId'] is! String) {
      throw const FormatException('Missing preparation identity field.');
    }
    if (version == 4) {
      void requireObjects(Map source, List<String> keys) {
        for (final key in keys) {
          if (source[key] is! Map) {
            throw const FormatException(
              'Invalid nested preparation structure.',
            );
          }
        }
      }

      void validateCandidate(Map candidate) {
        final confirmed = candidate['registrationCityConfirmed'];
        if (confirmed != null && confirmed is! bool) {
          throw const FormatException('Invalid registration confirmation.');
        }
      }

      requireObjects(data, [
        'candidateVehicle',
        'candidateRegistrationAttachment',
        'preparations',
        'contract',
      ]);
      requireObjects(data['preparations'] as Map, ['buy', 'sell']);
      validateCandidate(data['candidateVehicle'] as Map);
      for (final archive in data['archivedPurchases'] as List) {
        if (archive is! Map) {
          throw const FormatException('Invalid preparation archive.');
        }
        requireObjects(archive, [
          'context',
          'candidate',
          'preparation',
          'legacyAttachment',
          'contract',
        ]);
        validateCandidate(archive['candidate'] as Map);
      }
    }
    final mode = _readMode(data['mode']);
    final candidatePlate = data['candidatePlate'];
    final city = data['city'];
    final preparationsSource = data['preparations'];
    if (candidatePlate is! String ||
        city is! String ||
        preparationsSource is! Map) {
      throw const FormatException('Invalid buy/sell draft field type.');
    }
    final preparations = <BuySellMode, BuySellPreparation>{};
    for (final mode in BuySellMode.values) {
      preparations[mode] = BuySellPreparation.fromJson(
        preparationsSource[mode.value],
      );
    }
    final consultation = PurchaseConsultationContext.fromJson(
      data['purchaseContext'],
    );
    final archiveSource = data['archivedPurchases'];
    if (archiveSource != null && archiveSource is! List) {
      throw const FormatException('Invalid preparation archive list.');
    }
    final archives = [
      for (final item in (archiveSource as List? ?? const []))
        BuySellPurchaseSnapshot.fromJson(item),
    ];
    final identities = {consultation.preparationId};
    for (final snapshot in archives) {
      final id = snapshot.context.preparationId;
      if (id.isEmpty || !identities.add(id)) {
        throw const FormatException('Preparation owners must be distinct.');
      }
    }
    return BuySellDraft(
      purchaseContext: consultation,
      archivedPurchases: archives,
      mode: mode,
      candidatePlate: candidatePlate,
      city: city,
      candidateVehicle: BuySellCandidateVehicle.fromJson(
        data['candidateVehicle'],
        legacyPlate: candidatePlate,
        legacyCity: city,
      ),
      candidateRegistrationAttachment: BuySellRegistrationAttachment.fromJson(
        data['candidateRegistrationAttachment'],
      ),
      preparations: preparations,
      contract: BuySellContractDraft.fromJson(data['contract']),
    );
  }

  static BuySellDraft _fromLegacyJson(Map<dynamic, dynamic> data) {
    final mode = _readMode(data['mode']);
    final candidatePlate = data['candidatePlate'];
    final city = data['city'];
    final notes = data['notes'];
    final checked = data['checkedItems'];
    if (candidatePlate is! String ||
        city is! String ||
        notes is! String ||
        checked is! List) {
      throw const FormatException('Invalid legacy buy/sell draft field type.');
    }
    final checkedItems = <String>{};
    for (final item in checked) {
      if (item is! String) {
        throw const FormatException('Invalid buy/sell draft checklist item.');
      }
      checkedItems.add(_normalizePreparationItem(item));
    }
    final preparations = {
      BuySellMode.buy: const BuySellPreparation(),
      BuySellMode.sell: const BuySellPreparation(),
      mode: BuySellPreparation(notes: notes, checkedItems: checkedItems),
    };
    return BuySellDraft(
      mode: mode,
      candidatePlate: candidatePlate,
      city: city,
      candidateVehicle: BuySellCandidateVehicle(
        plate: candidatePlate,
        registrationCity: city,
      ),
      candidateRegistrationAttachment: const BuySellRegistrationAttachment(),
      preparations: preparations,
      contract: const BuySellContractDraft(),
    );
  }

  static BuySellMode _readMode(Object? source) {
    if (source is! String) {
      throw const FormatException('Buy/sell draft mode must be a string.');
    }
    final mode = BuySellMode.tryFromValue(source);
    if (mode == null) {
      throw const FormatException('Unsupported buy/sell draft mode.');
    }
    return mode;
  }
}

String _normalizePreparationItem(String item) {
  return switch (item) {
    'Revisar comparendos y obligaciones.' =>
      BuySellPreparationStepIds.comparendos,
    'Consultar SIMIT y autoridad territorial.' =>
      BuySellPreparationStepIds.comparendos,
    'Confirmar requisitos de traspaso.' => BuySellPreparationStepIds.transfer,
    'Agendar peritaje antes de pagar.' => BuySellPreparationStepIds.appraisal,
    'Revisar SOAT, tecnomecánica y documentos.' =>
      BuySellPreparationStepIds.documents,
    'Acordar forma de pago verificable.' =>
      BuySellPreparationStepIds.paymentDelivery,
    'Preparar comparendos y paz y salvo.' =>
      BuySellPreparationStepIds.comparendos,
    'Confirmar impuestos y obligaciones.' => BuySellPreparationStepIds.taxes,
    'Organizar SOAT, tecnomecánica y documentos.' =>
      BuySellPreparationStepIds.documents,
    'Tener peritaje o revisión disponible.' =>
      BuySellPreparationStepIds.appraisal,
    'Preparar texto de compraventa.' => 'saleContract',
    'Coordinar cita y traspaso.' => BuySellPreparationStepIds.transfer,
    _ => item,
  };
}

Future<BuySellDraft?> loadBuySellDraft(AppPreferences preferences) async {
  final source = await preferences.getString(buySellDraftPreferenceKey);
  if (source == null || source.trim().isEmpty) {
    return null;
  }
  try {
    return BuySellDraft.fromJsonString(source);
  } on FormatException {
    rethrow;
  } on TypeError {
    throw const FormatException(
      'Invalid buy/sell draft. Previous data preserved.',
    );
  }
}

Future<void> saveBuySellDraft(
  AppPreferences preferences,
  BuySellDraft draft,
) async {
  // Invalid persisted data must remain available for explicit recovery.
  await loadBuySellDraft(preferences);
  await preferences.setString(buySellDraftPreferenceKey, draft.toJsonString());
}

Future<void> deleteBuySellDraft(AppPreferences preferences) {
  return preferences.remove(buySellDraftPreferenceKey);
}
