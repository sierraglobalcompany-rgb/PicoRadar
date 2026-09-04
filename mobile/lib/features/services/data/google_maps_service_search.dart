const googleMapsSearchHost = 'www.google.com';
const googleMapsSearchPath = '/maps/search/';

Uri googleMapsServiceSearchUri({
  required String category,
  required String city,
}) {
  final normalizedCategory = category.trim();
  final normalizedCity = city.trim();
  final query = [
    normalizedCategory,
    normalizedCity,
  ].where((value) => value.isNotEmpty).join(' ');

  return Uri.https(googleMapsSearchHost, googleMapsSearchPath, {
    'api': '1',
    'query': query,
  });
}
