import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/features/vehicle_status/data/insurance_directory.dart';
import 'package:picoradar/features/vehicle_status/data/vehicle_status_catalog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final source = File(insuranceDirectoryAsset).readAsStringSync();
  final directory = InsuranceDirectory.fromJsonString(source);

  Map<String, dynamic> raw() => jsonDecode(source) as Map<String, dynamic>;
  Map<String, dynamic> company() =>
      (raw()['entries'] as List).first as Map<String, dynamic>;
  Map<String, dynamic> channel() =>
      (company()['channels'] as List).first as Map<String, dynamic>;

  group('reference inventory and evidence', () {
    test('all 16 existing exact insurer labels resolve independently', () {
      final legacy = insuranceProviderOptions
          .where((name) => name != 'Otra / no aparece')
          .toList();
      expect(legacy, hasLength(16));
      expect(directory.entries, hasLength(16));
      expect(
        legacy.map((name) => directory.resolve(null, name)?.id).toSet(),
        hasLength(16),
      );
      for (final name in legacy) {
        final entry = directory.resolve(null, name);
        expect(entry, isNotNull, reason: name);
        expect(entry!.aliases, contains(name), reason: name);
      }
      expect(directory.resolve(null, 'Otra / no aparece'), isNull);
    });

    test('every entity and channel has review evidence and scope', () {
      final rows = raw()['entries'] as List;
      expect(
        rows.map((row) => row['reference']['sfcCode']).toSet(),
        hasLength(16),
      );
      for (final entry in directory.entries) {
        expect(entry.reviewedAt, '2026-09-14');
        expect(Uri.parse(entry.website).scheme, 'https');
        expect(Uri.parse(entry.sourceUrl).scheme, 'https');
        for (final contact in entry.channels) {
          expect(contact.reviewedAt, isIn(['2026-09-13', '2026-09-14']));
          expect(Uri.parse(contact.sourceUrl).scheme, 'https');
          expect(contact.label, isNotEmpty);
          expect(contact.purpose, isIn(['assistance', 'customerService']));
          expect(contact.kind, isIn(['phone', 'whatsapp']));
        }
        final row = rows.singleWhere((row) => row['id'] == entry.id);
        for (final category in entry.categories) {
          expect(row['categoryEvidence'][category], startsWith('https://'));
        }
      }
    });

    test('disputed and wrong-purpose contacts never become actions', () {
      final all = directory.entries.expand((entry) => entry.channels).toList();
      expect(all, hasLength(60));
      expect(all.where((channel) => channel.verified), hasLength(54));
      for (final entry in directory.entries) {
        expect(
          entry.verifiedChannels.every((channel) => channel.verified),
          isTrue,
        );
        for (final inactive in entry.channels.where(
          (channel) => !channel.verified,
        )) {
          expect(entry.verifiedChannels, isNot(contains(inactive)));
        }
      }
      for (final id in ['axa', 'zurich']) {
        expect(
          directory
              .resolve(id, null)!
              .verifiedChannels
              .where((c) => c.kind == 'whatsapp'),
          isEmpty,
        );
      }
      expect(directory.resolve('alfa', null)!.categories, isEmpty);
      expect(
        directory
            .resolve('equidad', null)!
            .verifiedChannels
            .every((c) => c.purpose == 'customerService'),
        isTrue,
      );
      expect(
        directory
            .resolve('sbs', null)!
            .verifiedChannels
            .every((c) => c.purpose == 'customerService'),
        isTrue,
      );
    });
  });

  group('published service routes', () {
    test('service counts and conditions describe routes, not coverage', () {
      final contacts = directory.entries.expand((e) => e.channels).toList();
      expect(contacts.where((c) => c.services.isNotEmpty), hasLength(34));
      const entityCounts = {
        InsuranceService.generalAssistance: 11,
        InsuranceService.towing: 9,
        InsuranceService.designatedDriver: 10,
        InsuranceService.roadsideRepair: 9,
      };
      for (final item in entityCounts.entries) {
        expect(
          directory.entries.where(
            (e) => e.verifiedChannels.any((c) => c.services.contains(item.key)),
          ),
          hasLength(item.value),
        );
      }
      for (final c in contacts) {
        expect(c.services.toSet(), hasLength(c.services.length));
        if (c.services.isNotEmpty) {
          expect(c.verified, isTrue);
          expect(c.purpose, 'assistance');
          expect(c.reviewedAt, '2026-09-14');
          expect(c.conditions, isNotEmpty);
          expect(() => c.services.clear(), throwsUnsupportedError);
        }
        if (!c.verified || c.purpose == 'customerService') {
          expect(c.services, isEmpty);
        }
      }
    });

    test('HDI WhatsApp is only driver and roadside repair', () {
      final hdi = directory.resolve('hdi', null)!;
      final chat = hdi.verifiedChannels.singleWhere(
        (c) => c.kind == 'whatsapp',
      );
      expect(chat.value, '573164821802');
      expect(chat.services, [
        InsuranceService.designatedDriver,
        InsuranceService.roadsideRepair,
      ]);
      expect(chat.conditions, contains('2 horas'));
      expect(chat.conditions, contains('40 km'));
      for (final phone in hdi.verifiedChannels.where(
        (c) => c.kind == 'phone',
      )) {
        expect(phone.services, [InsuranceService.generalAssistance]);
      }
      expect(hdi.channels.singleWhere((c) => !c.verified).services, isEmpty);
    });

    test('general assistance does not imply every specific service', () {
      final cami = directory
          .resolve('solidaria', null)!
          .verifiedChannels
          .singleWhere((c) => c.kind == 'whatsapp');
      expect(cami.services, [InsuranceService.generalAssistance]);
      final axa = directory.resolve('axa', null)!;
      final renewal = axa.channels.singleWhere((c) => c.kind == 'whatsapp');
      expect(renewal.verified, isFalse);
      expect(renewal.services, isEmpty);
      expect(
        axa.verifiedChannels.expand((c) => c.services),
        isNot(contains(InsuranceService.roadsideRepair)),
      );
      for (final id in ['bbva', 'equidad', 'sbs', 'alfa', 'zurich']) {
        expect(
          directory
              .resolve(id, null)!
              .verifiedChannels
              .expand((c) => c.services),
          isEmpty,
          reason: id,
        );
      }
    });

    test('legacy JSON and const constructors do not invent services', () {
      final legacy = channel()
        ..remove('services')
        ..remove('conditions');
      final parsed = InsuranceChannel.fromJson(legacy);
      expect(parsed.services, isEmpty);
      expect(parsed.conditions, isNull);
      const constructed = InsuranceChannel(
        id: 'legacy',
        label: 'Legacy',
        kind: 'phone',
        value: '#265',
        purpose: 'assistance',
        sourceUrl: 'https://www.allianz.co/',
        reviewedAt: '2026-09-13',
        verified: true,
      );
      expect(constructed.services, isEmpty);
      expect(constructed.conditions, isNull);
    });

    test('new optional fields are strict when supplied', () {
      for (final invalid in [
        null,
        'towing',
        [null],
        ['unknown'],
        ['Towing'],
        ['towing', 'towing'],
      ]) {
        expect(
          () => InsuranceChannel.fromJson({...channel(), 'services': invalid}),
          throwsFormatException,
        );
      }
      for (final invalid in ['', '   ', 1, [], {}]) {
        expect(
          () =>
              InsuranceChannel.fromJson({...channel(), 'conditions': invalid}),
          throwsFormatException,
        );
      }
      expect(
        InsuranceChannel.fromJson({...channel(), 'conditions': null})
            .conditions,
        isNull,
      );
      for (final change in [
        {'purpose': 'customerService'},
        {'verified': false},
      ]) {
        expect(
          () => InsuranceChannel.fromJson({
            ...channel(),
            ...change,
            'services': ['towing'],
          }),
          throwsFormatException,
        );
      }
      final services = ['towing'];
      final parsed = InsuranceChannel.fromJson({
        ...channel(),
        'services': services,
        'conditions': '  Según póliza.  ',
      });
      services.add('roadsideRepair');
      expect(parsed.services, [InsuranceService.towing]);
      expect(parsed.conditions, 'Según póliza.');
    });

    test('duplicate destinations fail across IDs and Colombian prefixes', () {
      for (final pair in [
        ['#265', '#265'],
        ['6015941133', '+576015941133'],
        ['6015941133', '576015941133'],
        ['3152757888', '+573152757888'],
        ['018000513500', '018000513500'],
      ]) {
        expect(
          () => InsuranceCompany.fromJson({
            ...company(),
            'channels': [
              {...channel(), 'id': 'one', 'value': pair.first},
              {...channel(), 'id': 'two', 'value': pair.last},
            ],
          }),
          throwsFormatException,
        );
      }
      final phoneAndChat = InsuranceCompany.fromJson({
        ...company(),
        'channels': [
          {...channel(), 'id': 'voice', 'value': '3152757888'},
          {
            ...channel(),
            'id': 'chat',
            'kind': 'whatsapp',
            'value': '573152757888',
          },
        ],
      });
      expect(phoneAndChat.channels, hasLength(2));
    });
  });

  group('resolution and search', () {
    test(
      'known ID wins, unknown ID falls back only to an exact legacy name',
      () {
        expect(directory.resolve('sura', 'Allianz Colombia')?.id, 'sura');
        expect(
          directory.resolve(' deleted ', 'Allianz Colombia')?.id,
          'allianz',
        );
        expect(directory.resolve(' sura ', null)?.id, 'sura');
        expect(directory.resolve(null, null), isNull);
        expect(directory.resolve('', '   '), isNull);
        expect(directory.resolve('missing', 'unknown insurer'), isNull);
        expect(directory.resolve(null, 'Allian'), isNull);
        expect(directory.resolve(null, 'Liberty'), isNull);
        expect(directory.resolve(null, 'BBVA Seguros')?.id, 'bbva');
      },
    );

    test('accent, decomposed accent, case and spaces are folded', () {
      expect(
        directory.resolve(null, '  SEGUROS   BOLIVAR S.A. ')?.id,
        'bolivar',
      );
      expect(directory.resolve(null, 'Qua\u0301litas')?.id, 'qualitas');
      expect(directory.search('compania qualitas').single.id, 'qualitas');
      expect(directory.search('equidad').single.id, 'equidad');
      expect(directory.search('not present'), isEmpty);
      expect(directory.search(''), hasLength(16));
      expect(
        directory.search('   ').map((e) => e.id).toList().first,
        'allianz',
      );
    });

    test('category filters use proved products, not SOAT or authorization', () {
      expect(directory.search('', category: 'car'), hasLength(15));
      expect(directory.search('', category: 'motorcycle'), hasLength(6));
      expect(directory.search('', category: 'taxi').single.id, 'axa');
      expect(directory.search('alfa', category: 'car'), isEmpty);
      expect(directory.search('', category: 'soat'), isEmpty);
      expect(directory.search('', category: 'unknown'), isEmpty);
    });

    test('callers cannot mutate the cached directory', () {
      final entry = directory.entries.first;
      expect(() => directory.entries.clear(), throwsUnsupportedError);
      expect(() => directory.search('').clear(), throwsUnsupportedError);
      expect(() => entry.aliases.clear(), throwsUnsupportedError);
      expect(() => entry.categories.clear(), throwsUnsupportedError);
      expect(() => entry.channels.clear(), throwsUnsupportedError);
      expect(() => entry.verifiedChannels.clear(), throwsUnsupportedError);
    });
  });

  group('strict asset parsing', () {
    test('unknown schema, null lists and duplicate IDs fail explicitly', () {
      expect(
        () => InsuranceDirectory.fromJson({...raw(), 'schemaVersion': 2}),
        throwsFormatException,
      );
      expect(
        () => InsuranceDirectory.fromJson({...raw(), 'entries': null}),
        throwsFormatException,
      );
      expect(
        () => InsuranceDirectory.fromJsonString('[]'),
        throwsFormatException,
      );
      expect(
        () => InsuranceDirectory.fromJsonString('{'),
        throwsFormatException,
      );
      expect(
        () => InsuranceDirectory.fromJson({
          'schemaVersion': 1,
          'entries': [company(), company()],
        }),
        throwsFormatException,
      );
      final other = {...company(), 'id': 'different'};
      expect(
        () => InsuranceDirectory.fromJson({
          'schemaVersion': 1,
          'entries': [company(), other],
        }),
        throwsFormatException,
      );
    });

    test('duplicate channel IDs and unknown categories are rejected', () {
      expect(
        () => InsuranceCompany.fromJson({
          ...company(),
          'channels': [channel(), channel()],
        }),
        throwsFormatException,
      );
      expect(
        () => InsuranceCompany.fromJson({
          ...company(),
          'categories': ['soat'],
        }),
        throwsFormatException,
      );
      expect(
        () => InsuranceCompany.fromJson({
          ...company(),
          'categories': ['car', 'car'],
        }),
        throwsFormatException,
      );
      expect(
        () => InsuranceCompany.fromJson({
          ...company(),
          'aliases': [null],
        }),
        throwsFormatException,
      );
    });

    test('review dates must be real calendar dates', () {
      for (final invalid in [
        '2026-02-30',
        '2026-13-01',
        'yesterday',
        '2026-9-13',
        '2026-09-13T12:00:00Z',
      ]) {
        expect(
          () =>
              InsuranceChannel.fromJson({...channel(), 'reviewedAt': invalid}),
          throwsFormatException,
        );
      }
      expect(
        InsuranceChannel.fromJson({...channel(), 'reviewedAt': '2024-02-29'})
            .reviewedAt,
        '2024-02-29',
      );
    });

    test('unsafe URLs and destination injection are rejected', () {
      for (final invalid in [
        'http://example.com',
        'https://user:password@example.com',
        'https://example.com:8080',
        'tel:123',
      ]) {
        expect(
          () => InsuranceChannel.fromJson({...channel(), 'sourceUrl': invalid}),
          throwsFormatException,
        );
      }
      for (final invalid in [
        '#265?body=secret',
        'https://wa.me/573152757888',
        '6014378888;123',
        '123',
        '+1 555 0100',
      ]) {
        expect(
          () => InsuranceChannel.fromJson({...channel(), 'value': invalid}),
          throwsFormatException,
        );
      }
      expect(
        () => InsuranceChannel.fromJson({...channel(), 'verified': 'true'}),
        throwsFormatException,
      );
      expect(
        () => InsuranceChannel.fromJson({...channel(), 'purpose': 'marketing'}),
        throwsFormatException,
      );
    });

    test(
      'phone short codes and leading zeroes survive; WhatsApp requires mobile',
      () {
        for (final value in [
          '#265',
          '018000513500',
          '6015941133',
          '3232641770',
          '+576015941133',
        ]) {
          expect(
            InsuranceChannel.fromJson({
              ...channel(),
              'kind': 'phone',
              'value': value,
            }).value,
            value,
          );
        }
        expect(
          InsuranceChannel.fromJson({
            ...channel(),
            'kind': 'whatsapp',
            'value': '573152757888',
          }).value,
          '573152757888',
        );
        for (final value in [
          '3152757888',
          '576014378888',
          '573152757888?text=hello',
          '#888',
        ]) {
          expect(
            () => InsuranceChannel.fromJson({
              ...channel(),
              'kind': 'whatsapp',
              'value': value,
            }),
            throwsFormatException,
          );
        }
      },
    );
  });

  test(
    'provider loads once and survives closing listeners in one container',
    () async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      var reads = 0;
      rootBundle.evict(insuranceDirectoryAsset);
      messenger.setMockMessageHandler('flutter/assets', (message) async {
        if (utf8.decode(
              message!.buffer.asUint8List(
                message.offsetInBytes,
                message.lengthInBytes,
              ),
            ) !=
            insuranceDirectoryAsset) {
          return null;
        }
        reads++;
        return ByteData.sublistView(Uint8List.fromList(utf8.encode(source)));
      });
      final container = ProviderContainer();
      addTearDown(() {
        container.dispose();
        messenger.setMockMessageHandler('flutter/assets', null);
        rootBundle.evict(insuranceDirectoryAsset);
      });
      final subscription = container.listen(
        insuranceDirectoryProvider,
        (_, _) {},
      );
      final first = await container.read(insuranceDirectoryProvider.future);
      subscription.close();
      await Future<void>.delayed(Duration.zero);
      final second = await container.read(insuranceDirectoryProvider.future);
      expect(identical(first, second), isTrue);
      expect(reads, 1);
    },
  );
}
