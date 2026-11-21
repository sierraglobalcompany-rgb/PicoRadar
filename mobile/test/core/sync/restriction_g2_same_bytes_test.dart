import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:picoradar/app/app_providers.dart';
import 'package:picoradar/features/pico_placa/data/pico_jurisdiction_catalog.dart';
import 'package:picoradar/features/trip/data/trip_municipality_catalog.dart';
import 'package:picoradar/core/config/app_config.dart';
import 'package:picoradar/core/database/app_database.dart';
import 'package:picoradar/core/storage/app_preferences.dart';
import 'package:picoradar/core/sync/dataset_sync_service.dart';
import 'package:picoradar/features/garage/data/vehicle_profile.dart';
import 'package:picoradar/features/pico_placa/data/restriction_dataset.dart';
import 'package:picoradar/features/pico_placa/data/restriction_store.dart';
import 'package:picoradar/features/pico_placa/domain/restriction_engine.dart';
import 'package:picoradar/features/pico_placa/domain/restriction_rule.dart';

void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  late AppDatabase db;
  late _MemoryPreferences preferences;
  late _Loopback server;
  late Directory tempDirectory;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    preferences = _MemoryPreferences();
    server = await _Loopback.start();
    tempDirectory = await Directory.systemTemp.createTemp('picoradar-g2-sync-');
  });

  tearDown(() async {
    await server.close();
    await db.close();
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test('Laravel schema2 release SHA reaches loopback Flutter import and survives failures', () async {
    final evidenceDirectory = Directory(
      Platform.environment['PICORADAR_G2_V3_EVIDENCE_DIR'] ?? '',
    );
    expect(await evidenceDirectory.exists(), isTrue);
    final releaseFile = File(
      '${evidenceDirectory.path}/PHP_G2_V3_REAL_LAB_RELEASE.json',
    );
    final manifestFile = File(
      '${evidenceDirectory.path}/PHP_G2_V3_REAL_LAB_MANIFEST.json',
    );
    expect(await releaseFile.exists(), isTrue);
    expect(await manifestFile.exists(), isTrue);
    final releaseBytes = await releaseFile.readAsBytes();
    final manifestBytes = await manifestFile.readAsBytes();
    final release = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(releaseBytes)) as Map,
    );
    final manifest = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(manifestBytes)) as Map,
    );
    final entry = Map<String, dynamic>.from(
      (manifest['datasets'] as Map)['restrictions'] as Map,
    );
    final actualSha = await _sha256(releaseBytes);
    expect(entry['sha256'], actualSha);
    expect(release['schemaVersion'], 2);

    await db
        .into(db.vehicles)
        .insert(
          VehiclesCompanion.insert(id: 'synthetic-user-row', plate: 'SYN123'),
        );
    await db
        .into(db.notificationPreferences)
        .insert(
          NotificationPreferencesCompanion.insert(
            id: 'synthetic-user-preferences',
          ),
        );
    await db
        .into(db.restrictionCoverages)
        .insert(
          RestrictionCoveragesCompanion.insert(
            id: 'co-legacy:car:private',
            jurisdictionId: 'co-legacy',
            jurisdictionName: 'Synthetic legacy city',
            vehicleKind: 'car',
            serviceType: 'private',
            rulesJson: '[]',
            verifiedAt: DateTime.utc(2026, 11, 1),
            staleAfter: DateTime.utc(2026, 12, 1),
            sourceUrlsJson: '["https://example.test/legacy"]',
          ),
        );

    server.serve('/v1/manifest.json', manifestBytes, etag: '"php-g2-manifest"');
    server.serve(Uri.parse(entry['url'] as String).path, releaseBytes);
    final service = _service(
      db,
      preferences,
      tempDirectory,
      server,
      now: DateTime.parse(manifest['generatedAt'] as String)
          .add(const Duration(seconds: 1)),
    );
    final result = await service.sync();
    expect(result.imported, ['restrictions']);

    final installed = await db.select(db.restrictionCoverages).get();
    expect(installed, hasLength(13));
    expect(
      installed.where((row) => row.jurisdictionId != 'co-g2-synthetic'),
      hasLength(12),
    );
    final partialRows = installed
        .where((row) => row.coverageCompleteness == 'partial')
        .toList();
    expect(partialRows, hasLength(1));
    expect(partialRows.single.jurisdictionId, 'co-g2-synthetic');
    expect(partialRows.single.rulesJson, contains('inside_scope_ref'));
    final installedVersion = await db.select(db.datasetVersions).getSingle();
    expect(installedVersion.sha256, actualSha);
    expect(installedVersion.version, entry['version']);
    expect(installedVersion.publicationRevision, entry['publicationRevision']);
    expect((await db.select(db.vehicles).get()).single.plate, 'SYN123');
    expect(
      (await db.select(db.notificationPreferences).get()).single.id,
      'synthetic-user-preferences',
    );
    final lastGoodVehicle = await db.select(db.vehicles).getSingle();
    final lastGoodPreferences = await db
        .select(db.notificationPreferences)
        .getSingle();

    final loaded = await RestrictionStore(db).loadCoverage(
      'co-g2-synthetic',
      VehicleKind.truck,
      VehicleServiceType.publicCargo,
      DateTime.utc(2026, 11, 10),
    );
    expect(loaded.coverageCompleteness, CoverageCompleteness.partial);
    final context = RestrictionContext(
      jurisdictionId: 'co-g2-synthetic',
      plate: 'SYN123',
      vehicleKind: VehicleKind.truck,
      serviceType: VehicleServiceType.publicCargo,
      registrationOrigin: RegistrationOrigin.unknown,
      localDateTime: DateTime(2026, 11, 10, 7),
      isHoliday: false,
      coverageKnown: loaded.coverageKnown,
      dataIsStale: loaded.dataIsStale,
      coverageCompleteness: loaded.coverageCompleteness,
      facts: const RestrictionFacts(
        grossVehicleWeightKg: 8501,
        spatialEvidence: SpatialEvidence(
          scopeId: 'co-dc-bogota-zone1',
          scopeVersion: '2026-lab',
          membership: SpatialMembership.inside,
          provenance: SpatialEvidenceProvenance.syntheticContext,
        ),
      ),
    );
    expect(
      const RestrictionEngine().evaluate(context, loaded.rules).status,
      RestrictionStatus.restricted,
    );

    final rowsBeforeFailure = await db.select(db.restrictionCoverages).get();
    final versionBeforeFailure = await db
        .select(db.datasetVersions)
        .getSingle();

    final hashFailureManifest = Map<String, dynamic>.from(manifest);
    final hashFailureEntry = Map<String, dynamic>.from(
      (hashFailureManifest['datasets'] as Map)['restrictions'] as Map,
    )..['version'] = 'r2-hash-failure';
    hashFailureEntry['publicationRevision'] =
        versionBeforeFailure.publicationRevision + 1;
    hashFailureEntry['sha256'] = '0' * 64;
    (hashFailureManifest['datasets'] as Map)['restrictions'] = hashFailureEntry;
    server.serve(
      '/v1/manifest.json',
      utf8.encode(jsonEncode(hashFailureManifest)),
    );
    await expectLater(service.sync(), throwsA(isA<DatasetSyncException>()));
    expect(await db.select(db.restrictionCoverages).get(), rowsBeforeFailure);
    expect(
      await db.select(db.datasetVersions).getSingle(),
      versionBeforeFailure,
    );

    final invalidRelease = Map<String, dynamic>.from(release);
    final jurisdictions = (invalidRelease['jurisdictions'] as List).cast<Map>();
    final invalidJurisdiction = Map<String, dynamic>.from(
      jurisdictions.singleWhere((city) => city['id'] == 'co-g2-synthetic'),
    );
    final invalidCoverage = Map<String, dynamic>.from(
      (invalidJurisdiction['coverages'] as List).single as Map,
    );
    final invalidRule = Map<String, dynamic>.from(
      (invalidCoverage['rules'] as List).single as Map,
    );
    final invalidConditions = List<Map<String, dynamic>>.from(
      (invalidRule['conditions'] as List).map(
        (value) => Map<String, dynamic>.from(value as Map),
      ),
    );
    invalidConditions.first['type'] = 'future_operator';
    invalidRule['conditions'] = invalidConditions;
    invalidCoverage['rules'] = [invalidRule];
    invalidJurisdiction['coverages'] = [invalidCoverage];
    invalidRelease['jurisdictions'] = [
      for (final city in jurisdictions)
        city['id'] == 'co-g2-synthetic' ? invalidJurisdiction : city,
    ];
    invalidRelease['version'] = 'r2-invalid-condition';
    final invalidBytes = utf8.encode(jsonEncode(invalidRelease));
    final invalidManifest = Map<String, dynamic>.from(manifest);
    final invalidEntry =
        Map<String, dynamic>.from(
            (invalidManifest['datasets'] as Map)['restrictions'] as Map,
          )
          ..['version'] = 'r2-invalid-condition'
          ..['sha256'] = await _sha256(invalidBytes);
    invalidEntry['publicationRevision'] =
        versionBeforeFailure.publicationRevision + 1;
    (invalidManifest['datasets'] as Map)['restrictions'] = invalidEntry;
    server.serve('/v1/manifest.json', utf8.encode(jsonEncode(invalidManifest)));
    server.serve(Uri.parse(invalidEntry['url'] as String).path, invalidBytes);
    await expectLater(service.sync(), throwsA(isA<DatasetSyncException>()));
    expect(await db.select(db.restrictionCoverages).get(), rowsBeforeFailure);
    expect(
      await db.select(db.datasetVersions).getSingle(),
      versionBeforeFailure,
    );
    expect(await db.select(db.vehicles).getSingle(), lastGoodVehicle);
    expect(
      await db.select(db.notificationPreferences).getSingle(),
      lastGoodPreferences,
    );

    final report = StringBuffer()
      ..writeln('# Flutter importó los mismos bytes de Laravel')
      ..writeln()
      ..writeln('- PHP release SHA-256: `$actualSha`.')
      ..writeln('- Laravel manifest entry SHA-256: `${entry['sha256']}`.')
      ..writeln(
        '- Drift dataset_versions SHA-256: `${installedVersion.sha256}`.',
      )
      ..writeln(
        '- Esquema importado: 2; cobertura: partial; 8501 kg y scope sintético; 2 condiciones.',
      )
      ..writeln(
        '- Importación mixta: 7 ciudades legacy + 1 V2 sintética; 12 coberturas legacy + 1 parcial: PASS.',
      )
      ..writeln('- HTTP loopback y evaluación tipada sintética: PASS.')
      ..writeln(
        '- Hash incorrecto y condición desconocida preservaron las 13 coberturas, dataset_versions y filas de usuario: PASS.',
      )
      ..writeln(
        '- Filas sintéticas de vehículo y preferencias persistieron: PASS.',
      )
      ..writeln(
        '- Evidencia espacial: SYNTHETIC_CONTEXT; no es verificación GPS.',
      )
      ..writeln();
    await File('${evidenceDirectory.path}/FLUTTER_SAME_BYTES_IMPORT_RESULT.md')
        .writeAsString(report.toString());
  });

  test(
    'V1 schema2 availability bytes reach Drift through HTTP loopback',
    () async {
      final evidenceDirectory = Directory(
        Platform.environment['PICORADAR_V1_METADATA_LAB_DIR'] ?? '',
      );
      expect(await evidenceDirectory.exists(), isTrue);
      final releaseFile = File(
        '${evidenceDirectory.path}/V1_SCHEMA2_PHP_RELEASE.json',
      );
      final manifestFile = File(
        '${evidenceDirectory.path}/V1_SCHEMA2_PHP_MANIFEST.json',
      );
      expect(await releaseFile.exists(), isTrue);
      expect(await manifestFile.exists(), isTrue);
      final releaseBytes = await releaseFile.readAsBytes();
      final manifestBytes = await manifestFile.readAsBytes();
      final release = Map<String, dynamic>.from(
        jsonDecode(utf8.decode(releaseBytes)) as Map,
      );
      final manifest = Map<String, dynamic>.from(
        jsonDecode(utf8.decode(manifestBytes)) as Map,
      );
      final entry = Map<String, dynamic>.from(
        (manifest['datasets'] as Map)['restrictions'] as Map,
      );
      final releaseSha = await _sha256(releaseBytes);
      expect(release['schemaVersion'], 2);
      expect(entry['sha256'], releaseSha);
      final cities = (release['jurisdictions'] as List).cast<Map>();
      final city = Map<String, dynamic>.from(
        cities.singleWhere((candidate) => candidate['id'] == 'co-ant-medellin'),
      );
      expect(city['municipalityCodes'], ['05001']);
      expect(city['consultationEnabled'], isTrue);

      await db
          .into(db.vehicles)
          .insert(VehiclesCompanion.insert(id: 'v1-user-row', plate: 'SYN123'));
      await db
          .into(db.notificationPreferences)
          .insert(
            NotificationPreferencesCompanion.insert(id: 'v1-user-preferences'),
          );
      final vehicleBefore = await db.select(db.vehicles).getSingle();
      final preferencesBefore = await db
          .select(db.notificationPreferences)
          .getSingle();
      final releasePath = Uri.parse(entry['url'] as String).path;
      server.serve('/v1/manifest.json', manifestBytes, etag: '"v1-schema2"');
      server.serve(releasePath, releaseBytes);
      final service = _service(
        db,
        preferences,
        tempDirectory,
        server,
        now: DateTime.parse(manifest['generatedAt'] as String)
            .add(const Duration(seconds: 1)),
      );

      final result = await service.sync();
      expect(result.imported, ['restrictions']);
      final responseBody = server.servedBody(releasePath);
      expect(responseBody, isNotNull);
      final responseBytes = responseBody!;
      expect(responseBytes, orderedEquals(releaseBytes));
      expect(await _sha256(responseBytes), releaseSha);
      final availability = await db
          .select(db.restrictionJurisdictionAvailability)
          .get();
      expect(availability, hasLength(1));
      expect(availability.single.jurisdictionId, 'co-ant-medellin');
      expect(availability.single.municipalityCodesJson, '["05001"]');
      expect(availability.single.consultationEnabled, isTrue);
      final coverages = await db.select(db.restrictionCoverages).get();
      expect(coverages, hasLength(1));
      final installedVersion = await db.select(db.datasetVersions).getSingle();
      expect(installedVersion.sha256, releaseSha);
      expect(installedVersion.version, entry['version']);
      expect(
        installedVersion.publicationRevision,
        entry['publicationRevision'],
      );
      expect(await db.select(db.vehicles).getSingle(), vehicleBefore);
      expect(
        await db.select(db.notificationPreferences).getSingle(),
        preferencesBefore,
      );

      final manifestWithBadSha = Map<String, dynamic>.from(manifest);
      final badEntry = Map<String, dynamic>.from(entry)
        ..['version'] = 'v1-invalid-sha'
        ..['publicationRevision'] = installedVersion.publicationRevision + 1
        ..['sha256'] = List<String>.filled(64, '0').join();
      (manifestWithBadSha['datasets'] as Map)['restrictions'] = badEntry;
      server.serve(
        '/v1/manifest.json',
        utf8.encode(jsonEncode(manifestWithBadSha)),
      );
      final coveragesBeforeFailure = await db
          .select(db.restrictionCoverages)
          .get();
      final availabilityBeforeFailure = await db
          .select(db.restrictionJurisdictionAvailability)
          .get();
      await expectLater(service.sync(), throwsA(isA<DatasetSyncException>()));
      expect(
        await db.select(db.restrictionCoverages).get(),
        coveragesBeforeFailure,
      );
      expect(
        await db.select(db.restrictionJurisdictionAvailability).get(),
        availabilityBeforeFailure,
      );
      expect(await db.select(db.datasetVersions).getSingle(), installedVersion);

      await File('${evidenceDirectory.path}/V1_FLUTTER_LOOPBACK_RESULT.json')
          .writeAsString(
            '${jsonEncode({
              'classification': 'LAB_SYNTHETIC_NOT_FOR_RELEASE',
              'transport': 'HTTP_LOOPBACK_TEST_ONLY',
              'releaseSha256': releaseSha,
              'loopbackSha256': await _sha256(responseBytes),
              'manifestSha256': await _sha256(manifestBytes),
              'jurisdictionId': availability.single.jurisdictionId,
              'municipalityCodes': ['05001'],
              'consultationEnabled': true,
              'coverageRows': coverages.length,
              'badShaPreservedCoverageAvailabilityAndVersion': true,
              'vehiclePreserved': true,
              'notificationPreferencesPreserved': true,
            })}\n',
          );
    },
  );

  test('G34 Laravel release SHA reaches loopback Drift import and engine', () async {
    final evidenceDirectory = Directory(
      Platform.environment['PICORADAR_G34_LAB_EVIDENCE_DIR'] ?? '',
    );
    expect(await evidenceDirectory.exists(), isTrue);
    final releaseFile = File(
      '${evidenceDirectory.path}${Platform.pathSeparator}G34_PHP_RELEASE.json',
    );
    final manifestFile = File(
      '${evidenceDirectory.path}${Platform.pathSeparator}G34_PHP_MANIFEST.json',
    );
    expect(await releaseFile.exists(), isTrue);
    expect(await manifestFile.exists(), isTrue);
    final releaseBytes = await releaseFile.readAsBytes();
    final manifestBytes = await manifestFile.readAsBytes();
    final release = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(releaseBytes)) as Map,
    );
    final manifest = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(manifestBytes)) as Map,
    );
    final entry = Map<String, dynamic>.from(
      (manifest['datasets'] as Map)['restrictions'] as Map,
    );
    final phpReleaseSha = await _sha256(releaseBytes);
    final phpManifestSha = await _sha256(manifestBytes);
    expect(entry['sha256'], phpReleaseSha);
    expect(release['schemaVersion'], 2);
    expect(manifest['schemaVersion'], 1);

    await db
        .into(db.vehicles)
        .insert(
          VehiclesCompanion.insert(
            id: 'g34-synthetic-user-row',
            plate: 'SYN123',
          ),
        );
    await db
        .into(db.notificationPreferences)
        .insert(
          NotificationPreferencesCompanion.insert(
            id: 'g34-synthetic-user-preferences',
          ),
        );
    final vehicleBefore = await db.select(db.vehicles).getSingle();
    final preferencesBefore = await db
        .select(db.notificationPreferences)
        .getSingle();
    List<int>? flutterReceivedBody;

    server.serve(
      '/v1/manifest.json',
      manifestBytes,
      etag: '"php-g34-manifest"',
    );
    server.serve(Uri.parse(entry['url'] as String).path, releaseBytes);
    final service = _service(
      db,
      preferences,
      tempDirectory,
      server,
      now: DateTime.parse(manifest['generatedAt'] as String)
          .add(const Duration(seconds: 1)),
      onDatasetCommitted: (datasetKey) {
        expect(datasetKey, 'restrictions');
        final downloadedFiles = tempDirectory
            .listSync()
            .whereType<File>()
            .where((file) => !file.path.endsWith('.decoded'))
            .toList();
        expect(downloadedFiles, hasLength(1));
        flutterReceivedBody = downloadedFiles.single.readAsBytesSync();
      },
    );
    final syncResult = await service.sync();
    expect(syncResult.imported, ['restrictions']);
    final releasePath = Uri.parse(entry['url'] as String).path;
    final loopbackBody = server.servedBody(releasePath);
    expect(loopbackBody, isNotNull);
    expect(loopbackBody, orderedEquals(releaseBytes));
    final loopbackBodySha = await _sha256(loopbackBody!);
    expect(flutterReceivedBody, isNotNull);
    expect(flutterReceivedBody, orderedEquals(releaseBytes));
    final flutterReceivedSha = await _sha256(flutterReceivedBody!);
    expect(loopbackBodySha, phpReleaseSha);
    expect(flutterReceivedSha, phpReleaseSha);
    expect(loopbackBody.length, releaseBytes.length);
    expect(flutterReceivedBody!.length, releaseBytes.length);

    final installed = await db.select(db.restrictionCoverages).get();
    expect(installed, hasLength(14));
    expect(installed.map((row) => row.jurisdictionId).toSet(), hasLength(8));
    expect(
      installed.any((row) => row.jurisdictionId == 'co-g2-synthetic'),
      isFalse,
    );
    final partialRows = installed
        .where((row) => row.coverageCompleteness == 'partial')
        .toList();
    expect(partialRows, hasLength(5));
    expect(
      partialRows.where((row) => row.jurisdictionId == 'co-ant-medellin'),
      hasLength(2),
    );
    expect(
      partialRows.where((row) => row.jurisdictionId == 'co-bol-cartagena'),
      hasLength(2),
    );
    expect(
      partialRows.where((row) => row.jurisdictionId == 'co-cal-manizales'),
      hasLength(1),
    );

    final installedVersion = await db.select(db.datasetVersions).getSingle();
    expect(installedVersion.sha256, phpReleaseSha);
    expect(installedVersion.sha256, entry['sha256']);
    expect(installedVersion.version, entry['version']);
    expect(installedVersion.publicationRevision, entry['publicationRevision']);
    expect(await db.select(db.vehicles).getSingle(), vehicleBefore);
    expect(
      await db.select(db.notificationPreferences).getSingle(),
      preferencesBefore,
    );

    final store = RestrictionStore(db);
    Future<RestrictionEvaluation> evaluate({
      required String jurisdictionId,
      required String plate,
      required VehicleKind vehicleKind,
      required DateTime localDateTime,
      VehicleServiceType serviceType = VehicleServiceType.private,
    }) async {
      final coverage = await store.loadCoverage(
        jurisdictionId,
        vehicleKind,
        serviceType,
        localDateTime,
      );
      return const RestrictionEngine().evaluate(
        RestrictionContext(
          jurisdictionId: jurisdictionId,
          plate: plate,
          vehicleKind: vehicleKind,
          serviceType: serviceType,
          registrationOrigin: RegistrationOrigin.unknown,
          localDateTime: localDateTime,
          isHoliday: false,
          coverageKnown: coverage.coverageKnown,
          dataIsStale: coverage.dataIsStale,
          coverageCompleteness: coverage.coverageCompleteness,
        ),
        coverage.rules,
      );
    }

    final medellinCar = await evaluate(
      jurisdictionId: 'co-ant-medellin',
      plate: 'ABC120',
      vehicleKind: VehicleKind.car,
      localDateTime: DateTime(2026, 11, 11, 6),
    );
    final medellinMotorcycle = await evaluate(
      jurisdictionId: 'co-ant-medellin',
      plate: 'MOT231',
      vehicleKind: VehicleKind.motorcycle,
      localDateTime: DateTime(2026, 11, 11, 6),
    );
    final cartagenaCar = await evaluate(
      jurisdictionId: 'co-bol-cartagena',
      plate: 'ABC123',
      vehicleKind: VehicleKind.car,
      localDateTime: DateTime(2026, 11, 17, 7),
    );
    final cartagenaMotorcycle = await evaluate(
      jurisdictionId: 'co-bol-cartagena',
      plate: 'MOT123',
      vehicleKind: VehicleKind.motorcycle,
      localDateTime: DateTime(2026, 11, 17, 5),
    );
    final manizalesCar = await evaluate(
      jurisdictionId: 'co-cal-manizales',
      plate: 'ABC125',
      vehicleKind: VehicleKind.car,
      localDateTime: DateTime(2026, 11, 11, 6),
    );
    final partialMismatch = await evaluate(
      jurisdictionId: 'co-ant-medellin',
      plate: 'ABC121',
      vehicleKind: VehicleKind.car,
      localDateTime: DateTime(2026, 11, 11, 6),
    );
    final unknownCoverage = await evaluate(
      jurisdictionId: 'co-test-unresearched',
      plate: 'ABC120',
      vehicleKind: VehicleKind.car,
      localDateTime: DateTime(2026, 11, 11, 6),
    );
    final unsupportedServicePair = await evaluate(
      jurisdictionId: 'co-ant-medellin',
      plate: 'ABC120',
      vehicleKind: VehicleKind.car,
      serviceType: VehicleServiceType.taxi,
      localDateTime: DateTime(2026, 11, 11, 6),
    );
    final staleCoverage = await evaluate(
      jurisdictionId: 'co-cal-manizales',
      plate: 'ABC125',
      vehicleKind: VehicleKind.car,
      localDateTime: DateTime(2026, 11, 18, 6),
    );

    expect(medellinCar.status, RestrictionStatus.restricted);
    expect(medellinMotorcycle.status, RestrictionStatus.restricted);
    expect(cartagenaCar.status, RestrictionStatus.restricted);
    expect(cartagenaMotorcycle.status, RestrictionStatus.restricted);
    expect(manizalesCar.status, RestrictionStatus.restricted);
    expect(partialMismatch.status, RestrictionStatus.unknown);
    expect(unknownCoverage.status, RestrictionStatus.unknown);
    expect(unsupportedServicePair.status, RestrictionStatus.unknown);
    expect(staleCoverage.status, RestrictionStatus.stale);

    final evidence = <String, Object?>{
      'classification': 'LAB_ONLY_NOT_JURIDICAL_CERTIFICATION',
      'transport': 'HTTP_LOOPBACK_TEST_ONLY',
      'realStaticHttpHost': 'NOT_RUN',
      'phpReleaseSha256': phpReleaseSha,
      'loopbackResponsePayloadSha256': loopbackBodySha,
      'phpReleaseBytes': releaseBytes.length,
      'loopbackResponseBytes': loopbackBody.length,
      'flutterReceivedBytes': flutterReceivedBody!.length,
      'flutterReceivedAndImportedSha256': flutterReceivedSha,
      'phpManifestSha256': phpManifestSha,
      'manifestReleaseSha256': entry['sha256'],
      'releaseVersion': installedVersion.version,
      'publicationRevision': installedVersion.publicationRevision,
      'jurisdictions': 8,
      'coverages': 14,
      'g34PartialCoverages': 5,
      'vehiclePreserved': true,
      'preferencesPreserved': true,
      'evaluationStatuses': {
        'medellinCar': medellinCar.status.name,
        'medellinMotorcycle': medellinMotorcycle.status.name,
        'cartagenaCar': cartagenaCar.status.name,
        'cartagenaMotorcycle': cartagenaMotorcycle.status.name,
        'manizalesCar': manizalesCar.status.name,
        'partialMismatch': partialMismatch.status.name,
        'unresearchedCoverage': unknownCoverage.status.name,
        'unsupportedServicePair': unsupportedServicePair.status.name,
        'staleCoverage': staleCoverage.status.name,
      },
    };
    await File(
      '${evidenceDirectory.path}${Platform.pathSeparator}G34_FLUTTER_RESULT.json',
    ).writeAsString('${jsonEncode(evidence)}\n');
  });
  final r2SnapshotsPath = Platform.environment['PICORADAR_R2_SNAPSHOTS_DIR'];
  test(
    'Laravel-generated schema2 A/B snapshots sync over loopback into Drift and fail closed',
    () async {
      final snapshots = Directory(r2SnapshotsPath!);
      expect(await snapshots.exists(), isTrue);
      final databaseFile = File(
        '${tempDirectory.path}${Platform.pathSeparator}r2-drift.sqlite',
      );
      final database = AppDatabase(NativeDatabase(databaseFile));
      final r2Preferences = _MemoryPreferences();
      final picoCatalog = PicoJurisdictionCatalog.fromJson(
        jsonDecode(File(picoJurisdictionCatalogAssetPath).readAsStringSync())
            as Map<String, Object?>,
      );
      final tripCatalog = TripMunicipalityCatalog.fromJson(
        jsonDecode(File(tripMunicipalityCatalogAssetPath).readAsStringSync())
            as Map<String, Object?>,
      );
      expect(
        picoCatalog.records.any((entry) => entry.municipalityCode == '05002'),
        isFalse,
      );
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          bundledRestrictionsProvider.overrideWith((ref) async {}),
          picoJurisdictionCatalogProvider.overrideWith(
            (ref) async => picoCatalog,
          ),
          tripMunicipalityCatalogProvider.overrideWith(
            (ref) async => tripCatalog,
          ),
        ],
      );
      var containerDisposed = false;
      var databaseClosed = false;
      try {
        await database
            .into(database.vehicles)
            .insert(
              VehiclesCompanion.insert(
                id: 'r2-synthetic-garage-car',
                plate: 'SYN123',
              ),
            );
        await database
            .into(database.notificationPreferences)
            .insert(
              NotificationPreferencesCompanion.insert(
                id: 'r2-synthetic-notification-preferences',
              ),
            );
        final vehicleBefore = await database
            .select(database.vehicles)
            .getSingle();
        final preferencesBefore = await database
            .select(database.notificationPreferences)
            .getSingle();
        final onCommit = container.read(datasetSyncCommitHandlerProvider);
        final sync = _service(
          database,
          r2Preferences,
          tempDirectory,
          server,
          now: DateTime.utc(2026, 11, 20, 12),
          onDatasetCommitted: onCommit,
        );
        final store = RestrictionStore(database);
        final snapshotsToSync = [
          ('v1', true, 1, [1], 360, 600, DateTime(2026, 11, 16, 7)),
          ('v2', false, 2, [2], 720, 900, DateTime(2026, 11, 17, 13)),
          ('v3', true, 3, [3], 960, 1200, DateTime(2026, 11, 18, 17)),
        ];
        var lastGoodAsset = <int>[];
        var lastGoodVersion = '';
        for (final snapshot in snapshotsToSync) {
          final (label, enabled, digit, weekdays, start, end, at) = snapshot;
          final manifestBytes = await File(
            '${snapshots.path}${Platform.pathSeparator}$label${Platform.pathSeparator}manifest.json',
          ).readAsBytes();
          final assetBytes = await File(
            '${snapshots.path}${Platform.pathSeparator}$label${Platform.pathSeparator}asset.json',
          ).readAsBytes();
          final manifest = Map<String, Object?>.from(
            jsonDecode(utf8.decode(manifestBytes)) as Map,
          );
          final datasets = Map<String, Object?>.from(
            manifest['datasets'] as Map,
          );
          final entry = Map<String, Object?>.from(
            datasets['restrictions'] as Map,
          );
          final assetPath = Uri.parse(entry['url'] as String).path;
          expect(assetPath, startsWith('/storage/datasets/restrictions/'));
          expect(await _sha256(assetBytes), entry['sha256']);
          server.serve('/v1/manifest.json', manifestBytes);
          server.serve(assetPath, assetBytes);

          final result = await sync.sync();
          expect(result.imported, ['restrictions']);
          expect(
            server.servedBody('/v1/manifest.json'),
            orderedEquals(manifestBytes),
          );
          expect(server.servedBody(assetPath), orderedEquals(assetBytes));

          final versionRow =
              await (database.select(database.datasetVersions)..where(
                    (row) => row.datasetKey.equals(restrictionsDatasetKey),
                  ))
                  .getSingle();
          expect(versionRow.version, entry['version']);
          expect(versionRow.publicationRevision, entry['publicationRevision']);
          expect(versionRow.sha256, entry['sha256']);

          final active = await container.read(
            restrictionJurisdictionsProvider.future,
          );
          final activeIds = active.map((city) => city.id).toSet();
          expect(activeIds.contains('co-ant-medellin'), enabled);
          expect(activeIds, contains('co-lab-abejorral'));
          final selectorEntries = picoCatalog.withRuntimeAvailability(active);
          final selectableIds = selectorEntries
              .where(
                (city) => city.engineEnabled && activeIds.contains(city.id),
              )
              .map((city) => city.id)
              .toSet();
          expect(selectableIds.contains('co-ant-medellin'), enabled);
          expect(selectableIds, contains('co-lab-abejorral'));

          final trip = await container.read(
            tripRestrictionMappedMunicipalitiesProvider.future,
          );
          expect(
            trip.findByCode('05001')?.jurisdictionId,
            enabled ? 'co-ant-medellin' : isNull,
          );
          expect(
            trip.findByCode('05002')?.displayName,
            'Abejorral · Antioquia',
          );
          expect(trip.findByCode('05002')?.jurisdictionId, 'co-lab-abejorral');

          final coverageA = await store.loadCoverage(
            'co-ant-medellin',
            VehicleKind.car,
            VehicleServiceType.private,
            at,
          );
          final coverageB = await store.loadCoverage(
            'co-lab-abejorral',
            VehicleKind.car,
            VehicleServiceType.private,
            DateTime(2026, 11, 19, 10, 30),
          );
          expect(coverageA.coverageKnown, isTrue);
          expect(coverageA.dataIsStale, isFalse);
          expect(coverageA.rules.single.digits, {digit});
          expect(coverageA.rules.single.weekdays, weekdays.toSet());
          expect(coverageA.rules.single.timeWindows.single.startMinute, start);
          expect(coverageA.rules.single.timeWindows.single.endMinute, end);
          expect(coverageB.coverageKnown, isTrue);
          expect(coverageB.dataIsStale, isFalse);
          expect(coverageB.rules.single.digits, {9});
          expect(coverageB.rules.single.weekdays, {4});

          RestrictionStatus evaluate(
            String jurisdictionId,
            String plate,
            DateTime localDateTime,
            RestrictionRuleSet coverage,
          ) => const RestrictionEngine()
              .evaluate(
                RestrictionContext(
                  jurisdictionId: jurisdictionId,
                  plate: plate,
                  vehicleKind: VehicleKind.car,
                  serviceType: VehicleServiceType.private,
                  registrationOrigin: RegistrationOrigin.unknown,
                  localDateTime: localDateTime,
                  isHoliday: false,
                  coverageKnown: coverage.coverageKnown,
                  dataIsStale: coverage.dataIsStale,
                  coverageCompleteness: coverage.coverageCompleteness,
                ),
                coverage.rules,
              )
              .status;

          expect(
            evaluate('co-ant-medellin', 'SYN00$digit', at, coverageA),
            RestrictionStatus.restricted,
          );
          expect(
            evaluate(
              'co-lab-abejorral',
              'SYN009',
              DateTime(2026, 11, 19, 10, 30),
              coverageB,
            ),
            RestrictionStatus.restricted,
          );
          lastGoodAsset = assetBytes;
          lastGoodVersion = versionRow.version;
        }

        final unknownCoverage = await store.loadCoverage(
          'co-lab-unresearched',
          VehicleKind.car,
          VehicleServiceType.private,
          DateTime(2026, 11, 19, 10, 30),
        );
        expect(
          const RestrictionEngine()
              .evaluate(
                RestrictionContext(
                  jurisdictionId: 'co-lab-unresearched',
                  plate: 'SYN009',
                  vehicleKind: VehicleKind.car,
                  serviceType: VehicleServiceType.private,
                  registrationOrigin: RegistrationOrigin.unknown,
                  localDateTime: DateTime(2026, 11, 19, 10, 30),
                  isHoliday: false,
                  coverageKnown: unknownCoverage.coverageKnown,
                  dataIsStale: unknownCoverage.dataIsStale,
                  coverageCompleteness: unknownCoverage.coverageCompleteness,
                ),
                unknownCoverage.rules,
              )
              .status,
          RestrictionStatus.unknown,
        );
        final staleCoverage = await store.loadCoverage(
          'co-lab-abejorral',
          VehicleKind.car,
          VehicleServiceType.private,
          DateTime(2027, 1, 10, 10, 30),
        );
        expect(staleCoverage.dataIsStale, isTrue);
        expect(
          const RestrictionEngine()
              .evaluate(
                RestrictionContext(
                  jurisdictionId: 'co-lab-abejorral',
                  plate: 'SYN009',
                  vehicleKind: VehicleKind.car,
                  serviceType: VehicleServiceType.private,
                  registrationOrigin: RegistrationOrigin.unknown,
                  localDateTime: DateTime(2027, 1, 10, 10, 30),
                  isHoliday: false,
                  coverageKnown: staleCoverage.coverageKnown,
                  dataIsStale: staleCoverage.dataIsStale,
                  coverageCompleteness: staleCoverage.coverageCompleteness,
                ),
                staleCoverage.rules,
              )
              .status,
          RestrictionStatus.stale,
        );

        final badManifest = Map<String, Object?>.from(
          jsonDecode(
            await File(
              '${snapshots.path}${Platform.pathSeparator}v3${Platform.pathSeparator}manifest.json',
            ).readAsString(),
          ) as Map,
        );
        final badDatasets = Map<String, Object?>.from(
          badManifest['datasets'] as Map,
        );
        final badEntry = Map<String, Object?>.from(
          badDatasets['restrictions'] as Map,
        );
        badEntry['version'] = 'qa-corrupt-v4';
        badEntry['publicationRevision'] = 4;
        badEntry['sha256'] = List.filled(64, '0').join();
        badEntry['url'] =
            '/storage/datasets/restrictions/qa-corrupt-v4/asset.json';
        badDatasets['restrictions'] = badEntry;
        badManifest['datasets'] = badDatasets;
        final corruptManifestBytes = utf8.encode(jsonEncode(badManifest));
        const corruptAssetPath =
            '/storage/datasets/restrictions/qa-corrupt-v4/asset.json';
        server.serve('/v1/manifest.json', corruptManifestBytes);
        server.serve(corruptAssetPath, lastGoodAsset);
        await expectLater(sync.sync(), throwsA(isA<DatasetSyncException>()));
        final retainedVersion =
            await (database.select(database.datasetVersions)..where(
                  (row) => row.datasetKey.equals(restrictionsDatasetKey),
                ))
                .getSingle();
        expect(retainedVersion.version, lastGoodVersion);
        expect(
          await database.select(database.vehicles).getSingle(),
          vehicleBefore,
        );
        expect(
          await database.select(database.notificationPreferences).getSingle(),
          preferencesBefore,
        );

        container.dispose();
        containerDisposed = true;
        await database.close();
        databaseClosed = true;
        final reopened = AppDatabase(NativeDatabase(databaseFile));
        try {
          final reopenedVersion =
              await (reopened.select(reopened.datasetVersions)..where(
                    (row) => row.datasetKey.equals(restrictionsDatasetKey),
                  ))
                  .getSingle();
          expect(reopenedVersion.version, lastGoodVersion);
          expect(
            await reopened.select(reopened.vehicles).getSingle(),
            vehicleBefore,
          );
          expect(
            await reopened.select(reopened.notificationPreferences).getSingle(),
            preferencesBefore,
          );
          final reopenedCoverage = await RestrictionStore(reopened)
              .loadCoverage(
                'co-lab-abejorral',
                VehicleKind.car,
                VehicleServiceType.private,
                DateTime(2026, 11, 19, 10, 30),
              );
          expect(reopenedCoverage.rules.single.digits, {9});
        } finally {
          await reopened.close();
        }
      } finally {
        if (!containerDisposed) container.dispose();
        if (!databaseClosed) await database.close();
      }
    },
    skip: r2SnapshotsPath == null
        ? 'Requires the synthetic Laravel R2 snapshot directory.'
        : null,
  );
}

