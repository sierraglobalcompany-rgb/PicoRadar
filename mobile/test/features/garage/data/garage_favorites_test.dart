import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/core/storage/app_preferences.dart';
import 'package:picoradar/features/garage/data/garage_favorites.dart';

void main() {
  group('legacy garage favorites', () {
    for (final raw in <String?>[
      null,
      '',
      '  ',
      '{}',
      'null',
      '42',
      '{broken',
    ]) {
      test('ignores absent or malformed legacy value $raw', () async {
        expect(await loadGarageFavoriteVehicleIds(_Preferences(raw)), isEmpty);
      });
    }

    test(
      'reads unique string ids from legacy list without writing it',
      () async {
        final preferences = _Preferences('["second",1,null,"first","second"]');
        expect(await loadGarageFavoriteVehicleIds(preferences), {
          'first',
          'second',
        });
        expect(preferences.raw, '["second",1,null,"first","second"]');
      },
    );

    test('propagates storage read failures', () async {
      final preferences = _Preferences(null)..failRead = true;
      await expectLater(
        loadGarageFavoriteVehicleIds(preferences),
        throwsStateError,
      );
    });
  });

  test(
    'queue continues after failure and delivers original error to caller',
    () async {
      final preferences = _Preferences(null);
      final release = Completer<void>();
      final order = <int>[];
      final first = serializeGarageFavoriteMutation<void>(
        preferences,
        () async {
          order.add(1);
          await release.future;
          throw StateError('failed mutation');
        },
      );
      final failure = expectLater(first, throwsStateError);
      final second = serializeGarageFavoriteMutation(preferences, () async {
        order.add(2);
        return 'done';
      });
      release.complete();
      await failure;
      expect(await second, 'done');
      expect(order, [1, 2]);
    },
  );
}

class _Preferences implements AppPreferences {
  _Preferences(this.raw);

  final String? raw;
  bool failRead = false;

  @override
  Future<String?> getString(String key) async {
    expect(key, garageFavoriteVehicleIdsPreferenceKey);
    if (failRead) throw StateError('Preference read failed');
    return raw;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
