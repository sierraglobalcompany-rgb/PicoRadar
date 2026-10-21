import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/core/storage/app_preferences.dart';
import 'package:picoradar/features/buy_sell/data/buy_sell_draft.dart';

void main() {
  for (final path in [
    ['preparations', 'buy'],
    ['preparations', 'sell'],
    ['contract'],
    ['candidateVehicle'],
    ['candidateRegistrationAttachment'],
    ['archivedPurchases', 0, 'context'],
    ['archivedPurchases', 0, 'candidate'],
    ['archivedPurchases', 0, 'preparation'],
    ['archivedPurchases', 0, 'legacyAttachment'],
    ['archivedPurchases', 0, 'contract'],
  ]) {
    for (final invalid in [null, [], 'invalid', 42, false]) {
      test(
        'v4 preserves invalid nested $path = $invalid on load/save',
        () async {
          final payload =
              jsonDecode(BuySellDraft.empty().toJsonString()) as Map;
          payload['archivedPurchases'] = [
            const BuySellPurchaseSnapshot(
              context: PurchaseConsultationContext(preparationId: 'archived'),
              candidate: BuySellCandidateVehicle(),
              preparation: BuySellPreparation(),
              legacyAttachment: BuySellRegistrationAttachment(),
              contract: BuySellContractDraft(),
            ).toJson(),
          ];
          dynamic parent = payload;
          for (final key in path.take(path.length - 1)) {
            parent = parent[key];
          }
          parent[path.last] = invalid;
          final raw = jsonEncode(payload);
          final preferences = _MemoryPreferences();
          await preferences.setString(buySellDraftPreferenceKey, raw);
          await expectLater(
            loadBuySellDraft(preferences),
            throwsFormatException,
          );
          await expectLater(
            saveBuySellDraft(preferences, BuySellDraft.empty()),
            throwsFormatException,
          );
          expect(await preferences.getString(buySellDraftPreferenceKey), raw);
        },
      );
    }
  }
  test('v4 rejects a non-boolean city confirmation', () {
    final payload = jsonDecode(BuySellDraft.empty().toJsonString()) as Map;
    payload['candidateVehicle']['registrationCityConfirmed'] = 'true';
    expect(
      () => BuySellDraft.fromJsonString(jsonEncode(payload)),
      throwsFormatException,
    );
  });
  test(
    'v3 preserves progress and legacy declarations without fabricating files',
    () {
      final json = jsonDecode(
        BuySellDraft.empty().toJsonString(),
      ) as Map<String, dynamic>;
      json['version'] = 3;
      json.remove('purchaseContext');
      json.remove('archivedPurchases');
      json['candidateRegistrationAttachment'] = {'pdf': true};
      json['preparations']['buy'] = {
        'notes': 'Revisar soporte',
        'checkedItems': ['comparendos'],
      };
      final draft = BuySellDraft.fromJsonString(jsonEncode(json));
      expect(draft.checkedItems, {'comparendos'});
      expect(draft.notes, 'Revisar soporte');
      expect(
        draft.candidateRegistrationAttachment.statusLabel,
        'Copia pendiente de importar',
      );
      expect(draft.purchaseContext.preparationId, isEmpty);
      expect(jsonDecode(draft.toJsonString())['version'], 4);
    },
  );
  test('independent authorities and immutable archive survive restart', () {
    final id = newPurchasePreparationId();
    final nextId = newPurchasePreparationId();
    expect(id, isNot(nextId));
    const originalCandidate = BuySellCandidateVehicle(
      plate: 'ABC123',
      registrationCity: 'Medellín',
      registrationCityConfirmed: true,
    );
    final old = BuySellDraft.empty().copyWith(
      purchaseContext: PurchaseConsultationContext(
        preparationId: id,
        taxAuthorityId: 'antioquia',
        transitAuthorityId: 'medellin',
        comparendosAuthorityId: 'bogota',
      ),
      candidateVehicle: originalCandidate,
    );
    final next = old.copyWith(
      purchaseContext: PurchaseConsultationContext(preparationId: nextId),
      archivedPurchases: [
        BuySellPurchaseSnapshot(
          context: old.purchaseContext,
          candidate: originalCandidate,
          preparation: const BuySellPreparation(
            notes: 'Privado',
            checkedItems: {'taxes'},
          ),
          legacyAttachment: const BuySellRegistrationAttachment(),
          contract: const BuySellContractDraft(),
        ),
      ],
    );
    final restored = BuySellDraft.fromJsonString(next.toJsonString());
    expect(restored.purchaseContext.preparationId, nextId);
    expect(restored.purchaseContext.taxAuthorityId, isEmpty);
    final archive = restored.archivedPurchases.single;
    expect(archive.context.taxAuthorityId, 'antioquia');
    expect(archive.context.transitAuthorityId, 'medellin');
    expect(archive.context.comparendosAuthorityId, 'bogota');
    expect(archive.candidate.registrationCityConfirmed, isTrue);
    expect(archive.preparation.checkedItems, {'taxes'});
  });
  test('malformed persisted preparation remains recoverable', () async {
    final preferences = _MemoryPreferences();
    await preferences.setString(buySellDraftPreferenceKey, '{broken');
    await expectLater(loadBuySellDraft(preferences), throwsFormatException);
    expect(await preferences.getString(buySellDraftPreferenceKey), '{broken');
  });
  test('v4 cannot silently recreate a missing private owner field', () {
    final payload =
        jsonDecode(BuySellDraft.empty().toJsonString()) as Map<String, dynamic>;
    (payload['purchaseContext'] as Map).remove('preparationId');
    expect(
      () => BuySellDraft.fromJsonString(jsonEncode(payload)),
      throwsFormatException,
    );
  });
  test('archive cannot reuse the active private document owner', () {
    final context = PurchaseConsultationContext(
      preparationId: newPurchasePreparationId(),
    );
    final draft = BuySellDraft.empty().copyWith(
      purchaseContext: context,
      archivedPurchases: [
        BuySellPurchaseSnapshot(
          context: context,
          candidate: const BuySellCandidateVehicle(plate: 'ZZZ999'),
          preparation: const BuySellPreparation(),
          legacyAttachment: const BuySellRegistrationAttachment(),
          contract: const BuySellContractDraft(),
        ),
      ],
    );
    expect(
      () => BuySellDraft.fromJsonString(draft.toJsonString()),
      throwsFormatException,
    );
  });
}

class _MemoryPreferences implements AppPreferences {
  final values = <String, Object?>{};
  @override
  Future<String?> getString(String key) async => values[key] as String?;
  @override
  Future<void> setString(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> remove(String key) async {
    values.remove(key);
  }

  @override
  Future<bool?> getBool(String key) async => values[key] as bool?;
  @override
  Future<void> setBool(String key, bool value) async {
    values[key] = value;
  }

  @override
  Future<int?> getInt(String key) async => values[key] as int?;
  @override
  Future<void> setInt(String key, int value) async {
    values[key] = value;
  }
}