DatasetSyncService _service(
  AppDatabase db,
  AppPreferences preferences,
  Directory tempDirectory,
  _Loopback server, {
  DateTime? now,
  void Function(String)? onDatasetCommitted,
}) => DatasetSyncService(
  database: db,
  preferences: preferences,
  config: AppConfig(cdnBaseUrl: server.origin.toString()),
  importers: {restrictionsDatasetKey: importRestrictionsDataset},
  http: Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 2),
      receiveTimeout: const Duration(seconds: 5),
    ),
  ),
  tempDirectory: tempDirectory,
  currentAppVersion: '1.0.0',
  now: () => now ?? DateTime.utc(2026, 11, 10, 23),
  onDatasetCommitted: onDatasetCommitted,
);

class _MemoryPreferences implements AppPreferences {
  final Map<String, Object?> _values = {};

  @override
  Future<bool?> getBool(String key) async => _values[key] as bool?;

  @override
  Future<int?> getInt(String key) async => _values[key] as int?;

  @override
  Future<String?> getString(String key) async => _values[key] as String?;

  @override
  Future<void> setString(String key, String value) async =>
      _values[key] = value;

  @override
  Future<void> setBool(String key, bool value) async => _values[key] = value;

  @override
  Future<void> setInt(String key, int value) async => _values[key] = value;

