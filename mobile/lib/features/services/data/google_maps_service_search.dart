const googleMapsSearchHost = 'www.google.com';
const googleMapsSearchPath = '/maps/search/';

enum GoogleMapsServiceCategory {
  tow('grúa 24 horas'),
  battery('batería'),
  tires('llantas'),
  mechanic('taller mecánico'),
  appraisal('peritaje vehicular');

  const GoogleMapsServiceCategory(this.searchLabel);

  final String searchLabel;
}

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

Uri googleMapsNearbyServiceSearchUri({
  required GoogleMapsServiceCategory category,
  required double latitude,
  required double longitude,
}) {
  final lat = latitude.toStringAsFixed(6);
  final lng = longitude.toStringAsFixed(6);
  return _googleMapsSearchUri('${category.searchLabel} cerca de $lat,$lng');
}

Uri googleMapsCityServiceSearchUri({
  required GoogleMapsServiceCategory category,
  required String city,
}) {
  return googleMapsServiceSearchUri(category: category.searchLabel, city: city);
}

Uri _googleMapsSearchUri(String query) {
  return Uri.https(googleMapsSearchHost, googleMapsSearchPath, {
    'api': '1',
    'query': query,
  });
}
