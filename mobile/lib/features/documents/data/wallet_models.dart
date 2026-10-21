import 'dart:io';

import '../../vehicle_status/data/private_vehicle_document_store.dart';

enum WalletDocumentSide { front, back, pdf }

class WalletAuthorizationException implements Exception {
  const WalletAuthorizationException();

  @override
  String toString() => 'WalletAuthorizationException';
}

enum WalletDocumentType {
  driverLicense('driver_license', 'Licencia de conducci\u00f3n'),
  identityCard('identity_card', 'C\u00e9dula de ciudadan\u00eda'),
  trafficLicense('traffic_license', 'Licencia de tr\u00e1nsito'),
  soat('soat', 'SOAT'),
  rtm('rtm', 'Tecnomec\u00e1nica'),
  voluntaryInsurance('voluntary_insurance', 'Seguro voluntario'),
  salePurchase('sale_purchase', 'Compraventa'),
  appraisal('appraisal', 'Peritaje'),
  other('other', 'Otro');

  const WalletDocumentType(this.value, this.label);
  final String value;
  final String label;
  bool get isDriverDocument => this == driverLicense || this == identityCard;
  bool get supportsTwoSides => isDriverDocument || this == trafficLicense;

  static WalletDocumentType fromValue(String value) =>
      values.firstWhere((type) => type.value == value);
}

class WalletOwner {
  const WalletOwner.driver(String id)
    : driverId = id,
      vehicleId = null,
      preparationId = null;
  const WalletOwner.vehicle(String id)
    : vehicleId = id,
      driverId = null,
      preparationId = null;
  const WalletOwner.preparation(String id)
    : preparationId = id,
      driverId = null,
      vehicleId = null;

  final String? driverId;
  final String? vehicleId;
  final String? preparationId;
  bool get isDriver => driverId != null;
  bool get isPreparation => preparationId != null;
  String get id => driverId ?? vehicleId ?? preparationId!;

  @override
  bool operator ==(Object other) =>
      other is WalletOwner &&
      other.driverId == driverId &&
      other.vehicleId == vehicleId &&
      other.preparationId == preparationId;
  @override
  int get hashCode => Object.hash(driverId, vehicleId, preparationId);
}

class WalletDriver {
  const WalletDriver({
    required this.id,
    required this.displayName,
    required this.isPrincipal,
  });
  final String id;
  final String displayName;
  final bool isPrincipal;
}

class WalletDocumentInput {
  const WalletDocumentInput({
    required this.source,
    required this.originalName,
    required this.mimeType,
  });
  final File source;
  final String originalName;
  final String mimeType;
}

class WalletFileRef {
  const WalletFileRef({
    required this.encryptedRelativePath,
    required this.originalName,
    required this.mimeType,
    this.legacyMetadata,
  });
  final String encryptedRelativePath;
  final String originalName;
  final String mimeType;
  final PrivateVehicleDocumentMetadata? legacyMetadata;

  Map<String, Object?> toJson() => {
    'path': encryptedRelativePath,
    'name': originalName,
    'mime': mimeType,
    if (legacyMetadata != null) 'legacy': legacyMetadata!.toJson(),
  };

  factory WalletFileRef.fromJson(Map<String, Object?> json) => WalletFileRef(
    encryptedRelativePath: json['path']! as String,
    originalName: json['name']! as String,
    mimeType: json['mime']! as String,
    legacyMetadata: json['legacy'] == null
        ? null
        : PrivateVehicleDocumentMetadata.fromJson(
            Map<String, Object?>.from(json['legacy']! as Map),
          ),
  );
}

class WalletDocument {
  WalletDocument({
    required this.id,
    required this.owner,
    required this.type,
    required this.importedAt,
    this.front,
    this.back,
    this.pdf,
    Map<String, String> metadata = const {},
  }) : metadata = Map.unmodifiable(metadata);
  final String id;
  final WalletOwner owner;
  final WalletDocumentType type;
  final DateTime importedAt;
  final WalletFileRef? front;
  final WalletFileRef? back;
  final WalletFileRef? pdf;
  final Map<String, String> metadata;

  WalletFileRef? fileFor(WalletDocumentSide side) => switch (side) {
    WalletDocumentSide.front => front,
    WalletDocumentSide.back => back,
    WalletDocumentSide.pdf => pdf,
  };
  List<WalletDocumentSide> get sides => [
    for (final side in WalletDocumentSide.values)
      if (fileFor(side) != null) side,
  ];
}

class WalletMigrationReport {
  const WalletMigrationReport({
    this.importedCount = 0,
    this.orphanedCount = 0,
    this.pendingCleanupCount = 0,
    this.unreadableRecordCount = 0,
    this.migrationFailed = false,
  });
  final int importedCount;
  final int orphanedCount;
  final int pendingCleanupCount;
  final int unreadableRecordCount;
  final bool migrationFailed;
  bool get needsRecovery =>
      orphanedCount > 0 ||
      pendingCleanupCount > 0 ||
      unreadableRecordCount > 0 ||
      migrationFailed;
}
