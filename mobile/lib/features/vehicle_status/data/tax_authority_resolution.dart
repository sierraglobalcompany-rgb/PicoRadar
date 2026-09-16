import '../../onboarding/data/registration_city_catalog.dart';
import 'tax_catalog.dart';

String? suggestTaxAuthority(
  TaxCatalog catalog,
  RegistrationCityCatalog? cities,
  String? raw,
) {
  if (raw == null || raw.trim().isEmpty) return null;
  String clean(String value) =>
      normalizeRegistrationCityText(value)
          .replaceAll(RegExp(r'[^a-z0-9 ]'), '')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
  final input = clean(raw);
  if (const [
    'bogota',
    'bogota dc',
    'bogota d c',
    'bogota bogota dc',
  ].contains(input)) {
    return 'bogota';
  }
  if (const ['medellin', 'medellin antioquia'].contains(input)) {
    return 'antioquia';
  }
  final matches =
      cities?.records
          .where(
            (city) =>
                clean(city.displayName) == input ||
                clean(city.municipality) == input,
          )
          .toList() ??
      [];
  final departments = matches.map((city) => clean(city.department)).toSet();
  if (departments.length != 1) return null;
  if (departments.single == 'archipielago de san andres providencia') {
    return catalog.authorities
        .where((item) => item.territoryCode == '88')
        .firstOrNull
        ?.id;
  }
  return catalog.authorities
      .where(
        (authority) => clean(authority.territoryName) == departments.single,
      )
      .firstOrNull
      ?.id;
}
