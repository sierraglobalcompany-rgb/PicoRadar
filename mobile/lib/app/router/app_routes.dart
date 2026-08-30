enum AppRoute {
  home('/home'),
  garage('/garage'),
  apps('/apps'),
  trip('/trip'),
  drive('/drive'),
  pico('/pico'),
  vehicleOnboarding('/onboarding/vehicle'),
  immersivePreview('/immersive-preview');

  const AppRoute(this.path);

  final String path;
}

enum PicoRouteOrigin { home, garage, apps }

String picoShellLocation({
  required PicoRouteOrigin origin,
  String? vehicleId,
  String? jurisdictionId,
}) {
  final path = switch (origin) {
    PicoRouteOrigin.home => '${AppRoute.home.path}/pico',
    PicoRouteOrigin.garage => '${AppRoute.garage.path}/pico',
    PicoRouteOrigin.apps => '${AppRoute.apps.path}/pico',
  };
  final queryParameters = <String, String>{};
  if (_hasRouteValue(vehicleId)) {
    queryParameters['vehicleId'] = vehicleId!.trim();
  }
  if (_hasRouteValue(jurisdictionId)) {
    queryParameters['jurisdictionId'] = jurisdictionId!.trim();
  }
  if (queryParameters.isEmpty) {
    return path;
  }
  return Uri(path: path, queryParameters: queryParameters).toString();
}

String picoCompatibilityLocation(Uri uri) {
  final vehicleId = uri.queryParameters['vehicleId'];
  final jurisdictionId = uri.queryParameters['jurisdictionId'];
  final origin = switch (uri.queryParameters['origin']) {
    'home' => PicoRouteOrigin.home,
    'garage' => PicoRouteOrigin.garage,
    'apps' => PicoRouteOrigin.apps,
    _ =>
      _hasRouteValue(vehicleId) ? PicoRouteOrigin.home : PicoRouteOrigin.apps,
  };
  return picoShellLocation(
    origin: origin,
    vehicleId: vehicleId,
    jurisdictionId: jurisdictionId,
  );
}

bool _hasRouteValue(String? value) => value != null && value.trim().isNotEmpty;
