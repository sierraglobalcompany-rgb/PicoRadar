import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/features/tramites/presentation/tramites_screen.dart';
import 'package:picoradar/features/vehicle_status/platform/external_launcher.dart';

void main() {
  testWidgets('starts with city selector and no procedure cards', (
    tester,
  ) async {
    await _pumpScreen(tester);

    expect(find.text('Trámites'), findsOneWidget);
    expect(
      find.text('Selecciona la ciudad donde realizarás el trámite.'),
      findsOneWidget,
    );
    expect(
      find.text('Por ahora incluimos enlaces revisados de Medellín y Bogotá.'),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('tramites-city-selector')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('tramites-select-city')), findsOneWidget);
    expect(find.byKey(_cardKey('medellin', 'traspaso')), findsNothing);
    expect(find.byKey(_cardKey('bogota', 'traspaso')), findsNothing);
  });

  testWidgets('Medellín shows the four approved procedures in order', (
    tester,
  ) async {
    await _pumpScreen(tester);
    await _selectCity(tester, 'Medellín');

    expect(
      find.byKey(const ValueKey('tramites-list-medellin')),
      findsOneWidget,
    );
    _expectProcedureOrder(tester, 'medellin');
  });

  testWidgets('Bogotá shows the four approved procedures in order', (
    tester,
  ) async {
    await _pumpScreen(tester);
    await _selectCity(tester, 'Bogotá');

    expect(find.byKey(const ValueKey('tramites-list-bogota')), findsOneWidget);
    _expectProcedureOrder(tester, 'bogota');
  });

  testWidgets(
    'detail sheet shows preparation list, disclaimer and review date',
    (tester) async {
      await _pumpScreen(tester);
      await _selectCity(tester, 'Medellín');
      await _openCard(tester, 'medellin', 'traspaso');

      expect(
        find.byKey(const ValueKey('tramites-detail-sheet')),
        findsOneWidget,
      );
      expect(find.text('Traspaso de propiedad'), findsWidgets);
      expect(find.text('Medellín'), findsWidgets);
      expect(find.text('Lista de preparación'), findsOneWidget);
      expect(
        find.text(
          'Esta lista es una ayuda de preparación. Confirma siempre los '
          'requisitos, costos, vigencia y disponibilidad en el portal oficial.',
        ),
        findsOneWidget,
      );
      expect(find.text('Revisado 2026-09-03'), findsOneWidget);
      expect(
        find.byKey(
          const ValueKey(
            'tramites-check-Verificar inscripción RUNT de las partes.',
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('tramites-open-official')),
        findsOneWidget,
      );
    },
  );

  testWidgets('checklist state is temporary and resets when reopened', (
    tester,
  ) async {
    const checkKey = ValueKey(
      'tramites-check-Verificar inscripción RUNT de las partes.',
    );
    await _pumpScreen(tester);
    await _selectCity(tester, 'Medellín');
    await _openCard(tester, 'medellin', 'traspaso');

    expect(tester.widget<CheckboxListTile>(find.byKey(checkKey)).value, false);
    await tester.tap(find.byKey(checkKey));
    await tester.pumpAndSettle();
    expect(tester.widget<CheckboxListTile>(find.byKey(checkKey)).value, true);

    await tester.tapAt(const Offset(24, 24));
    await tester.pumpAndSettle();
    await _openCard(tester, 'medellin', 'traspaso');

    expect(tester.widget<CheckboxListTile>(find.byKey(checkKey)).value, false);
  });

  testWidgets('official URLs are exact and HTTPS for both cities', (
    tester,
  ) async {
    final launcher = _FakeExternalLauncher();
    await _pumpScreen(tester, launcher: launcher);

    for (final city in _cityLabels.entries) {
      await _selectCity(tester, city.value);
      for (final procedure in _procedures) {
        await _openCard(tester, city.key, procedure);
        await tester.tap(find.byKey(const ValueKey('tramites-open-official')));
        await tester.pumpAndSettle();
        await _dismissSheet(tester);

        expect(launcher.opened.last, _officialUrls[(city.key, procedure)]);
        final uri = Uri.parse(launcher.opened.last);
        expect(uri.scheme, 'https');
        expect(
          uri.host,
          anyOf('www.medellin.gov.co', 'www.ventanillamovilidad.com.co'),
        );
      }
    }
  });

  testWidgets('launch failure shows the approved message', (tester) async {
    await _pumpScreen(
      tester,
      launcher: _FakeExternalLauncher(openResult: false),
    );
    await _selectCity(tester, 'Bogotá');
    await _openCard(tester, 'bogota', 'certificado');

    await tester.tap(find.byKey(const ValueKey('tramites-open-official')));
    await tester.pump();

    expect(find.text('No pudimos abrir el portal oficial.'), findsOneWidget);
  });

  testWidgets('launch exception shows the approved message', (tester) async {
    await _pumpScreen(
      tester,
      launcher: _FakeExternalLauncher(throwOnOpen: true),
    );
    await _selectCity(tester, 'Bogotá');
    await _openCard(tester, 'bogota', 'certificado');

    await tester.tap(find.byKey(const ValueKey('tramites-open-official')));
    await tester.pump();

    expect(find.text('No pudimos abrir el portal oficial.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('does not require a vehicle or automatic location', (
    tester,
  ) async {
    await _pumpScreen(tester);
    await _selectCity(tester, 'Bogotá');

    expect(find.byKey(_cardKey('bogota', 'matricula')), findsOneWidget);
    expect(find.textContaining('ubicación'), findsNothing);
    expect(find.textContaining('vehículo activo'), findsNothing);
  });

  testWidgets('keeps minimum scope without tariffs or processing times', (
    tester,
  ) async {
    await _pumpScreen(tester);
    await _selectCity(tester, 'Medellín');
    await _openCard(tester, 'medellin', 'matricula');

    expect(find.textContaining(r'$'), findsNothing);
    expect(find.textContaining('COP'), findsNothing);
    expect(find.textContaining('pesos'), findsNothing);
    expect(find.textContaining('horas'), findsNothing);
    expect(find.textContaining('días'), findsNothing);
    expect(find.textContaining('semanas'), findsNothing);
  });

  testWidgets('Trámites stays readable on target phones', (tester) async {
    const sizes = [Size(360, 800), Size(390, 844), Size(412, 915)];
    const scales = [1.0, 1.5, 2.0];

    for (final size in sizes) {
      for (final scale in scales) {
        await _pumpScreen(tester, size: size, scale: scale);
        await _selectCity(tester, 'Medellín');
        await _openCard(tester, 'medellin', 'duplicado');

        expect(
          find.byKey(const ValueKey('tramites-detail-sheet')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await _dismissSheet(tester);
      }
    }
  });
}

const _procedures = ['traspaso', 'duplicado', 'matricula', 'certificado'];

const _cityLabels = {'medellin': 'Medellín', 'bogota': 'Bogotá'};

const _officialUrls = {
  ('medellin', 'traspaso'): 'https://www.medellin.gov.co/es/tramites-y-servicios/traspaso-de-propiedad-de-un-vehiculo-automotor/',
  ('medellin', 'duplicado'): 'https://www.medellin.gov.co/es/tramites-y-servicios/como-sacar-el-duplicado-de-la-licencia-de-transito-de-un-vehiculo-automotor/',
  ('medellin', 'matricula'): 'https://www.medellin.gov.co/es/tramites-y-servicios/matricula-de-vehiculos-automotores/',
  ('medellin', 'certificado'): 'https://www.medellin.gov.co/es/tramites-y-servicios/certificado-de-libertad-y-tradicion-de-un-vehiculo-automotor/',
  ('bogota', 'traspaso'):
      'https://www.ventanillamovilidad.com.co/tramites/traspaso-propiedad',
  ('bogota', 'duplicado'): 'https://www.ventanillamovilidad.com.co/tramites/duplicado-de-licencia-de-transito',
  ('bogota', 'matricula'):
      'https://www.ventanillamovilidad.com.co/tramites/matricula',
  ('bogota', 'certificado'): 'https://www.ventanillamovilidad.com.co/tramites/certificado-de-libertad-y-tradicion',
};

Future<void> _pumpScreen(
  WidgetTester tester, {
  _FakeExternalLauncher? launcher,
  Size size = const Size(390, 844),
  double scale = 1,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        externalLauncherProvider.overrideWithValue(
          launcher ?? _FakeExternalLauncher(),
        ),
      ],
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(scale)),
          child: const TramitesScreen(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _selectCity(WidgetTester tester, String label) async {
  await tester.ensureVisible(find.text(label).first);
  await tester.tap(find.text(label).first);
  await tester.pumpAndSettle();
}

Future<void> _openCard(
  WidgetTester tester,
  String city,
  String procedure,
) async {
  final card = find.byKey(_cardKey(city, procedure));
  await tester.ensureVisible(card);
  await tester.tap(card);
  await tester.pumpAndSettle();
}

Future<void> _dismissSheet(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
  await tester.pumpAndSettle();
}

ValueKey<String> _cardKey(String city, String procedure) {
  return ValueKey('tramites-card-$city-$procedure');
}

void _expectProcedureOrder(WidgetTester tester, String city) {
  final keys = _procedures.map((procedure) => _cardKey(city, procedure));
  final tops = [for (final key in keys) tester.getTopLeft(find.byKey(key)).dy];
  expect(tops, orderedEquals([...tops]..sort()));
  expect(find.text('Traspaso de propiedad'), findsOneWidget);
  expect(find.text('Duplicado de licencia de tránsito'), findsOneWidget);
  expect(find.text('Matrícula de vehículo'), findsOneWidget);
  expect(find.text('Certificado de libertad y tradición'), findsOneWidget);
}

class _FakeExternalLauncher implements ExternalLauncher {
  _FakeExternalLauncher({this.openResult = true, this.throwOnOpen = false});

  final bool openResult;
  final bool throwOnOpen;
  final opened = <String>[];

  @override
  Future<bool> callPhone(String phone) async => true;

  @override
  Future<bool> openExternal(String uri) async {
    if (throwOnOpen) {
      throw StateError('launcher failed');
    }
    opened.add(uri);
    return openResult;
  }
}
