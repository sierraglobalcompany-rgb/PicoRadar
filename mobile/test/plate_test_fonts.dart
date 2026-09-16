import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/core/design_system/branding.dart';

Finder findPlateNumber(String value) => find.byWidgetPredicate(
  (widget) =>
      (widget is ColombianPlateBadge &&
          widget.plate == value.replaceAll(' ', '')) ||
      (widget is Text && widget.data == value),
);

Future<void> loadPlateTestFonts() async {
  final configFile = File('.dart_tool/package_config.json').absolute;
  final config =
      jsonDecode(await configFile.readAsString()) as Map<String, dynamic>;
  final flutter = (config['packages'] as List)
      .cast<Map<String, dynamic>>()
      .singleWhere((package) => package['name'] == 'flutter');
  final root = configFile.uri.resolve(
    '${(flutter['rootUri'] as String).replaceFirst(RegExp(r'/$'), '')}/',
  );
  final fonts = root.resolve('../../bin/cache/artifacts/material_fonts/');
  for (final font in [
    ('sans-serif-condensed', 'robotocondensed-bold.ttf'),
    ('Roboto', 'roboto-regular.ttf'),
    ('MaterialIcons', 'materialicons-regular.otf'),
  ]) {
    final loader = FontLoader(font.$1)
      ..addFont(
        File.fromUri(fonts.resolve(font.$2))
            .readAsBytes()
            .then((bytes) => ByteData.sublistView(bytes)),
      );
    await loader.load();
  }
}
