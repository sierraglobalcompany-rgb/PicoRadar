import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const insuranceDirectoryAsset = 'assets/catalogs/insurance_directory_v1.json';

/// Published request routes, never a statement of the user's policy coverage.
enum InsuranceService {
  generalAssistance,
  towing,
  designatedDriver,
  roadsideRepair,
}

// Deliberately not autoDispose: one asset load per provider-container lifetime.
final insuranceDirectoryProvider = FutureProvider<InsuranceDirectory>((
  ref,
) async {
  return InsuranceDirectory.fromJsonString(
    await rootBundle.loadString(insuranceDirectoryAsset),
  );
});

class InsuranceDirectory {
  InsuranceDirectory({required List<InsuranceCompany> entries})
    : entries = List.unmodifiable(entries) {
    for (final entry in entries) {
      if (_byId.containsKey(entry.id)) {
        throw const FormatException('Duplicate insurer ID.');
      }
      _byId[entry.id] = entry;
      for (final name in [entry.name, entry.legalName, ...entry.aliases]) {
        final key = _normalize(name);
        if (key.isEmpty) continue;
        final existing = _byName[key];
        if (existing != null && existing.id != entry.id) {
          throw const FormatException('Ambiguous insurer alias.');
        }
        _byName[key] = entry;
      }
    }
  }

  factory InsuranceDirectory.fromJsonString(String source) =>
      InsuranceDirectory.fromJson(_object(jsonDecode(source)));

  factory InsuranceDirectory.fromJson(Map<String, dynamic> json) {
    if (json['schemaVersion'] != 1) {
      throw const FormatException('Unsupported insurance directory version.');
    }
    return InsuranceDirectory(
      entries: [
        for (final entry in _list(json, 'entries'))
          InsuranceCompany.fromJson(_object(entry)),
      ],
    );
  }

  final List<InsuranceCompany> entries;
  final Map<String, InsuranceCompany> _byId = {};
  final Map<String, InsuranceCompany> _byName = {};

  /// A known ID wins. Legacy fallback is exact after accent/case/space folding,
  /// never a substring or fuzzy match. Unknown names remain user-owned data.
  InsuranceCompany? resolve(String? id, String? legacyName) {
    final identified = _byId[id?.trim()];
    if (identified != null) return identified;
    return _byName[_normalize(legacyName ?? '')];
  }

  List<InsuranceCompany> search(String query, {String? category}) {
    final tokens = _normalize(query).split(' ').where((s) => s.isNotEmpty);
    final result = entries.where((entry) {
      if (category != null && !entry.categories.contains(category)) {
        return false;
      }
      final haystack = _normalize(
        [entry.name, entry.legalName, ...entry.aliases].join(' '),
      );
      return tokens.every(haystack.contains);
    }).toList();
    result.sort((a, b) {
      final byName = _normalize(a.name).compareTo(_normalize(b.name));
      return byName != 0 ? byName : a.id.compareTo(b.id);
    });
    return List.unmodifiable(result);
  }
}

class InsuranceCompany {
  InsuranceCompany({
    required this.id,
    required this.name,
    required this.legalName,
    required List<String> aliases,
    required this.website,
    required this.sourceUrl,
    required this.reviewedAt,
    required List<InsuranceChannel> channels,
    required List<String> categories,
  }) : aliases = List.unmodifiable(aliases),
       channels = List.unmodifiable(channels),
       categories = List.unmodifiable(categories);

  factory InsuranceCompany.fromJson(Map<String, dynamic> json) {
    final channels = [
      for (final channel in _list(json, 'channels'))
        InsuranceChannel.fromJson(_object(channel)),
    ];
    if (channels.map((c) => c.id).toSet().length != channels.length) {
      throw const FormatException('Duplicate insurer channel ID.');
    }
    final destinations = <String>{};
    for (final channel in channels) {
      if (!destinations.add(_destinationKey(channel))) {
        throw const FormatException('Duplicate insurer contact destination.');
      }
    }
    final categories = _strings(json, 'categories');
    if (categories.any((c) => !{'car', 'motorcycle', 'taxi'}.contains(c)) ||
        categories.toSet().length != categories.length) {
      throw const FormatException('Invalid insurer categories.');
    }
    return InsuranceCompany(
      id: _text(json, 'id'),
      name: _text(json, 'name'),
      legalName: _text(json, 'legalName'),
      aliases: _strings(json, 'aliases'),
      website: _url(json, 'website'),
      sourceUrl: _url(json, 'sourceUrl'),
      reviewedAt: _date(json, 'reviewedAt'),
      channels: channels,
      categories: categories,
    );
  }

  final String id;
  final String name;
  final String legalName;
  final List<String> aliases;
  final String website;
  final String sourceUrl;
  final String reviewedAt;
  final List<InsuranceChannel> channels;
  final List<String> categories;

