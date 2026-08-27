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