  @override
  Future<void> remove(String key) async {
    _values.remove(key);
  }
}

class _Loopback {
  _Loopback(this._server) {
    _server.listen((request) async {
      final bytes = _responses[request.uri.path];
      if (bytes == null) {
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
        return;
      }
      request.response.headers.contentType = ContentType.json;
      request.response.headers.contentLength = bytes.length;
      final etag = _etags[request.uri.path];
      if (etag != null) {
        request.response.headers.set(HttpHeaders.etagHeader, etag);
      }
      _servedBodies[request.uri.path] = List<int>.unmodifiable(bytes);
      request.response.add(bytes);
      await request.response.close();
    });
  }

  final HttpServer _server;
  final Map<String, List<int>> _responses = {};
  final Map<String, String> _etags = {};
  final Map<String, List<int>> _servedBodies = {};

  Uri get origin => Uri.parse('http://127.0.0.1:${_server.port}/');

  static Future<_Loopback> start() async =>
      _Loopback(await HttpServer.bind(InternetAddress.loopbackIPv4, 0));

  void serve(String path, List<int> bytes, {String? etag}) {
    _responses[path] = bytes;
    if (etag != null) _etags[path] = etag;
  }

  List<int>? servedBody(String path) => _servedBodies[path];

  Future<void> close() => _server.close(force: true);
}

Future<String> _sha256(List<int> bytes) async =>
    (await Sha256().hash(bytes)).bytes
        .map((value) => value.toRadixString(16).padLeft(2, '0'))
        .join();