  /// Only these channels may become contact actions. The full list also keeps
  /// editorially unresolved observations, which must not be dialled/opened.
  List<InsuranceChannel> get verifiedChannels =>
      List.unmodifiable(channels.where((channel) => channel.verified));
}

class InsuranceChannel {
  const InsuranceChannel({
    required this.id,
    required this.label,
    required this.kind,
    required this.value,
    required this.purpose,
    required this.sourceUrl,
    required this.reviewedAt,
    required this.verified,
    this.services = const [],
    this.conditions,
  });

  factory InsuranceChannel.fromJson(Map<String, dynamic> json) {
    final kind = _text(json, 'kind');
    final purpose = _text(json, 'purpose');
    final value = _text(json, 'value');
    if (!{'phone', 'whatsapp'}.contains(kind) ||
        !{'assistance', 'customerService'}.contains(purpose) ||
        json['verified'] is! bool) {
      throw const FormatException('Invalid insurance channel.');
    }
    // Retain leading zeroes and mobile short codes; no URLs, extensions or
    // message/query parameters may be smuggled into a dial/chat destination.
    final validNumber = kind == 'whatsapp'
        ? RegExp(r'^573\d{9}$').hasMatch(value)
        : RegExp(r'^(?:\+?57[36]\d{9}|60[1-8]\d{7}|3\d{9}|018000\d{6}|#\d{3})$')
              .hasMatch(value);
    if (!validNumber) {
      throw const FormatException('Invalid insurance contact number.');
    }
    final serviceNames = json.containsKey('services')
        ? _strings(json, 'services')
        : <String>[];
    if (serviceNames.toSet().length != serviceNames.length ||
        serviceNames.any(
          (name) => !InsuranceService.values.any((s) => s.name == name),
        )) {
      throw const FormatException('Invalid insurance channel services.');
    }
    if (serviceNames.isNotEmpty &&
        (purpose != 'assistance' || json['verified'] != true)) {
      throw const FormatException('Services require verified assistance.');
    }
    return InsuranceChannel(
      id: _text(json, 'id'),
      label: _text(json, 'label'),
      kind: kind,
      value: value,
      purpose: purpose,
      sourceUrl: _url(json, 'sourceUrl'),
      reviewedAt: _date(json, 'reviewedAt'),
      verified: json['verified'] as bool,
      services: List.unmodifiable([
        for (final name in serviceNames) InsuranceService.values.byName(name),
      ]),
      conditions: json['conditions'] == null ? null : _text(json, 'conditions'),
    );
  }

  final String id;
  final String label;
  final String kind;
  final String value;
  final String purpose;
  final String sourceUrl;
  final String reviewedAt;
  final bool verified;

  /// Empty for legacy, customer-service and unresolved channels. General
  /// assistance does not imply any of the three specific services (or vice versa).
  final List<InsuranceService> services;
  final String? conditions;
}

String _destinationKey(InsuranceChannel channel) {
  var number = channel.value.replaceFirst(RegExp(r'^\+'), '');
  if (number.length == 12 && number.startsWith('57')) {
    number = number.substring(2);
  }
  return '${channel.kind}:$number';
}

Map<String, dynamic> _object(Object? value) {
  if (value is! Map<String, dynamic>) {
    throw const FormatException('Expected an insurance directory object.');
  }
  return value;
}

String _text(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('Missing insurance directory field: $key.');
  }
  return value.trim();
}

List<dynamic> _list(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! List) {
    throw FormatException('Expected insurance directory list: $key.');
  }
  return value;
}

List<String> _strings(Map<String, dynamic> json, String key) {
  return [
    for (final item in _list(json, key)) _text({'value': item}, 'value'),
  ];
}

String _url(Map<String, dynamic> json, String key) {
  final value = _text(json, key);
  final uri = Uri.tryParse(value);
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      (uri.hasPort && uri.port != 443)) {
    throw FormatException('Invalid insurance directory URL: $key.');
  }
  return value;
}

String _date(Map<String, dynamic> json, String key) {
  final value = _text(json, key);
  final parsed = DateTime.tryParse(value);
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value) ||
      parsed == null ||
      parsed.toIso8601String().substring(0, 10) != value) {
    throw FormatException('Invalid insurance directory review date: $key.');
  }
  return value;
}

String _normalize(String value) {
  return value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp('[áàäâã]'), 'a')
      .replaceAll(RegExp('[éèëê]'), 'e')
      .replaceAll(RegExp('[íìïî]'), 'i')
      .replaceAll(RegExp('[óòöôõ]'), 'o')
      .replaceAll(RegExp('[úùüû]'), 'u')
      .replaceAll('ñ', 'n')
      .replaceAll(RegExp(r'[\u0300-\u036f]'), '')
      .replaceAll(RegExp(r'\s+'), ' ');
}
